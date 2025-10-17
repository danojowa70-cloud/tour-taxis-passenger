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
};


