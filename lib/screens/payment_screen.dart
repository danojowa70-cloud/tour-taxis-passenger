import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/inputs.dart';
import '../models/payment.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _method = 'Cash';
  bool _confirming = false;

  void _confirmPayment() async {
    setState(() => _confirming = true);
    await Future.delayed(const Duration(milliseconds: 700));
    final newPayment = PaymentRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: _method,
      amount: 1250,
      status: 'Paid',
      dateTime: DateTime.now(),
    );
    final list = [...ref.read(paymentsProvider)];
    list.insert(0, newPayment);
    ref.read(paymentsProvider.notifier).state = list;
    if (mounted) {
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment confirmed')));
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Payment'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select payment method', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _methodTile(context, 'Cash'),
              _methodTile(context, 'Card'),
              _methodTile(context, 'Wallet'),
              const Spacer(),
              AppleButton(label: _confirming ? 'Confirming…' : 'Confirm Payment', onPressed: _confirming ? () {} : _confirmPayment),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodTile(BuildContext context, String method) {
    final selected = _method == method;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2) : Colors.transparent),
      ),
      child: ListTile(
        onTap: () => setState(() => _method = method),
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
        title: Text(method),
      ),
    );
  }
}


