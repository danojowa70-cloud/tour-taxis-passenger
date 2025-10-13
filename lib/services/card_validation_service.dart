import 'package:card_scanner/card_scanner.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CardValidationService {
  final SupabaseClient _client;

  CardValidationService(this._client);

  /// Validate card number using Luhn algorithm
  static bool validateCardNumber(String cardNumber) {
    // Remove spaces and non-digits
    final cleanNumber = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanNumber.length < 13 || cleanNumber.length > 19) {
      return false;
    }

    return _luhnCheck(cleanNumber);
  }

  /// Validate expiry date
  static bool validateExpiryDate(String expiry) {
    // Expected format: MM/YY or MM/YYYY
    final cleanExpiry = expiry.replaceAll(RegExp(r'[^\d/]'), '');
    
    if (!RegExp(r'^\d{2}/\d{2,4}$').hasMatch(cleanExpiry)) {
      return false;
    }

    final parts = cleanExpiry.split('/');
    final month = int.tryParse(parts[0]);
    final yearStr = parts[1];
    
    if (month == null || month < 1 || month > 12) {
      return false;
    }

    // Convert 2-digit year to 4-digit
    final year = int.tryParse(yearStr.length == 2 ? '20$yearStr' : yearStr);
    if (year == null) return false;

    final now = DateTime.now();
    final expiryDate = DateTime(year, month + 1, 0); // Last day of expiry month
    
    return expiryDate.isAfter(now);
  }

  /// Validate CVV
  static bool validateCVV(String cvv, CardType cardType) {
    final cleanCVV = cvv.replaceAll(RegExp(r'[^\d]'), '');
    
    switch (cardType) {
      case CardType.amex:
        return cleanCVV.length == 4;
      default:
        return cleanCVV.length == 3;
    }
  }

  /// Get card type from number
  static CardType getCardType(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanNumber.isEmpty) return CardType.unknown;
    
    // Visa
    if (cleanNumber.startsWith('4')) {
      return CardType.visa;
    }
    
    // Mastercard
    if (cleanNumber.startsWith(RegExp(r'^5[1-5]')) || 
        cleanNumber.startsWith(RegExp(r'^2[2-7]'))) {
      return CardType.mastercard;
    }
    
    // American Express
    if (cleanNumber.startsWith('34') || cleanNumber.startsWith('37')) {
      return CardType.amex;
    }
    
    // Discover
    if (cleanNumber.startsWith('6011') || 
        cleanNumber.startsWith(RegExp(r'^65')) ||
        cleanNumber.startsWith(RegExp(r'^64[4-9]')) ||
        cleanNumber.startsWith(RegExp(r'^622'))) {
      return CardType.discover;
    }
    
    return CardType.unknown;
  }

  /// Format card number with spaces
  static String formatCardNumber(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    final cardType = getCardType(cleanNumber);
    
    switch (cardType) {
      case CardType.amex:
        // Format: XXXX XXXXXX XXXXX
        return cleanNumber.replaceAllMapped(
          RegExp(r'(\d{4})(\d{0,6})(\d{0,5})'),
          (match) {
            final parts = <String>[];
            if (match.group(1)!.isNotEmpty) parts.add(match.group(1)!);
            if (match.group(2)!.isNotEmpty) parts.add(match.group(2)!);
            if (match.group(3)!.isNotEmpty) parts.add(match.group(3)!);
            return parts.join(' ');
          },
        );
      default:
        // Format: XXXX XXXX XXXX XXXX
        return cleanNumber.replaceAllMapped(
          RegExp(r'(\d{4})(\d{0,4})(\d{0,4})(\d{0,4})'),
          (match) {
            final parts = <String>[];
            if (match.group(1)!.isNotEmpty) parts.add(match.group(1)!);
            if (match.group(2)!.isNotEmpty) parts.add(match.group(2)!);
            if (match.group(3)!.isNotEmpty) parts.add(match.group(3)!);
            if (match.group(4)!.isNotEmpty) parts.add(match.group(4)!);
            return parts.join(' ');
          },
        );
    }
  }

  /// Format expiry date
  static String formatExpiryDate(String expiry) {
    final cleanExpiry = expiry.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanExpiry.length <= 2) {
      return cleanExpiry;
    } else if (cleanExpiry.length <= 4) {
      return '${cleanExpiry.substring(0, 2)}/${cleanExpiry.substring(2)}';
    } else {
      return '${cleanExpiry.substring(0, 2)}/${cleanExpiry.substring(2, 4)}';
    }
  }

  /// Scan card using camera
  Future<ScannedCard?> scanCard() async {
    try {
      final card = await CardScanner.scanCard();
      return ScannedCard(
        cardNumber: card?.cardNumber ?? '',
        expiryDate: card?.expiryDate ?? '',
        cardholderName: card?.cardHolderName ?? '',
      );
    } catch (e) {
      throw Exception('Failed to scan card: $e');
    }
  }

  /// Create payment method with Stripe
  Future<PaymentMethod> createPaymentMethod({
    required String cardNumber,
    required String expiryDate,
    required String cvv,
    required String cardholderName,
    String? billingEmail,
  }) async {
    try {
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name: cardholderName,
              email: billingEmail,
            ),
          ),
        ),
      );

      return paymentMethod;
    } catch (e) {
      throw Exception('Failed to create payment method: $e');
    }
  }

  /// Save payment method to user's account
  Future<void> savePaymentMethod({
    required String userId,
    required PaymentMethod paymentMethod,
    required String cardholderName,
    bool isDefault = false,
  }) async {
    try {
      final card = paymentMethod.card;
      
      await _client.from('user_payment_methods').insert({
        'user_id': userId,
        'stripe_payment_method_id': paymentMethod.id,
        'card_brand': card.brand.toString(),
        'last_four': card.last4,
        'exp_month': card.expMonth,
        'exp_year': card.expYear,
        'cardholder_name': cardholderName,
        'is_default': isDefault,
        'created_at': DateTime.now().toIso8601String(),
      });

      // If this is set as default, update other cards
      if (isDefault) {
        await _client
            .from('user_payment_methods')
            .update({'is_default': false})
            .eq('user_id', userId)
            .neq('stripe_payment_method_id', paymentMethod.id);
      }
    } catch (e) {
      throw Exception('Failed to save payment method: $e');
    }
  }

  /// Get saved payment methods for user
  Future<List<SavedPaymentMethod>> getUserPaymentMethods(String userId) async {
    try {
      final response = await _client
          .from('user_payment_methods')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response
          .map<SavedPaymentMethod>((data) => SavedPaymentMethod.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to get payment methods: $e');
    }
  }

  /// Delete payment method
  Future<void> deletePaymentMethod(String paymentMethodId) async {
    try {
      // Note: detachPaymentMethod is not available in current Stripe version
      // The payment method will be managed on the server side
      
      // Delete from database
      await _client
          .from('user_payment_methods')
          .delete()
          .eq('stripe_payment_method_id', paymentMethodId);
    } catch (e) {
      throw Exception('Failed to delete payment method: $e');
    }
  }

  /// Luhn algorithm implementation
  static bool _luhnCheck(String cardNumber) {
    int sum = 0;
    bool isEven = false;
    
    // Process digits from right to left
    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);
      
      if (isEven) {
        digit *= 2;
        if (digit > 9) {
          digit = digit ~/ 10 + digit % 10;
        }
      }
      
      sum += digit;
      isEven = !isEven;
    }
    
    return sum % 10 == 0;
  }
}

