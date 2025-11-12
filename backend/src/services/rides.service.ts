import { supabase } from '../config/supabase';
import { Ride, RideStatus } from '../models/types';

export const RidesService = {
  async createRide(passengerId: string, pickup: string, drop: string): Promise<Ride> {
    const { data, error } = await supabase
      .from('rides')
      .insert({ passenger_id: passengerId, driver_id: null, pickup_location: pickup, drop_location: drop, status: 'pending' as RideStatus })
      .select()
      .single();
    if (error) throw error;
    return data as Ride;
  },

  async updateRideStatus(rideId: string, status: RideStatus, updates: Partial<Ride> = {}): Promise<Ride> {
    const { data, error } = await supabase
      .from('rides')
      .update({ status, ...updates })
      .eq('id', rideId)
      .select()
      .single();
    if (error) throw error;
    return data as Ride;
  },

  async getPassengerHistory(passengerId: string): Promise<Ride[]> {
    const { data, error } = await supabase
      .from('rides')
      .select(`
        *,
        drivers(
          id,
          name,
          phone,
          vehicle_type,
          vehicle_number,
          vehicle_make,
          vehicle_model,
          vehicle_plate,
          rating,
          is_online,
          is_available
        )
      `)
      .eq('passenger_id', passengerId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    return (data || []) as Ride[];
  },

  async getRideWithDriver(rideId: string): Promise<Ride | null> {
    const { data, error } = await supabase
      .from('rides')
      .select(`
        *,
        drivers(
          id,
          name,
          phone,
          vehicle_type,
          vehicle_number,
          vehicle_make,
          vehicle_model,
          vehicle_plate,
          rating,
          is_online,
          is_available
        )
      `)
      .eq('id', rideId)
      .single();
    if (error) return null;
    return data as Ride;
  },

  async getNearbyDrivers(lat: number, lng: number, radiusKm: number = 10): Promise<any[]> {
    const { data, error } = await supabase
      .rpc('get_nearby_drivers', {
        lat,
        lng,
        radius_km: radiusKm
      });
    if (error) throw error;
    return data || [];
  },

  async acceptRide(rideId: string, driverId: string): Promise<{ success: boolean; message?: string; ride?: any; driver?: any }> {
    try {
      // Get driver details first
      const { data: driverData, error: driverError } = await supabase
        .from('drivers')
        .select('*')
        .eq('id', driverId)
        .single();

      if (driverError || !driverData) {
        return { success: false, message: 'Driver not found' };
      }

      // Check if driver is available
      if (!driverData.is_online || !driverData.is_available) {
        return { success: false, message: 'Driver is not available' };
      }

      // Update ride status and assign driver
      const { data: rideData, error: rideError } = await supabase
        .from('rides')
        .update({
          driver_id: driverId,
          status: 'accepted' as RideStatus,
          accepted_at: new Date().toISOString(),
        })
        .eq('id', rideId)
        .eq('status', 'requested') // Only accept if still in requested state
        .select()
        .single();

      if (rideError || !rideData) {
        return { success: false, message: 'Failed to update ride or ride already accepted' };
      }

      // Create ride event for real-time updates to passenger app
      await supabase.from('ride_events').insert({
        ride_id: rideId,
        actor: 'driver',
        event_type: 'ride:accepted',
        payload: {
          driver_id: driverId,
          driver_name: driverData.name || 'Driver',
          driver_phone: driverData.phone || '',
          driver_car: `${driverData.vehicle_make || ''} ${driverData.vehicle_model || ''}`.trim(),
          vehicle_type: driverData.vehicle_type || '',
          vehicle_number: driverData.vehicle_number || '',
          vehicle_plate: driverData.vehicle_plate || '',
          driver_rating: driverData.rating || 4.5,
          driver_data: {
            id: driverId,
            name: driverData.name || 'Driver',
            phone: driverData.phone || '',
            vehicle_make: driverData.vehicle_make || '',
            vehicle_model: driverData.vehicle_model || '',
            vehicle_type: driverData.vehicle_type || '',
            vehicle_number: driverData.vehicle_number || '',
            vehicle_plate: driverData.vehicle_plate || '',
            rating: driverData.rating || 4.5,
          },
        },
      });

      // Update driver availability
      await supabase.from('drivers').update({
        is_available: false,
      }).eq('id', driverId);

      return {
        success: true,
        ride: rideData,
        driver: driverData,
      };
    } catch (error: any) {
      console.error('Error accepting ride:', error);
      return { success: false, message: error.message || 'Internal server error' };
    }
  },
};

