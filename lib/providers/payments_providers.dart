import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/stripe_service.dart';
import '../services/mpesa_service.dart';
import '../services/paypal_service.dart';
import '../services/wallet_service.dart';
import '../repositories/payments_repository.dart';
import '../repositories/wallet_repository.dart';

final stripeServiceProvider = Provider((ref) => StripeService());
final mpesaServiceProvider = Provider((ref) => MPesaService());
final paypalServiceProvider = Provider((ref) => PayPalService());
final walletServiceProvider = Provider((ref) => WalletService());

final paymentsRepositoryProvider = Provider((ref) => PaymentsRepository(
      stripe: ref.watch(stripeServiceProvider),
      mpesa: ref.watch(mpesaServiceProvider),
      paypal: ref.watch(paypalServiceProvider),
    ));

final walletRepositoryProvider = Provider((ref) => WalletRepository(ref.watch(walletServiceProvider)));


