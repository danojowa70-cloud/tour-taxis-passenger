import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride.dart';
import '../models/location.dart';

class ScheduledRidesService {
  // Get the current authenticated user ID from auth
  String? get _authUserId => Supabase.instance.client.auth.currentUser?.id;
  
  // Get the passenger ID from passengers table (not auth.users)
  Future<String?> _getPassengerId() async {
    try {
      final authUserId = _authUserId;
      if (authUserId == null) return null;
      
      final passenger = await Supabase.instance.client
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
  
  // Generate a 6-digit OTP
  String _generateOtp() {
    final random = Random();
    return List.generate(6, (index) => random.nextInt(10)).join();
  }
  
  // Get current session details for debugging
  Map<String, dynamic> _getAuthDebugInfo() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final session = client.auth.currentSession;
    
    return {
      'user_id': user?.id,
      'user_email': user?.email,
      'session_user_id': session?.user.id,
      'session_user_email': session?.user.email,
      'session_access_token': session?.accessToken.substring(0, 20) ?? 'null',
      'is_authenticated': user != null,
    };
  }
  
  Future<bool> scheduleRide({
    required Location pickupLocation,
    required Location dropoffLocation,
    required DateTime scheduledDateTime,
    required double estimatedFare,
    int? distanceMeters,
    int? durationSeconds,
  }) async {
    try {
      // IMPORTANT: Refresh session before fetching passenger ID
      try {
        debugPrint('🔍 Attempting to refresh auth session...');
        await Supabase.instance.client.auth.refreshSession();
        debugPrint('🔍 Auth session refreshed successfully');
      } catch (e) {
        debugPrint('🔍 Warning: Could not refresh session: $e');
        // Continue anyway - this might fail if already fresh
      }
      
      // Get the correct passenger ID from passengers table
      final passengerId = await _getPassengerId();
      final authDebugInfo = _getAuthDebugInfo();
      
      debugPrint('🔍 === SCHEDULE RIDE AUTHENTICATION DEBUG ===');
      debugPrint('🔍 Auth user ID: $_authUserId');
      debugPrint('🔍 Passenger ID (from passengers table): $passengerId');
      debugPrint('🔍 Full auth debug info: $authDebugInfo');
      
      if (passengerId == null) {
        debugPrint('❌ No passenger ID found');
        return false;
      }

      final otp = _generateOtp();
      debugPrint('🔐 Generated OTP: $otp');
      
      final data = {
        'passenger_id': passengerId,
        'pickup_location': pickupLocation.displayName,
        'pickup_latitude': pickupLocation.latitude,
        'pickup_longitude': pickupLocation.longitude,
        'destination_location': dropoffLocation.displayName,
        'destination_latitude': dropoffLocation.latitude,
        'destination_longitude': dropoffLocation.longitude,
        'scheduled_time': scheduledDateTime.toIso8601String(),
        'estimated_fare': estimatedFare,
        'distance_meters': distanceMeters,
        'duration_seconds': durationSeconds,
        'status': 'scheduled',
        'otp': otp,
      };
      
      debugPrint('💾 Saving scheduled ride: passenger=$passengerId, pickup=${pickupLocation.displayName}, time=${scheduledDateTime.toIso8601String()}');

      final response = await Supabase.instance.client
          .from('scheduled_rides')
          .insert(data)
          .select();
      
      debugPrint('✅ Ride scheduled successfully. Response: ${response.length} records inserted');
      if (response.isNotEmpty) {
        debugPrint('📝 Inserted ride ID: ${response[0]['id']}');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error scheduling ride: $e');
      return false;
    }
  }

  Future<List<Ride>> getScheduledRides() async {
    try {
      // IMPORTANT: Refresh session before fetching passenger ID
      try {
        debugPrint('🔔 Attempting to refresh auth session for ride fetch...');
        await Supabase.instance.client.auth.refreshSession();
        debugPrint('🔔 Auth session refreshed successfully');
      } catch (e) {
        debugPrint('🔔 Warning: Could not refresh session: $e');
        // Continue anyway
      }
      
      // Get the correct passenger ID from passengers table
      final passengerId = await _getPassengerId();
      final authDebugInfo = _getAuthDebugInfo();
      
      debugPrint('🔔 === GET SCHEDULED RIDES DEBUG ===');
      debugPrint('🔔 Auth user ID: $_authUserId');
      debugPrint('🔔 Passenger ID (from passengers table): $passengerId');
      debugPrint('🔔 Full auth debug info: $authDebugInfo');
      
      if (passengerId == null) {
        debugPrint('❌ No passenger ID found');
        return [];
      }

      debugPrint('🔔 Querying rides for passenger_id: $passengerId');
      final response = await Supabase.instance.client
          .from('scheduled_rides')
          .select()
          .eq('passenger_id', passengerId)
          .eq('status', 'scheduled')
          .order('scheduled_time', ascending: true);

      final ridesData = response as List<dynamic>;
      debugPrint('🔔 Found ${ridesData.length} rides for user $passengerId');
      debugPrint('🔔 === END GET SCHEDULED RIDES DEBUG ===');
      
      return ridesData.map((rideData) => _rideFromJson(rideData)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching scheduled rides: $e');
      return [];
    }
  }

  Future<bool> cancelScheduledRide(String rideId) async {
    try {
      await Supabase.instance.client
          .from('scheduled_rides')
          .update({'status': 'cancelled'})
          .eq('id', rideId);

      return true;
    } catch (e) {
      debugPrint('Error cancelling scheduled ride: $e');
      return false;
    }
  }

  Future<bool> updateScheduledRide({
    required String rideId,
    Location? pickupLocation,
    Location? dropoffLocation,
    DateTime? scheduledDateTime,
    double? estimatedFare,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      
      if (pickupLocation != null) {
        updateData['pickup_location'] = pickupLocation.displayName;
        updateData['pickup_latitude'] = pickupLocation.latitude;
        updateData['pickup_longitude'] = pickupLocation.longitude;
      }
      
      if (dropoffLocation != null) {
        updateData['destination_location'] = dropoffLocation.displayName;
        updateData['destination_latitude'] = dropoffLocation.latitude;
        updateData['destination_longitude'] = dropoffLocation.longitude;
      }
      
      if (scheduledDateTime != null) {
        updateData['scheduled_time'] = scheduledDateTime.toIso8601String();
      }
      
      if (estimatedFare != null) {
        updateData['estimated_fare'] = estimatedFare;
      }

      await Supabase.instance.client
          .from('scheduled_rides')
          .update(updateData)
          .eq('id', rideId);

      return true;
    } catch (e) {
      debugPrint('Error updating scheduled ride: $e');
      return false;
    }
  }

  Ride _rideFromJson(Map<String, dynamic> json) {
    return Ride.scheduled(
      id: json['id'].toString(),
      pickupLocation: json['pickup_location'] ?? 'Unknown',
      dropoffLocation: json['destination_location'] ?? 'Unknown',
      scheduledDateTime: DateTime.parse(json['scheduled_time']),
      fare: (json['estimated_fare'] ?? 0).toDouble(),
    );
  }
}
