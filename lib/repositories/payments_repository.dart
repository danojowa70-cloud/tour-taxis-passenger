import '../services/stripe_service.dart';
import '../services/mpesa_service.dart';
import '../services/paypal_service.dart';

class PaymentsRepository {
  final StripeService stripe;
  final MPesaService mpesa;
  final PayPalService paypal;
  PaymentsRepository({required this.stripe, required this.mpesa, required this.paypal});

  Future<void> payWithStripe({required double amount, required String currency}) async {
    final secret = await stripe.createPaymentIntent(amount: amount, currency: currency);
    await stripe.confirmPayment(secret);
  }

  Future<void> payWithMPesa({required String phone, required double amount}) async {
    final id = await mpesa.initiateStkPush(phone: phone, amount: amount);
    await mpesa.checkPaymentStatus(id);
  }

  Future<void> payWithPayPal({required double amount, required String currency}) async {
    final orderId = await paypal.createOrder(amount: amount, currency: currency);
    await paypal.captureOrder(orderId);
  }
}


