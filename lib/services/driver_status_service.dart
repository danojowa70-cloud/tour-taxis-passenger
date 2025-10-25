import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverStatusService {
  final SupabaseClient _client;
  
  DriverStatusService(this._client);
  
  /// Update driver's online status in the active_drivers table
  Future<bool> updateDriverStatus({
    required String driverId,
    required bool isOnline,
    bool isAvailable = true,
  }) async {
    try {
      debugPrint('🚗 Updating driver status: $driverId - Online: $isOnline, Available: $isAvailable');
      
      // Use the database function to update driver status
      await _client.rpc('update_driver_online_status', params: {
        'driver_id': driverId,
        'online_status': isOnline,
        'available_status': isAvailable,
      });
      
      debugPrint('✅ Driver status updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update driver status: $e');
      return false;
    }
  }
  
  /// Set driver as online and available
  Future<bool> goOnline(String driverId) async {
    return updateDriverStatus(
      driverId: driverId,
      isOnline: true,
      isAvailable: true,
    );
  }
  
  /// Set driver as offline
  Future<bool> goOffline(String driverId) async {
    return updateDriverStatus(
      driverId: driverId,
      isOnline: false,
      isAvailable: false,
    );
  }
  
  /// Set driver as online but unavailable (e.g., on a ride)
  Future<bool> setBusy(String driverId) async {
    return updateDriverStatus(
      driverId: driverId,
      isOnline: true,
      isAvailable: false,
    );
  }
  
  /// Set driver as online and available again (after completing a ride)
  Future<bool> setAvailable(String driverId) async {
    return updateDriverStatus(
      driverId: driverId,
      isOnline: true,
      isAvailable: true,
    );
  }
  
  /// Get current driver status
  Future<Map<String, dynamic>?> getDriverStatus(String driverId) async {
    try {
      final response = await _client
          .from('active_drivers')
          .select('*')
          .eq('id', driverId)
          .single();
      
      return response;
    } catch (e) {
      debugPrint('❌ Failed to get driver status: $e');
      return null;
    }
  }
  
  /// Check if driver is online and available
  Future<bool> isDriverAvailable(String driverId) async {
    try {
      final status = await getDriverStatus(driverId);
      return status?['is_online'] == true && status?['is_available'] == true;
    } catch (e) {
      debugPrint('❌ Failed to check driver availability: $e');
      return false;
    }
  }
  
  /// Get count of online drivers in an area
  Future<int> getOnlineDriverCount({
    required double lat,
    required double lng,
    double radiusKm = 10.0,
  }) async {
    try {
      final result = await _client.rpc('get_driver_count_in_area', params: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
      });
      
      return result ?? 0;
    } catch (e) {
      debugPrint('❌ Failed to get driver count: $e');
      return 0;
    }
  }
  
  /// Stream driver status changes for a specific driver
  Stream<Map<String, dynamic>> streamDriverStatus(String driverId) {
    return _client
        .from('active_drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .map((data) => data.isNotEmpty ? data.first : {});
  }
  
  /// Update driver's location and keep them active
  Future<bool> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) async {
    try {
      // Update driver location
      await _client.from('driver_locations').upsert({
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading ?? 0.0,
        'speed': speed ?? 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // Update last_seen in active_drivers to keep them active
      await _client.from('active_drivers').update({
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', driverId);
      
      debugPrint('📍 Driver location updated: $driverId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update driver location: $e');
      return false;
    }
  }
}