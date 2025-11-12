import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverScheduledRidesService {
  // Get the current authenticated driver ID
  String? get _driverId => Supabase.instance.client.auth.currentUser?.id;

  /// Get all available scheduled rides (not yet accepted by any driver)
  Future<List<Map<String, dynamic>>> getAvailableScheduledRides() async {
    try {
      final response = await Supabase.instance.client
          .from('scheduled_rides')
          .select('''
            *,
            passengers:passenger_id (
              full_name,
              phone_number
            )
          ''')
          .eq('status', 'scheduled')
          .gte('scheduled_time', DateTime.now().toIso8601String())
          .order('scheduled_time', ascending: true);

      debugPrint('✅ Found ${response.length} available scheduled rides');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching available scheduled rides: $e');
      return [];
    }
  }

  /// Get scheduled rides accepted by this driver
  Future<List<Map<String, dynamic>>> getMyScheduledRides() async {
    try {
      final driverId = _driverId;
      if (driverId == null) {
        debugPrint('❌ No authenticated driver');
        return [];
      }

      final response = await Supabase.instance.client
          .from('scheduled_rides')
          .select('''
            *,
            passengers:passenger_id (
              full_name,
              phone_number
            )
          ''')
          .eq('driver_id', driverId)
          .inFilter('status', ['confirmed', 'scheduled'])
          .gte('scheduled_time', DateTime.now().toIso8601String())
          .order('scheduled_time', ascending: true);

      debugPrint('✅ Found ${response.length} scheduled rides for driver');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching driver scheduled rides: $e');
      return [];
    }
  }

  /// Driver accepts a scheduled ride
  Future<bool> acceptScheduledRide(String rideId) async {
    try {
      final driverId = _driverId;
      if (driverId == null) {
        debugPrint('❌ No authenticated driver');
        return false;
      }

      await Supabase.instance.client
          .from('scheduled_rides')
          .update({
            'driver_id': driverId,
            'status': 'confirmed',
            'confirmed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('status', 'scheduled'); // Only accept if still scheduled

      debugPrint('✅ Scheduled ride accepted by driver');
      
      // TODO: Send notification to passenger
      await _notifyPassengerRideConfirmed(rideId);
      
      return true;
    } catch (e) {
      debugPrint('❌ Error accepting scheduled ride: $e');
      return false;
    }
  }

  /// Driver cancels a scheduled ride they accepted
  Future<bool> cancelScheduledRide(String rideId, String reason) async {
    try {
      final driverId = _driverId;
      if (driverId == null) {
        debugPrint('❌ No authenticated driver');
        return false;
      }

      await Supabase.instance.client
          .from('scheduled_rides')
          .update({
            'driver_id': null,
            'status': 'scheduled',
            'cancellation_reason': reason,
          })
          .eq('id', rideId)
          .eq('driver_id', driverId);

      debugPrint('✅ Scheduled ride cancelled by driver');
      
      // TODO: Send notification to passenger
      await _notifyPassengerRideCancelled(rideId, reason);
      
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling scheduled ride: $e');
      return false;
    }
  }

  /// Mark scheduled ride as started (when it's time)
  Future<bool> startScheduledRide(String rideId) async {
    try {
      final driverId = _driverId;
      if (driverId == null) {
        debugPrint('❌ No authenticated driver');
        return false;
      }

      await Supabase.instance.client
          .from('scheduled_rides')
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', driverId)
          .eq('status', 'confirmed');

      debugPrint('✅ Scheduled ride started');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting scheduled ride: $e');
      return false;
    }
  }

  /// Listen to new scheduled rides in real-time
  RealtimeChannel subscribeToScheduledRides(Function(Map<String, dynamic>) onNewRide) {
    final channel = Supabase.instance.client
        .channel('scheduled_rides_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scheduled_rides',
          callback: (payload) {
            debugPrint('🔔 New scheduled ride: ${payload.newRecord}');
            onNewRide(payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  // Private helper methods for notifications
  Future<void> _notifyPassengerRideConfirmed(String rideId) async {
    // TODO: Implement push notification to passenger
    debugPrint('📱 Notifying passenger: ride confirmed');
  }

  Future<void> _notifyPassengerRideCancelled(String rideId, String reason) async {
    // TODO: Implement push notification to passenger
    debugPrint('📱 Notifying passenger: ride cancelled - $reason');
  }
}
