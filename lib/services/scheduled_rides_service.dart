import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ride.dart';
import '../models/location.dart';

class ScheduledRidesService {
  // Replace with your actual API base URL
  static const String _baseUrl = 'https://your-api.com/api';
  
  // In a real app, get this from authentication service
  static String get _userId => 'current_user_id';
  
  Future<bool> scheduleRide({
    required Location pickupLocation,
    required Location dropoffLocation,
    required DateTime scheduledDateTime,
    required double estimatedFare,
    int? distanceMeters,
    int? durationSeconds,
  }) async {
    try {
      final body = json.encode({
        'user_id': _userId,
        'pickup_location': {
          'name': pickupLocation.name,
          'formatted_address': pickupLocation.formattedAddress,
          'latitude': pickupLocation.latitude,
          'longitude': pickupLocation.longitude,
          'place_id': pickupLocation.placeId,
        },
        'dropoff_location': {
          'name': dropoffLocation.name,
          'formatted_address': dropoffLocation.formattedAddress,
          'latitude': dropoffLocation.latitude,
          'longitude': dropoffLocation.longitude,
          'place_id': dropoffLocation.placeId,
        },
        'scheduled_datetime': scheduledDateTime.toIso8601String(),
        'estimated_fare': estimatedFare,
        'distance_meters': distanceMeters,
        'duration_seconds': durationSeconds,
        'status': 'scheduled',
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/scheduled-rides'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer your_auth_token', // Replace with actual token
        },
        body: body,
      );

      return response.statusCode == 201;
    } catch (e) {
      // For now, simulate successful scheduling
      // In a real app, handle the error appropriately
      print('Error scheduling ride: $e');
      return true; // Return true to simulate success
    }
  }

  Future<List<Ride>> getScheduledRides() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/scheduled-rides?user_id=$_userId'),
        headers: {
          'Authorization': 'Bearer your_auth_token', // Replace with actual token
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final ridesData = data['rides'] as List<dynamic>? ?? [];
        
        return ridesData.map((rideData) => _rideFromJson(rideData)).toList();
      }
      
      return [];
    } catch (e) {
      // Return mock data for now
      print('Error fetching scheduled rides: $e');
      return _getMockScheduledRides();
    }
  }

  Future<bool> cancelScheduledRide(String rideId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/scheduled-rides/$rideId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer your_auth_token', // Replace with actual token
        },
        body: json.encode({
          'status': 'cancelled',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error cancelling scheduled ride: $e');
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
        updateData['pickup_location'] = {
          'name': pickupLocation.name,
          'formatted_address': pickupLocation.formattedAddress,
          'latitude': pickupLocation.latitude,
          'longitude': pickupLocation.longitude,
          'place_id': pickupLocation.placeId,
        };
      }
      
      if (dropoffLocation != null) {
        updateData['dropoff_location'] = {
          'name': dropoffLocation.name,
          'formatted_address': dropoffLocation.formattedAddress,
          'latitude': dropoffLocation.latitude,
          'longitude': dropoffLocation.longitude,
          'place_id': dropoffLocation.placeId,
        };
      }
      
      if (scheduledDateTime != null) {
        updateData['scheduled_datetime'] = scheduledDateTime.toIso8601String();
      }
      
      if (estimatedFare != null) {
        updateData['estimated_fare'] = estimatedFare;
      }

      final response = await http.patch(
        Uri.parse('$_baseUrl/scheduled-rides/$rideId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer your_auth_token', // Replace with actual token
        },
        body: json.encode(updateData),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating scheduled ride: $e');
      return false;
    }
  }

  Ride _rideFromJson(Map<String, dynamic> json) {
    return Ride.scheduled(
      id: json['id'].toString(),
      pickupLocation: json['pickup_location']['name'] ?? 'Unknown',
      dropoffLocation: json['dropoff_location']['name'] ?? 'Unknown',
      scheduledDateTime: DateTime.parse(json['scheduled_datetime']),
      fare: (json['estimated_fare'] ?? 0).toDouble(),
    );
  }

  List<Ride> _getMockScheduledRides() {
    final now = DateTime.now();
    return [
      Ride.scheduled(
        id: '1',
        pickupLocation: 'Home',
        dropoffLocation: 'Office',
        scheduledDateTime: now.add(const Duration(hours: 2)),
        fare: 450.0,
      ),
      Ride.scheduled(
        id: '2',
        pickupLocation: 'Sarit Centre',
        dropoffLocation: 'JKIA Terminal 1A',
        scheduledDateTime: now.add(const Duration(days: 1)),
        fare: 800.0,
      ),
      Ride.scheduled(
        id: '3',
        pickupLocation: 'Westlands',
        dropoffLocation: 'Nairobi CBD',
        scheduledDateTime: now.add(const Duration(days: 2, hours: 3)),
        fare: 350.0,
      ),
    ];
  }
}