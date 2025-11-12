import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../models/payment.dart';

// Theme mode provider: true for dark, false for light (system default false)
class ThemeController extends StateNotifier<bool> {
  ThemeController(super.state);

  static const _key = 'theme_dark';

  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? false;
    return ThemeController(isDark);
  }

  Future<void> setDark(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final themeDarkProvider = StateNotifierProvider<ThemeController, bool>((ref) => ThemeController(false));

// Ride history provider - fetches from database
final ridesProvider = FutureProvider.autoDispose<List<Ride>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    
    if (userId == null) {
      // Return demo data if not logged in
      return [
        Ride(
          id: 'r1',
          passengerId: 'demo',
          passengerName: 'Demo User',
          passengerPhone: '',
          pickupLatitude: 50.8467,
          pickupLongitude: 4.3525,
          pickupAddress: 'Grand Place, Brussels',
          destinationLatitude: 50.9010,
          destinationLongitude: 4.4844,
          destinationAddress: 'Brussels Airport',
          driverName: 'Alex Janssens',
          driverVehicle: 'Tesla Model 3 - 1ABC234',
          fare: '38.5',
          status: 'Completed',
          requestedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        ),
        Ride(
          id: 'r2',
          passengerId: 'demo',
          passengerName: 'Demo User',
          passengerPhone: '',
          pickupLatitude: 50.8622,
          pickupLongitude: 4.3499,
          pickupAddress: 'Tour & Taxis',
          destinationLatitude: 50.8427,
          destinationLongitude: 4.3761,
          destinationAddress: 'EU Parliament',
          driverName: 'Marie Dubois',
          driverVehicle: 'BMW i3 - 2XYZ567',
          fare: '18.0',
          status: 'Completed',
          requestedAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
        ),
      ];
    }
    
    // First get passenger ID from passengers table
    final passengerResponse = await supabase
        .from('passengers')
        .select('id')
        .eq('auth_user_id', userId)
        .maybeSingle();
    
    if (passengerResponse == null) {
      debugPrint('⚠️ No passenger record found for user');
      return [];
    }
    
    final passengerId = passengerResponse['id'];
    
    // Fetch rides for this passenger
    final response = await supabase
        .from('rides')
        .select('''
          id,
          passenger_id,
          passenger_name,
          passenger_phone,
          pickup_latitude,
          pickup_longitude,
          pickup_address,
          destination_latitude,
          destination_longitude,
          destination_address,
          fare,
          status,
          requested_at,
          completed_at,
          driver_id,
          drivers!inner(
            name,
            vehicle_type,
            vehicle_number,
            vehicle_make,
            vehicle_model
          )
        ''')
        .eq('passenger_id', passengerId)
        .inFilter('status', ['completed', 'cancelled'])
        .order('requested_at', ascending: false)
        .limit(50); // Last 50 rides
    
    if (response.isEmpty) {
      return [];
    }
    
    return (response as List).map((json) {
      final driver = json['drivers'];
      String driverName = 'Driver';
      String driverVehicle = 'Vehicle';
      
      if (driver != null) {
        driverName = driver['name']?.toString() ?? 'Driver';
        final make = driver['vehicle_make']?.toString() ?? '';
        final model = driver['vehicle_model']?.toString() ?? '';
        final number = driver['vehicle_number']?.toString() ?? '';
        final vehicleType = driver['vehicle_type']?.toString() ?? '';
        
        if (make.isNotEmpty && model.isNotEmpty) {
          driverVehicle = '$make $model - $number';
        } else if (vehicleType.isNotEmpty) {
          driverVehicle = '$vehicleType - $number';
        } else {
          driverVehicle = number.isNotEmpty ? number : 'Vehicle';
        }
      }
      
      return Ride(
        id: json['id']?.toString() ?? '',
        passengerId: json['passenger_id']?.toString() ?? '',
        passengerName: json['passenger_name']?.toString() ?? 'Passenger',
        passengerPhone: json['passenger_phone']?.toString() ?? '',
        pickupLatitude: (json['pickup_latitude'] as num?)?.toDouble() ?? 0.0,
        pickupLongitude: (json['pickup_longitude'] as num?)?.toDouble() ?? 0.0,
        pickupAddress: json['pickup_address']?.toString() ?? 'Pickup Location',
        destinationLatitude: (json['destination_latitude'] as num?)?.toDouble() ?? 0.0,
        destinationLongitude: (json['destination_longitude'] as num?)?.toDouble() ?? 0.0,
        destinationAddress: json['destination_address']?.toString() ?? 'Destination',
        driverName: driverName,
        driverVehicle: driverVehicle,
        fare: (json['fare'] as num?)?.toString() ?? '0',
        status: _formatRideStatus(json['status']?.toString() ?? 'unknown'),
        requestedAt: json['requested_at'] != null
            ? DateTime.parse(json['requested_at'])
            : DateTime.now(),
      );
    }).toList();
  } catch (e) {
    debugPrint('❌ Error loading rides from database: $e');
    return [];
  }
});

// Helper function to format ride status for display
String _formatRideStatus(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'started':
      return 'In Progress';
    case 'accepted':
      return 'Accepted';
    case 'requested':
      return 'Requested';
    default:
      return status;
  }
}

// Payment history provider - fetches from database
final paymentsProvider = FutureProvider.autoDispose<List<PaymentRecord>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    
    if (userId == null) {
      // Return demo data if not logged in
      return [
        PaymentRecord(
          id: 'p1',
          method: 'Card',
          amount: 38.5,
          status: 'Paid',
          dateTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        ),
        PaymentRecord(
          id: 'p2',
          method: 'Wallet',
          amount: 18.0,
          status: 'Paid',
          dateTime: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
        ),
      ];
    }
    
    final response = await supabase
        .from('payments')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100); // Last 100 payments
    
    if (response.isEmpty) {
      // Return empty list if no payments yet
      return [];
    }
    
    return (response as List).map((json) {
      return PaymentRecord(
        id: json['id']?.toString() ?? '',
        method: _formatPaymentMethod(json['method']?.toString() ?? 'cash'),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        status: _formatPaymentStatus(json['status']?.toString() ?? 'completed'),
        dateTime: json['created_at'] != null 
            ? DateTime.parse(json['created_at']) 
            : DateTime.now(),
      );
    }).toList();
  } catch (e) {
    debugPrint('❌ Error loading payments from database: $e');
    // Return empty list on error
    return [];
  }
});

// Helper function to format payment method for display
String _formatPaymentMethod(String method) {
  switch (method.toLowerCase()) {
    case 'cash':
      return 'Cash';
    case 'mpesa':
    case 'm-pesa':
      return 'M-Pesa';
    case 'paypal':
      return 'PayPal';
    case 'card':
      return 'Card';
    case 'wallet':
      return 'Wallet';
    default:
      return method;
  }
}

// Helper function to format payment status for display
String _formatPaymentStatus(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return 'Paid';
    case 'pending':
      return 'Pending';
    case 'failed':
      return 'Failed';
    default:
      return status;
  }
}


