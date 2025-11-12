import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mpesa_service.dart';
import '../services/paypal_service.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  final double amount;
  final String? rideId;
  
  const PaymentMethodScreen({
    super.key,
    required this.amount,
    this.rideId,
  });

  @override
  ConsumerState<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  bool _loading = false;
  String? _selectedMethod;

  Future<void> _payMPesa() async {
    setState(() {
      _loading = true;
      _selectedMethod = 'mpesa';
    });
    
    try {
      final mpesa = MPesaService();
      await mpesa.launchMPesaPayment(
        amount: widget.amount,
        reference: widget.rideId ?? 'TourTaxi',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Complete M-Pesa Payment'),
          content: const Text('Finish the payment in M-Pesa, then tap "I have paid".'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('I have paid')),
          ],
        ),
      );
      if (!mounted) return;
      _handlePaymentSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('M-Pesa error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payPayPal() async {
    setState(() {
      _loading = true;
      _selectedMethod = 'paypal';
    });
    
    try {
      final paypal = PayPalService();
      await paypal.launchPayPalPayment(
        amount: widget.amount,
        currency: 'USD',
        reference: widget.rideId ?? 'TourTaxi',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Complete PayPal Payment'),
          content: const Text('Finish the payment in PayPal, then tap "I have paid".'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('I have paid')),
          ],
        ),
      );
      if (!mounted) return;
      _handlePaymentSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PayPal error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _handlePaymentSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment confirmed! Processing your request...'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Navigate back or to success screen
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('Choose Payment Method'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount to Pay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'KES ${widget.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Select Payment Method',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // M-Pesa option
              _buildPaymentTile(
                context: context,
                title: 'M-Pesa',
                subtitle: 'Pay via M-Pesa mobile money',
                icon: Icons.phone_android,
                color: Colors.green,
                isSelected: _selectedMethod == 'mpesa',
                onTap: _loading ? null : _payMPesa,
              ),
              
              const SizedBox(height: 12),
              
              // PayPal option
              _buildPaymentTile(
                context: context,
                title: 'PayPal',
                subtitle: 'Pay with PayPal account',
                icon: Icons.payment,
                color: Colors.blue[700]!,
                isSelected: _selectedMethod == 'paypal',
                onTap: _loading ? null : _payPayPal,
              ),
              
              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Redirecting to payment...'),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Info text
              const Padding(
                padding: EdgeInsets.all(0),
                child: SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? color
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.chevron_right,
              color: isSelected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}


