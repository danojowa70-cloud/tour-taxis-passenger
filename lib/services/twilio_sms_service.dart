import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TwilioSmsService {
  // ⚠️ WARNING: DO NOT put credentials in production app!
  // This should be moved to a backend server or use environment variables
  static const String _accountSid = 'AC87248ccf5627d839bccb19564a808fb';
  static const String _authToken = 'YOUR_AUTH_TOKEN_HERE'; // You need to provide this
  static const String _twilioPhoneNumber = 'YOUR_TWILIO_PHONE_NUMBER'; // e.g., +1234567890
  
  /// Send SMS via Twilio API
  /// 
  /// Parameters:
  /// - [toPhoneNumber]: Recipient phone number in E.164 format (e.g., +254712345678)
  /// - [message]: SMS message body
  /// 
  /// Returns: true if SMS sent successfully, false otherwise
  static Future<bool> sendSms({
    required String toPhoneNumber,
    required String message,
  }) async {
    try {
      // Validate phone number format
      if (!toPhoneNumber.startsWith('+')) {
        debugPrint('❌ Phone number must be in E.164 format (starting with +)');
        return false;
      }
      
      if (_authToken == 'YOUR_AUTH_TOKEN_HERE') {
        debugPrint('❌ Twilio Auth Token not configured');
        return false;
      }
      
      if (_twilioPhoneNumber == 'YOUR_TWILIO_PHONE_NUMBER') {
        debugPrint('❌ Twilio Phone Number not configured');
        return false;
      }
      
      debugPrint('📱 Sending SMS to $toPhoneNumber...');
      
      // Twilio API endpoint
      final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json',
      );
      
      // Create auth header
      final auth = base64Encode(utf8.encode('$_accountSid:$_authToken'));
      
      // Send request
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $auth',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': _twilioPhoneNumber,
          'To': toPhoneNumber,
          'Body': message,
        },
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ SMS sent successfully! SID: ${data['sid']}');
        return true;
      } else {
        final error = jsonDecode(response.body);
        debugPrint('❌ Twilio API error: ${error['message']}');
        debugPrint('Error code: ${error['code']}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to send SMS: $e');
      return false;
    }
  }
  
  /// Send booking confirmation SMS
  static Future<bool> sendBookingConfirmation({
    required String phoneNumber,
    required String bookingId,
    required String vehicleType,
    required String pickupLocation,
    required String dropoffLocation,
  }) async {
    final message = '''
🚕 TourTaxi Booking Confirmed!

Booking ID: $bookingId
Vehicle: $vehicleType
From: $pickupLocation
To: $dropoffLocation

Thank you for choosing TourTaxi!
''';
    
    return sendSms(toPhoneNumber: phoneNumber, message: message);
  }
  
  /// Send OTP SMS
  static Future<bool> sendOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final message = '''
Your TourTaxi verification code is: $otp

Do not share this code with anyone.
''';
    
    return sendSms(toPhoneNumber: phoneNumber, message: message);
  }
  
  /// Send driver arrival notification
  static Future<bool> sendDriverArrivalNotification({
    required String phoneNumber,
    required String driverName,
    required String vehicleNumber,
  }) async {
    final message = '''
🚗 Your TourTaxi driver has arrived!

Driver: $driverName
Vehicle: $vehicleNumber

Please proceed to your pickup location.
''';
    
    return sendSms(toPhoneNumber: phoneNumber, message: message);
  }
  
  /// Send ride started notification
  static Future<bool> sendRideStartedNotification({
    required String phoneNumber,
    required String destination,
  }) async {
    final message = '''
🚀 Your TourTaxi ride has started!

Destination: $destination

Have a safe journey!
''';
    
    return sendSms(toPhoneNumber: phoneNumber, message: message);
  }
  
  /// Send ride completed notification
  static Future<bool> sendRideCompletedNotification({
    required String phoneNumber,
    required String fare,
  }) async {
    final message = '''
✅ Ride completed successfully!

Fare: $fare

Thank you for using TourTaxi!
''';
    
    return sendSms(toPhoneNumber: phoneNumber, message: message);
  }
  
  /// Send premium booking confirmation
  static Future<bool> sendPremiumBookingConfirmation({
    required String phoneNumber,
    required String bookingId,
    required String vehicleType,
    required String origin,
    required String destination,
    required String departureTime,
  }) async {
    final message = '''
✈️ Premium Booking Confirmed!

Booking ID: $bookingId
Vehicle: $vehicleType
From: $origin
To: $destination
Departure: $departureTime

Your boarding pass has been generated.
''';
    
    return sendSms(toPhoneNumber: phoneNumber, message: message);
  }
}
