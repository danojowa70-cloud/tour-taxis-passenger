import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationData {
  final String driverId;
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final DateTime timestamp;

  const DriverLocationData({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
    required this.timestamp,
  });

  factory DriverLocationData.fromJson(Map<String, dynamic> json) {
    return DriverLocationData(
      driverId: json['driver_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['updated_at'] as String),
    );
  }

  LatLng get position => LatLng(latitude, longitude);
}

class DriverTrackingService {
  final SupabaseClient _client;
  final Map<String, StreamSubscription> _subscriptions = {};

  DriverTrackingService(this._client);

  /// Stream driver location updates for a specific driver
  Stream<DriverLocationData> trackDriver(String driverId) {
    return _client
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .map((data) {
      if (data.isNotEmpty) {
        return DriverLocationData.fromJson(data.first);
      }
      throw Exception('Driver location not found');
    });
  }

  /// Get current driver location (one-time fetch)
  Future<DriverLocationData?> getCurrentDriverLocation(String driverId) async {
    try {
      final response = await _client
          .from('driver_locations')
          .select()
          .eq('driver_id', driverId)
          .single();
      
      return DriverLocationData.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two positions
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Calculate estimated time of arrival based on current location and destination
  Duration calculateETA(DriverLocationData driverLocation, LatLng destination) {
    final distance = calculateDistance(driverLocation.position, destination);
    final speed = driverLocation.speed > 0 ? driverLocation.speed : 30; // Default 30 km/h
    
    // Convert speed from km/h to m/s and calculate time in seconds
    final speedMps = speed * 1000 / 3600;
    final timeInSeconds = distance / speedMps;
    
    return Duration(seconds: timeInSeconds.round());
  }

  /// Get all nearby drivers with their current locations
  Stream<List<DriverLocationData>> trackNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) {
    return _client
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .map((dataList) {
      return dataList
          .map((data) => DriverLocationData.fromJson(data))
          .where((driver) {
            final distance = Geolocator.distanceBetween(
              latitude,
              longitude,
              driver.latitude,
              driver.longitude,
            );
            return distance <= (radiusKm * 1000); // Convert km to meters
          })
          .toList();
    });
  }

  void dispose() {
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}

// Provider for driver tracking service
final driverTrackingServiceProvider = Provider<DriverTrackingService>((ref) {
  final service = DriverTrackingService(Supabase.instance.client);
  ref.onDispose(() => service.dispose());
  return service;
});

// Provider for tracking a specific driver
final driverLocationStreamProvider = StreamProvider.family<DriverLocationData, String>((ref, driverId) {
  final trackingService = ref.watch(driverTrackingServiceProvider);
  return trackingService.trackDriver(driverId);
});

// Provider for tracking nearby drivers
final nearbyDriversStreamProvider = StreamProvider.family<List<DriverLocationData>, Map<String, double>>((ref, location) {
  final trackingService = ref.watch(driverTrackingServiceProvider);
  return trackingService.trackNearbyDrivers(
    latitude: location['lat']!,
    longitude: location['lng']!,
    radiusKm: location['radius'] ?? 5.0,
  );
});