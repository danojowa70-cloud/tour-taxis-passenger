import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RideService {
  final SupabaseClient _client;
  RideService(this._client);


  Future<String> createRide({
    required String passengerName,
    required String passengerPhone,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double destLat,
    required double destLng,
    required String destAddress,
    required double distanceMeters,
    required double durationSeconds,
    required double fare,
    required String vehicleTypeId, // 'car' | 'suv' | 'bike'
  }) async {
    // IMPORTANT: Create/update passenger FIRST to satisfy foreign key constraint
    final authUserId = _client.auth.currentUser?.id;
    String? passengerId;
    
    if (authUserId != null) {
      try {
        // Upsert passenger by auth_user_id to ensure passenger exists
        final passenger = await _client
            .from('passengers')
            .upsert({
              'auth_user_id': authUserId,
              'email': _client.auth.currentUser?.email,
              'name': passengerName,
              'phone': passengerPhone,
            }, onConflict: 'auth_user_id')
            .select()
            .single();
        passengerId = passenger['id'] as String;
        debugPrint('✅ Passenger record created/updated: $passengerId');
      } catch (e) {
        debugPrint('⚠️ Failed to create passenger record: $e');
        // Continue without passenger_id if it fails
      }
    }
    
    // Insert into rides with passenger_id if available
    final rideData = {
      'passenger_name': passengerName,
      'passenger_phone': passengerPhone,
      'pickup_latitude': pickupLat,
      'pickup_longitude': pickupLng,
      'pickup_address': pickupAddress,
      'destination_latitude': destLat,
      'destination_longitude': destLng,
      'destination_address': destAddress,
      'distance': (distanceMeters / 1000.0),
      'distance_text': '${(distanceMeters / 1000.0).toStringAsFixed(1)} km',
      'duration': durationSeconds.toInt(),
      'duration_text': '${(durationSeconds / 60).round()} min',
      'fare': fare,
      'status': 'requested',
      'vehicle_type': vehicleTypeId,
    };
    
    // Only add passenger_id if we successfully created the passenger
    if (passengerId != null) {
      rideData['passenger_id'] = passengerId;
    }
    
    final insertRide = await _client
        .from('rides')
        .insert(rideData)
        .select()
        .single();

    final rideId = insertRide['id'] as String;

    // Create ride_passenger_link if we have both IDs
    if (passengerId != null) {
      try {
        await _client.from('ride_passenger_link').upsert({
          'ride_id': rideId,
          'passenger_id': passengerId,
        });
        debugPrint('✅ Ride-passenger link created');
      } catch (e) {
        debugPrint('⚠️ Failed to create ride-passenger link: $e');
      }
    }

    // Write an initial ride event for realtime/history
    await _client.from('ride_events').insert({
      'ride_id': rideId,
      'actor': 'passenger',
      'event_type': 'ride:request',
      'payload': {
        'pickup': pickupAddress,
        'destination': destAddress,
        'distance_m': distanceMeters,
        'duration_s': durationSeconds,
        'fare': fare,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
        'requested_vehicle_type': vehicleTypeId,
      }
    });

    // Find and notify nearby drivers using Supabase
    await _findAndNotifyDrivers(rideId, pickupLat, pickupLng, fare, vehicleTypeId);
    
    debugPrint('✅ Ride created in Supabase and drivers notified.');

    return rideId;
  }

  Future<void> _findAndNotifyDrivers(String rideId, double pickupLat, double pickupLng, double fare, String vehicleTypeId) async {
    try {
      // Find nearby online and available drivers using the database function
      final nearbyDrivers = await _client
          .rpc('get_nearby_drivers', params: {
            'lat': pickupLat,
            'lng': pickupLng,
            'radius_km': 10.0, // 10km radius
            'desired_vehicle': vehicleTypeId,
          });
      
      debugPrint('Found ${nearbyDrivers.length} nearby online drivers');
      
      // Filter drivers to ensure they are actually online and available
      final availableDrivers = (nearbyDrivers as List)
          .where((driver) => 
            driver['is_online'] == true && 
            driver['is_available'] == true &&
            driver['last_seen'] != null)
          .take(10) // Get up to 10 nearest drivers
          .toList();

      if (availableDrivers.isEmpty) {
        // No drivers available - log event
        await _client.from('ride_events').insert({
          'ride_id': rideId,
          'actor': 'system',
          'event_type': 'ride:no_drivers',
          'payload': {
            'message': 'No online drivers available in the area',
            'search_radius_km': 10.0,
            'total_drivers_found': nearbyDrivers.length,
            'online_available_drivers': availableDrivers.length,
          }
        });
        return;
      }

      // Log that drivers were found
      await _client.from('ride_events').insert({
        'ride_id': rideId,
        'actor': 'system',
        'event_type': 'ride:drivers_found',
        'payload': {
          'driver_count': availableDrivers.length,
          'drivers': availableDrivers.map((d) => {
            'id': d['id'],
            'name': d['name'],
            'distance_km': d['distance_km'],
            'rating': d['rating'],
            'is_online': d['is_online'],
            'is_available': d['is_available'],
            'vehicle_info': d['vehicle_info'],
          }).toList(),
        }
      });

      // Use Supabase real-time to broadcast to drivers
      // This will notify all connected driver apps about the new ride request
      final rideData = await _client
          .from('rides')
          .select('*')
          .eq('id', rideId)
          .single();

      // Send broadcast to all available online drivers
      for (final driver in availableDrivers) {
        await _client.from('ride_events').insert({
          'ride_id': rideId,
          'actor': 'system',
          'event_type': 'ride:notify_driver',
          'payload': {
            'driver_id': driver['id'],
            'driver_name': driver['name'],
            'distance_km': driver['distance_km'],
            'ride_data': rideData,
          }
        });
      }

    } catch (e) {
      // Log error
      await _client.from('ride_events').insert({
        'ride_id': rideId,
        'actor': 'system',
        'event_type': 'ride:driver_search_error',
        'payload': {
          'error': e.toString(),
        }
      });
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyDrivers(double lat, double lng, {double radiusKm = 5.0}) async {
    try {
      final drivers = await _client
          .rpc('get_nearby_drivers', params: {
            'lat': lat,
            'lng': lng,
            'radius_km': radiusKm,
            'desired_vehicle': null,  // Get all vehicle types
          });
      
      return List<Map<String, dynamic>>.from(drivers);
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRideStatus(String rideId) async {
    try {
      final ride = await _client
          .from('rides')
          .select('*')
          .eq('id', rideId)
          .single();
      
      return ride;
    } catch (e) {
      // Return null on error
      return null;
    }
  }

  // Subscribe to ride events for real-time updates
  Stream<List<Map<String, dynamic>>> subscribeToRideEvents(String rideId) {
    return _client
        .from('ride_events')
        .stream(primaryKey: ['id'])
        .eq('ride_id', rideId)
        .order('created_at');
  }

  // Subscribe to ride status changes
  Stream<List<Map<String, dynamic>>> subscribeToRideStatus(String rideId) {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('id', rideId);
  }

  Future<void> cancelRide({required String rideId, String? reason}) async {
    await _client.from('rides').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
      'cancelled_at': DateTime.now().toIso8601String(),
    }).eq('id', rideId);

    await _client.from('ride_events').insert({
      'ride_id': rideId,
      'actor': 'passenger',
      'event_type': 'ride:cancel',
      'payload': { 'reason': reason },
    });
  }

  /// Driver accepts a ride request
  Future<bool> acceptRide({
    required String rideId,
    required String driverId,
  }) async {
    try {
      // Get driver details (throws exception if not found)
      final driverData = await _client
          .from('drivers')
          .select('*')
          .eq('id', driverId)
          .single();

      // Update ride with driver information and change status to 'accepted'
      await _client.from('rides').update({
        'driver_id': driverId,
        'status': 'accepted',
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', rideId);

      // Create ride event with complete driver data for passenger app
      await _client.from('ride_events').insert({
        'ride_id': rideId,
        'actor': 'driver',
        'event_type': 'ride:accepted',
        'payload': {
          'driver_id': driverId,
          'driver_name': driverData['name'] ?? 'Driver',
          'driver_phone': driverData['phone'] ?? '',
          'driver_car': '${driverData['vehicle_type'] ?? ''} ${driverData['vehicle_model'] ?? ''}'.trim(),
          'vehicle_type': driverData['vehicle_type'] ?? '',
          'vehicle_number': driverData['vehicle_number'] ?? '',
          'vehicle_plate': driverData['vehicle_plate'] ?? '',
          'driver_rating': driverData['rating']?.toDouble() ?? 4.5,
          'driver_data': {
            'id': driverId,
            'name': driverData['name'] ?? 'Driver',
            'phone': driverData['phone'] ?? '',
            'vehicle_model': driverData['vehicle_model'] ?? '',
            'vehicle_type': driverData['vehicle_type'] ?? '',
            'vehicle_number': driverData['vehicle_number'] ?? '',
            'vehicle_plate': driverData['vehicle_plate'] ?? '',
            'rating': driverData['rating']?.toDouble() ?? 4.5,
          },
        }
      });

      debugPrint('✅ Driver $driverId accepted ride $rideId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to accept ride: $e');
      return false;
    }
  }
}


