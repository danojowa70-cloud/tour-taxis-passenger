import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payments_providers.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  ConsumerState<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  bool _loading = false;

  Future<void> _payStripe() async {
    setState(() => _loading = true);
    try {
      await ref.read(paymentsRepositoryProvider).payWithStripe(amount: 12.5, currency: 'EUR');
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stripe payment success')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stripe error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payMPesa() async {
    setState(() => _loading = true);
    try {
      await ref.read(paymentsRepositoryProvider).payWithMPesa(phone: '+254700000000', amount: 12.5);
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('M-Pesa payment success')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('M-Pesa error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payPayPal() async {
    setState(() => _loading = true);
    try {
      await ref.read(paymentsRepositoryProvider).payWithPayPal(amount: 12.5, currency: 'EUR');
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PayPal payment success')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PayPal error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Payment Methods'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _tile(context, 'Stripe (Card + 3DS)', Icons.credit_card, _loading ? null : _payStripe),
              _tile(context, 'M-Pesa (STK Push)', Icons.phone_iphone, _loading ? null : _payMPesa),
              _tile(context, 'PayPal', Icons.account_balance_wallet_outlined, _loading ? null : _payPayPal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String title, IconData icon, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}


