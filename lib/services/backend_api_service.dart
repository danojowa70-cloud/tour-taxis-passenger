import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class BackendApiService {
  // Production backend URL - your deployed Render backend
  static const String baseUrl = 'https://tourtaxi-unified-backend.onrender.com';
  
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Health check - Test if backend is working
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      );
      
      debugPrint('🏥 Backend health check: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ Backend health check failed: $e');
      return false;
    }
  }

  /// Create a ride request via backend API
  static Future<Map<String, dynamic>?> createRide({
    required String passengerId,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> destination,
    String? vehicleType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final body = {
        'passengerId': passengerId,
        'pickup': pickup,
        'destination': destination,
        'vehicleType': vehicleType ?? 'sedan',
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/rides'),
        headers: _headers,
        body: json.encode(body),
      );

      debugPrint('🚗 Create ride response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('⚠️ Create ride failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ Create ride error: $e');
      return null;
    }
  }

  /// Get ride history for a passenger
  static Future<List<Map<String, dynamic>>> getRideHistory(String passengerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/rides/history/$passengerId'),
        headers: _headers,
      );

      debugPrint('📜 Ride history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['rides'] ?? []);
      } else {
        debugPrint('⚠️ Get ride history failed: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('⚠️ Get ride history error: $e');
      return [];
    }
  }

  /// Process payment via backend API
  static Future<Map<String, dynamic>?> processPayment({
    required String rideId,
    required String passengerId,
    required double amount,
    required String method, // 'cash', 'card', 'wallet', 'online'
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final body = {
        'rideId': rideId,
        'passengerId': passengerId,
        'amount': amount,
        'method': method,
        'timestamp': DateTime.now().toIso8601String(),
        'details': paymentDetails ?? {},
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments'),
        headers: _headers,
        body: json.encode(body),
      );

      debugPrint('💳 Process payment response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('⚠️ Process payment failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ Process payment error: $e');
      return null;
    }
  }

  /// Update payment status
  static Future<bool> updatePaymentStatus({
    required String paymentId,
    required String status, // 'pending', 'paid', 'failed', 'refunded'
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = {
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': metadata ?? {},
      };

      final response = await http.patch(
        Uri.parse('$baseUrl/api/payments/$paymentId'),
        headers: _headers,
        body: json.encode(body),
      );

      debugPrint('💳 Update payment status response: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ Update payment status error: $e');
      return false;
    }
  }

  /// Get API status and information
  static Future<Map<String, dynamic>?> getApiInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/info'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Get API info error: $e');
      return null;
    }
  }
}