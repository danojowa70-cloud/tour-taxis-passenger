import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// M-Pesa Payment Service
/// Handles M-Pesa mobile money payments for Kenya
class MPesaService {
  // M-Pesa Business Details
  static const String businessNumber = '+254715055910'; // Your M-Pesa number
  static const String businessName = 'TourTaxi';
  
  /// Initiate M-Pesa payment
  /// Opens M-Pesa app or USSD for user to complete payment
  Future<String> initiateStkPush({
    required String phone, 
    required double amount,
    String? reference,
  }) async {
    try {
      debugPrint('💰 Initiating M-Pesa payment: KES ${amount.toInt()} to $businessNumber');
      
      // Try Method 1: Open M-Pesa app directly
      final success = await _openMPesaApp(amount: amount, reference: reference);
      
      if (success) {
        return 'mpesa_app_opened_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Fallback Method 2: Open USSD code
      await _openMPesaUSSD();
      return 'mpesa_ussd_opened_${DateTime.now().millisecondsSinceEpoch}';
      
    } catch (e) {
      debugPrint('❌ M-Pesa initiation error: $e');
      // Return ID anyway so user can pay manually
      return 'mpesa_manual_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Open M-Pesa app with pre-filled payment details
  Future<bool> _openMPesaApp({
    required double amount,
    String? reference,
  }) async {
    try {
      // M-Pesa deep link format
      final uri = Uri.parse(
        'mpesa://send?'
        'phone=$businessNumber&'
        'amount=${amount.toInt()}&'
        'ref=${reference ?? businessName}'
      );
      
      debugPrint('🔗 Opening M-Pesa app: $uri');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('⚠️ Could not open M-Pesa app: $e');
      return false;
    }
  }

  /// Open M-Pesa USSD code (*334#)
  Future<void> _openMPesaUSSD() async {
    try {
      final uri = Uri.parse('tel:*334#');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        debugPrint('📞 Opened M-Pesa USSD');
      } else {
        throw Exception('Cannot open phone dialer');
      }
    } catch (e) {
      debugPrint('❌ Failed to open USSD: $e');
      throw Exception('Please dial *334# manually to access M-Pesa');
    }
  }

  /// Check payment status (simplified for manual payments)
  Future<String> checkPaymentStatus(String checkoutRequestId) async {
    // For manual M-Pesa payments, we assume success after a delay
    // In production, verify via backend/webhook
    await Future.delayed(const Duration(seconds: 2));
    return 'SUCCESS';
  }

  /// Get payment instructions for manual payment
  String getPaymentInstructions({required double amount}) {
    return '''\nTo complete M-Pesa payment of KES ${amount.toInt()}:\n\n1. Dial *334# on your phone\n2. Select "Send Money"\n3. Enter: $businessNumber\n4. Amount: KES ${amount.toInt()}\n5. Enter your M-Pesa PIN\n6. Confirm the transaction\n\nOr use M-Pesa app to send to: $businessNumber\nReference: $businessName\n''';
  }

  /// Open M-Pesa app for user (alternative method)
  Future<void> launchMPesaPayment({
    required double amount,
    String? reference,
  }) async {
    final success = await _openMPesaApp(amount: amount, reference: reference);
    
    if (!success) {
      await _openMPesaUSSD();
    }
  }
}


