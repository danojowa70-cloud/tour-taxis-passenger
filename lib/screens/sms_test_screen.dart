import 'package:flutter/material.dart';
import '../services/twilio_sms_service.dart';

class SmsTestScreen extends StatefulWidget {
  const SmsTestScreen({super.key});

  @override
  State<SmsTestScreen> createState() => _SmsTestScreenState();
}

class _SmsTestScreenState extends State<SmsTestScreen> {
  final _phoneController = TextEditingController(text: '+254');
  final _messageController = TextEditingController(text: 'Test SMS from TourTaxi!');
  bool _isSending = false;
  String? _result;

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendTestSms() async {
    if (_phoneController.text.isEmpty || _messageController.text.isEmpty) {
      setState(() {
        _result = '❌ Please fill in all fields';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _result = null;
    });

    final success = await TwilioSmsService.sendSms(
      toPhoneNumber: _phoneController.text.trim(),
      message: _messageController.text.trim(),
    );

    setState(() {
      _isSending = false;
      _result = success 
          ? '✅ SMS sent successfully!'
          : '❌ Failed to send SMS. Check console for details.';
    });
  }

  Future<void> _sendBookingConfirmation() async {
    setState(() => _isSending = true);

    final success = await TwilioSmsService.sendBookingConfirmation(
      phoneNumber: _phoneController.text.trim(),
      bookingId: 'TT${DateTime.now().millisecondsSinceEpoch}',
      vehicleType: 'Sedan',
      pickupLocation: 'Nairobi CBD',
      dropoffLocation: 'Jomo Kenyatta Airport',
    );

    setState(() {
      _isSending = false;
      _result = success 
          ? '✅ Booking confirmation sent!'
          : '❌ Failed to send. Check console.';
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _isSending = true);

    final otp = (DateTime.now().millisecondsSinceEpoch % 900000 + 100000).toString();

    final success = await TwilioSmsService.sendOtp(
      phoneNumber: _phoneController.text.trim(),
      otp: otp,
    );

    setState(() {
      _isSending = false;
      _result = success 
          ? '✅ OTP sent: $otp'
          : '❌ Failed to send OTP. Check console.';
    });
  }

  Future<void> _sendPremiumBooking() async {
    setState(() => _isSending = true);

    final success = await TwilioSmsService.sendPremiumBookingConfirmation(
      phoneNumber: _phoneController.text.trim(),
      bookingId: 'BP${DateTime.now().millisecondsSinceEpoch}',
      vehicleType: 'Helicopter',
      origin: 'Nairobi',
      destination: 'Mombasa',
      departureTime: 'Tomorrow at 10:00 AM',
    );

    setState(() {
      _isSending = false;
      _result = success 
          ? '✅ Premium booking confirmation sent!'
          : '❌ Failed to send. Check console.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Test'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Twilio SMS Test',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure you have configured your Twilio credentials in twilio_sms_service.dart',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Phone number input
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '+254712345678',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                helperText: 'Use E.164 format (e.g., +254...)',
              ),
            ),

            const SizedBox(height: 16),

            // Message input
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'Enter your test message',
                prefixIcon: const Icon(Icons.message),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Send custom SMS button
            ElevatedButton(
              onPressed: _isSending ? null : _sendTestSms,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Custom SMS', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 8),

            Text(
              'Test Pre-built Templates',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Booking confirmation button
            OutlinedButton.icon(
              onPressed: _isSending ? null : _sendBookingConfirmation,
              icon: const Icon(Icons.local_taxi),
              label: const Text('Send Booking Confirmation'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // OTP button
            OutlinedButton.icon(
              onPressed: _isSending ? null : _sendOtp,
              icon: const Icon(Icons.security),
              label: const Text('Send OTP'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Premium booking button
            OutlinedButton.icon(
              onPressed: _isSending ? null : _sendPremiumBooking,
              icon: const Icon(Icons.flight),
              label: const Text('Send Premium Booking'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Result message
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result!.startsWith('✅') 
                      ? Colors.green.shade50 
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _result!.startsWith('✅') 
                        ? Colors.green.shade200 
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _result!.startsWith('✅') 
                          ? Icons.check_circle_outline 
                          : Icons.error_outline,
                      color: _result!.startsWith('✅') 
                          ? Colors.green.shade700 
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _result!,
                        style: TextStyle(
                          color: _result!.startsWith('✅') 
                              ? Colors.green.shade900 
                              : Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Help text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Phone numbers must use E.164 format (+254...)\n'
                    '• Check Flutter console for detailed logs\n'
                    '• Twilio trial accounts can only send to verified numbers\n'
                    '• Each SMS costs money - monitor your usage',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