enum CardType {
  visa,
  mastercard,
  amex,
  discover,
  unknown,
}

extension CardTypeExtension on CardType {
  String get displayName {
    switch (this) {
      case CardType.visa:
        return 'Visa';
      case CardType.mastercard:
        return 'Mastercard';
      case CardType.amex:
        return 'American Express';
      case CardType.discover:
        return 'Discover';
      case CardType.unknown:
        return 'Unknown';
    }
  }

  String get iconAsset {
    switch (this) {
      case CardType.visa:
        return 'assets/icons/visa.png';
      case CardType.mastercard:
        return 'assets/icons/mastercard.png';
      case CardType.amex:
        return 'assets/icons/amex.png';
      case CardType.discover:
        return 'assets/icons/discover.png';
      case CardType.unknown:
        return 'assets/icons/credit_card.png';
    }
  }
}

class ScannedCard {
  final String cardNumber;
  final String expiryDate;
  final String cardholderName;

  ScannedCard({
    required this.cardNumber,
    required this.expiryDate,
    required this.cardholderName,
  });
}

class SavedPaymentMethod {
  final String id;
  final String stripePaymentMethodId;
  final String cardBrand;
  final String lastFour;
  final int expMonth;
  final int expYear;
  final String cardholderName;
  final bool isDefault;
  final DateTime createdAt;

  SavedPaymentMethod({
    required this.id,
    required this.stripePaymentMethodId,
    required this.cardBrand,
    required this.lastFour,
    required this.expMonth,
    required this.expYear,
    required this.cardholderName,
    required this.isDefault,
    required this.createdAt,
  });

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) {
    return SavedPaymentMethod(
      id: json['id'] as String,
      stripePaymentMethodId: json['stripe_payment_method_id'] as String,
      cardBrand: json['card_brand'] as String,
      lastFour: json['last_four'] as String,
      expMonth: json['exp_month'] as int,
      expYear: json['exp_year'] as int,
      cardholderName: json['cardholder_name'] as String,
      isDefault: json['is_default'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get displayName {
    return '${cardBrand.toUpperCase()} •••• $lastFour';
  }

  String get expiryDisplay {
    return '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().substring(2)}';
  }
}