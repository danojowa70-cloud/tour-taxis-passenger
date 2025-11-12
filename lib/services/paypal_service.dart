import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// PayPal Payment Service
/// Handles PayPal payments by redirecting to PayPal app/web
class PayPalService {
  // PayPal Business Details
  static const String paypalEmail = 'danojowa@gmail.com'; // Your PayPal email
  static const String businessName = 'TourTaxi';
  
  /// Create PayPal order and redirect user to PayPal
  Future<String> createOrder({
    required double amount, 
    required String currency,
    String? description,
  }) async {
    try {
      debugPrint('💳 Initiating PayPal payment: $currency $amount to $paypalEmail');
      
      // Open PayPal for payment
      await _openPayPalPayment(
        amount: amount,
        currency: currency,
        description: description,
      );
      
      return 'paypal_opened_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('❌ PayPal initiation error: $e');
      rethrow;
    }
  }

  /// Open PayPal app or web for payment
  Future<void> _openPayPalPayment({
    required double amount,
    required String currency,
    String? description,
  }) async {
    try {
      // Method 1: Try PayPal app deep link
      final appSuccess = await _openPayPalApp(
        amount: amount,
        currency: currency,
        description: description,
      );
      
      if (appSuccess) {
        return;
      }
      
      // Method 2: Fallback to PayPal.Me link (web)
      await _openPayPalWeb(
        amount: amount,
        currency: currency,
      );
    } catch (e) {
      debugPrint('❌ Failed to open PayPal: $e');
      rethrow;
    }
  }

  /// Open PayPal app
  Future<bool> _openPayPalApp({
    required double amount,
    required String currency,
    String? description,
  }) async {
    try {
      // PayPal app deep link format
      final uri = Uri.parse(
        'paypal://paypalme/$paypalEmail/$amount$currency'
      );
      
      debugPrint('🔗 Opening PayPal app: $uri');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('⚠️ Could not open PayPal app: $e');
      return false;
    }
  }

  /// Open PayPal.Me web link
  Future<void> _openPayPalWeb({
    required double amount,
    required String currency,
  }) async {
    try {
      // PayPal.Me link format
      final paypalMeUrl = 'https://paypal.me/$paypalEmail/$amount$currency';
      final uri = Uri.parse(paypalMeUrl);
      
      debugPrint('🌐 Opening PayPal web: $uri');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Cannot open PayPal');
      }
    } catch (e) {
      debugPrint('❌ Failed to open PayPal web: $e');
      throw Exception('Please visit paypal.me/$paypalEmail to complete payment');
    }
  }

  /// Open PayPal for user (direct method)
  Future<void> launchPayPalPayment({
    required double amount,
    required String currency,
    String? reference,
  }) async {
    await _openPayPalPayment(
      amount: amount,
      currency: currency,
      description: reference ?? businessName,
    );
  }

  /// Capture PayPal order (verify payment)
  Future<void> captureOrder(String orderId) async {
    // For manual PayPal payments, we assume success after opening
    // In production, verify via PayPal webhooks or API
    await Future.delayed(const Duration(seconds: 2));
  }

  /// Get payment instructions
  String getPaymentInstructions({required double amount, required String currency}) {
    return '''\nTo complete PayPal payment of $currency $amount:\n\n1. Open PayPal app or visit:\n   paypal.me/$paypalEmail\n\n2. Enter amount: $currency $amount\n\n3. Complete the payment\n\nOr send to PayPal email: $paypalEmail\n''';
  }
}


