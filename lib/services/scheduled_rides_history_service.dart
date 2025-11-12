import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduledRidesHistoryService {
  final _supabase = Supabase.instance.client;
  
  // Get the passenger ID from passengers table (not auth.users)
  Future<String?> _getPassengerId(String authUserId) async {
    try {
      final passenger = await _supabase
          .from('passengers')
          .select('id')
          .eq('auth_user_id', authUserId)
          .maybeSingle();
      
      if (passenger != null) {
        return passenger['id'] as String?;
      }
      
      // Fallback to auth user ID if no passenger record exists
      return authUserId;
    } catch (e) {
      debugPrint('❌ Error fetching passenger ID: $e');
      return null;
    }
  }

  /// Get passenger's all scheduled rides history with OTP
  Future<List<Map<String, dynamic>>> getScheduledRidesHistory({
    required String passengerId,
  }) async {
    try {
      debugPrint('📥 Fetching scheduled rides for passenger: $passengerId');
      debugPrint('🔍 Current user (auth): ${_supabase.auth.currentUser?.id}');
      debugPrint('🔍 Current user email: ${_supabase.auth.currentUser?.email}');
      debugPrint('🔍 Auth session: ${_supabase.auth.currentSession}');
      debugPrint('🔍 Auth session user ID: ${_supabase.auth.currentSession?.user.id}');
      
      // IMPORTANT: Refresh auth session before querying
      try {
        debugPrint('📥 Refreshing auth session before history fetch...');
        await _supabase.auth.refreshSession();
        debugPrint('📥 Auth session refreshed');
      } catch (e) {
        debugPrint('⚠️ Could not refresh session: $e');
      }
      
      // Validate that passengerId matches current auth user
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        debugPrint('❌ No authenticated user');
        return [];
      }
      
      // Get the actual passenger ID from passengers table to ensure we're using the right one
      final actualPassengerId = await _getPassengerId(authUserId);
      if (actualPassengerId == null) {
        debugPrint('❌ Could not determine passenger ID');
        return [];
      }
      
      debugPrint('📥 Using passenger ID: $actualPassengerId (provided: $passengerId)');
      if (actualPassengerId != passengerId) {
        debugPrint('⚠️ WARNING: Provided passengerId differs from actual passenger ID');
        debugPrint('⚠️ Using actual passenger ID: $actualPassengerId');
      }
      
      final effectivePassengerId = actualPassengerId;
      
      // Fetch ALL scheduled rides using the validated passenger ID
      final ridesResponse = await _supabase
          .from('scheduled_rides')
          .select()
          .eq('passenger_id', effectivePassengerId)
          .order('scheduled_time', ascending: false)
          .limit(50);

      debugPrint('📖 Total rides fetched: ${ridesResponse.length}');
      if (ridesResponse.isEmpty) {
        debugPrint('⚠️ No rides found for passenger $effectivePassengerId');
        
        // Try to fetch ALL rides to see if data exists with different passenger_id
        try {
          final allRides = await _supabase
              .from('scheduled_rides')
              .select('passenger_id')
              .limit(1);
          
          if (allRides.isNotEmpty) {
            final somePassengerId = allRides[0]['passenger_id'];
            debugPrint('📊 IMPORTANT: Rides exist but with different passenger_id: $somePassengerId');
            debugPrint('📊 You are logged in as: $effectivePassengerId');
            debugPrint('📊 FIX: Log out and log in with the account that scheduled the ride');
          }
        } catch (e) {
          debugPrint('⚠️ Could not check other rides: $e');
        }
        
        return [];
      }
      
      // Log all statuses
      final statusCount = <String, int>{};
      for (var ride in ridesResponse) {
        final status = ride['status'] as String?;
        statusCount[status ?? 'null'] = (statusCount[status ?? 'null'] ?? 0) + 1;
      }
      debugPrint('📊 Ride statuses: $statusCount');
      debugPrint('🚗 First ride: ID=${ridesResponse[0]['id']}, Status=${ridesResponse[0]['status']}, ScheduledTime=${ridesResponse[0]['scheduled_time']}');
      debugPrint('📍 First ride locations: ${ridesResponse[0]['pickup_location']} → ${ridesResponse[0]['destination_location']}');
      
      // LOG COMPLETE PAYLOAD OF FIRST RIDE
      debugPrint('📄 === FIRST RIDE COMPLETE PAYLOAD ===');
      ridesResponse[0].forEach((key, value) {
        debugPrint('🔍  $key: $value (type: ${value.runtimeType})');
      });
      debugPrint('📄 === END PAYLOAD ===');
      
      // Specifically check for OTP field
      if (ridesResponse[0].containsKey('otp')) {
        debugPrint('✅ OTP field EXISTS: ${ridesResponse[0]['otp']}');
      } else {
        debugPrint('❌ OTP field MISSING from ride data');
        debugPrint('🔍 Available fields: ${ridesResponse[0].keys.toList()}');
      }
      
      // Check for driver_id
      if (ridesResponse[0].containsKey('driver_id')) {
        debugPrint('✅ driver_id field EXISTS: ${ridesResponse[0]['driver_id']}');
      } else {
        debugPrint('❌ driver_id field MISSING');
      }

      List<Map<String, dynamic>> rides = List<Map<String, dynamic>>.from(ridesResponse);

      // Fetch driver data for each ride separately
      for (int i = 0; i < rides.length; i++) {
        final driverId = rides[i]['driver_id'];
        debugPrint('🚙 Processing ride ${i + 1}: Status=${rides[i]['status']}, DriverID=$driverId');
        if (driverId != null) {
          try {
            final driverData = await _supabase
                .from('drivers')
                .select()
                .eq('id', driverId)
                .single();
            rides[i]['drivers'] = driverData;
            debugPrint('✅ Driver data fetched for ride ${i + 1}');
          } catch (e) {
            debugPrint('⚠️ Could not fetch driver data for $driverId: $e');
          }
        }
      }

      debugPrint('✅ Successfully fetched ${rides.length} scheduled rides');
      return rides;
    } catch (e) {
      debugPrint('❌ Error fetching scheduled rides history: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      
      // Enhanced error logging for PostgrestException
      if (e.toString().contains('PostgrestException')) {
        debugPrint('❌ SUPABASE ERROR: This might be a Row-Level Security (RLS) policy issue');
        debugPrint('❌ Check if RLS is enabled on scheduled_rides table and if policies allow the current user to read data');
        debugPrint('❌ Auth user: ${_supabase.auth.currentUser?.id}');
        debugPrint('❌ Auth session exists: ${_supabase.auth.currentSession != null}');
      }
      
      return [];
    }
  }

  /// Get a specific scheduled ride with OTP
  Future<Map<String, dynamic>?> getScheduledRideWithOtp({
    required String rideId,
  }) async {
    try {
      final response = await _supabase
          .from('scheduled_rides')
          .select()
          .eq('id', rideId)
          .single();

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching scheduled ride: $e');
      return null;
    }
  }

  /// Get ride details including OTP and driver info
  Future<Map<String, dynamic>?> getRideDetailsWithDriverInfo({
    required String rideId,
  }) async {
    try {
      // Fetch ride with potential driver info
      final response = await _supabase
          .from('scheduled_rides')
          .select()
          .eq('id', rideId)
          .single();

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching ride details: $e');
      return null;
    }
  }

  /// Listen to scheduled rides updates in real-time
  RealtimeChannel subscribeToScheduledRidesHistory({
    required String passengerId,
    required Function(Map<String, dynamic>) onUpdate,
  }) {
    final channel = _supabase
        .channel('scheduled_rides_history_$passengerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scheduled_rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'passenger_id',
            value: passengerId,
          ),
          callback: (payload) {
            final ride = payload.newRecord;
            // Only notify if status is in history (completed, in_progress, cancelled)
            if (['completed', 'in_progress', 'cancelled'].contains(ride['status'])) {
              onUpdate(ride);
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Unsubscribe from real-time updates
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
