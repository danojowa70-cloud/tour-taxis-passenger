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
  }) async {
    // Insert into rides (passenger fields kept for driver app compatibility)
    final insertRide = await _client.from('rides').insert({
      'passenger_id': _client.auth.currentUser?.id ?? passengerPhone,
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
    }).select().single();

    final rideId = insertRide['id'] as String;

    // Link to passengers table if exists (best-effort)
    final authUserId = _client.auth.currentUser?.id;
    if (authUserId != null) {
      // upsert passenger by auth_user_id
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
      final passengerId = passenger['id'] as String;

      // link row
      await _client.from('ride_passenger_link').upsert({
        'ride_id': rideId,
        'passenger_id': passengerId,
      });
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
      }
    });

    // Find and notify nearby drivers
    await _findAndNotifyDrivers(rideId, pickupLat, pickupLng, fare);

    return rideId;
  }

  Future<void> _findAndNotifyDrivers(String rideId, double pickupLat, double pickupLng, double fare) async {
    try {
      // Find nearby available drivers using the database function
      final nearbyDrivers = await _client
          .rpc('get_nearby_drivers', params: {
            'lat': pickupLat,
            'lng': pickupLng,
            'radius_km': 10.0, // 10km radius
          })
          .limit(10); // Get up to 10 nearest drivers

      if (nearbyDrivers.isEmpty) {
        // No drivers available - log event
        await _client.from('ride_events').insert({
          'ride_id': rideId,
          'actor': 'system',
          'event_type': 'ride:no_drivers',
          'payload': {
            'message': 'No drivers available in the area',
            'search_radius_km': 10.0,
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
          'driver_count': nearbyDrivers.length,
          'drivers': nearbyDrivers.map((d) => {
            'id': d['id'],
            'name': d['name'],
            'distance_km': d['distance_km'],
            'rating': d['rating'],
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

      // Send broadcast to all nearby drivers
      for (final driver in nearbyDrivers) {
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
}


