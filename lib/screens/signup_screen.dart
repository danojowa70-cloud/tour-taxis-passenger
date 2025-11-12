import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/inputs.dart';
import '../services/instant_ride_notifications_service.dart';
import '../services/scheduled_ride_notifications_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;

  Future<void> _signup() async {
    setState(() => _loading = true);
    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final phone = _phoneController.text.trim();
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('Name, email and password are required');
      }
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: { 'full_name': name, 'phone': phone },
      );
      
      // Create passenger record in database
      if (authResponse.user != null) {
        try {
          await Supabase.instance.client.from('passengers').upsert({
            'auth_user_id': authResponse.user!.id,
            'name': name,
            'email': email,
            'phone': phone,
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'auth_user_id');
          debugPrint('✅ Passenger record created with name: $name');
        } catch (e) {
          debugPrint('⚠️ Failed to create passenger record: $e');
          // Continue anyway - the auth metadata has the name
        }
      }
      
      if (!mounted) return;
      
      // Start listening for ride notifications after successful signup
      final userId = authResponse.user?.id;
      if (userId != null) {
        InstantRideNotificationsService.listenForRideUpdates(userId);
        ScheduledRideNotificationsService.listenForRideUpdates(userId);
        debugPrint('✅ Started listening for ride notifications for new user: $userId');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome $name! Your account has been created successfully.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Create account',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 24),
                AppleTextField(
                  controller: _nameController,
                  hintText: 'Full name',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                AppleTextField(
                  controller: _emailController,
                  hintText: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                AppleTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                AppleTextField(
                  controller: _phoneController,
                  hintText: 'Phone number',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signup(),
                ),
                const SizedBox(height: 18),
                AppleButton(
                  label: _loading ? 'Creating…' : 'Create Account',
                  onPressed: _loading ? () {} : _signup,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


