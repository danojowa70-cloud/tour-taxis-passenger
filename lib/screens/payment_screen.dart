import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_providers.dart';
import '../providers/ride_flow_providers.dart';
import '../providers/realtime_providers.dart';
import '../providers/socket_ride_providers.dart';
import '../widgets/inputs.dart';
import '../services/mpesa_service.dart';
import '../services/paypal_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String? rideId;
  final double? fare;
  final String? rideType;
  
  const PaymentScreen({
    super.key,
    this.rideId,
    this.fare,
    this.rideType,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _method = 'Cash';
  bool _confirming = false;

  Future<void> _handlePaymentRedirect(double amount) async {
    try {
      if (_method == 'M-Pesa') {
        await MPesaService().launchMPesaPayment(amount: amount, reference: 'TourTaxi');
      } else if (_method == 'PayPal') {
        await PayPalService().launchPayPalPayment(amount: amount, currency: 'USD', reference: 'TourTaxi');
      }
    } catch (e) {
      debugPrint('Payment redirect error: $e');
    }
  }

  void _confirmPayment() async {
    setState(() => _confirming = true);
    
    // Use passed fare if available (scheduled ride), otherwise use rideFlow (instant ride)
    final flow = ref.read(rideFlowProvider);
    final fare = widget.fare ?? flow.estimatedFare ?? 1250;

    // For M-Pesa and PayPal, redirect to their apps first
    if (_method == 'M-Pesa' || _method == 'PayPal') {
      await _handlePaymentRedirect(fare);
      // Give time for app switch
      await Future.delayed(const Duration(seconds: 2));
    } else {
      await Future.delayed(const Duration(milliseconds: 700));
    }
    
    // Save payment to database
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId != null) {
        await supabase.from('payments').insert({
          'user_id': userId,
          'ride_id': widget.rideId ?? flow.rideId,
          'amount': fare.toDouble(),
          'method': _method.toLowerCase(),
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Payment saved to database');
        
        // Invalidate the paymentsProvider to force refresh
        ref.invalidate(paymentsProvider);
      }
    } catch (e) {
      debugPrint('❌ Error saving payment to database: $e');
      // Continue anyway - don't block user flow
    }
    
    // IMPORTANT: Clear ALL ride state after payment is complete
    // This ensures fresh state for the next ride booking
    ref.read(rideFlowProvider.notifier).clearAll();
    ref.read(rideRealtimeProvider.notifier).clearRide();
    ref.read(socketRideProvider.notifier).reset();
    debugPrint('🧹 All ride states cleared after payment completion');
    
    if (mounted) {
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment confirmed')));
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(rideFlowProvider);
    // Use passed fare if available (scheduled ride), otherwise use rideFlow (instant ride)
    final fare = widget.fare ?? flow.estimatedFare ?? 1250;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Payment', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trip Completed',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KSh',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fare.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '✓ Trip successfully completed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Payment Method',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              _methodTile(context, 'Cash', Icons.attach_money, 'Pay with cash'),
              _methodTile(context, 'M-Pesa', Icons.phone_android, 'Mobile Money'),
              _methodTile(context, 'PayPal', Icons.account_balance_wallet, 'PayPal Account'),
              const Spacer(),
              AppleButton(
                label: _confirming ? 'Processing…' : 'Proceed to Payment',
                onPressed: _confirming ? () {} : _confirmPayment,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodTile(BuildContext context, String method, IconData icon, String subtitle) {
    final selected = _method == method;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected 
              ? Theme.of(context).colorScheme.primary 
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => setState(() => _method = method),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: selected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          method,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}


