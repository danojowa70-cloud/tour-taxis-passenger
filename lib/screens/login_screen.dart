import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/inputs.dart';
import '../services/error_handler_service.dart';
import '../services/instant_ride_notifications_service.dart';
import '../services/scheduled_ride_notifications_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    
    final result = await ErrorHandlerService.handleAsync<AuthResponse>(
      () async {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        
        if (email.isEmpty || password.isEmpty) {
          throw Exception('Email and password are required');
        }
        
        return await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      },
      context: context,
      errorMessage: 'Failed to sign in. Please check your credentials.',
    );
    
    if (result != null && mounted) {
      final user = result.user;
      
      // Check if passenger record exists, if not create one with basic info
      if (user != null) {
        try {
          final existingPassenger = await Supabase.instance.client
              .from('passengers')
              .select()
              .eq('auth_user_id', user.id)
              .maybeSingle();
          
          if (existingPassenger == null) {
            // Create passenger record with available information
            final name = user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? 'User';
            final phone = user.phone ?? user.userMetadata?['phone'];
            
            await Supabase.instance.client.from('passengers').insert({
              'auth_user_id': user.id,
              'name': name,
              'email': user.email,
              if (phone != null) 'phone': phone,
              'created_at': DateTime.now().toIso8601String(),
            });
            
            debugPrint('✅ Created passenger record for existing user');
          }
        } catch (e) {
          debugPrint('⚠️ Error checking/creating passenger record: $e');
          // Continue with login even if this fails
        }
      }
      
      // Start listening for ride notifications after successful login
      final userId = user?.id;
      if (userId != null) {
        InstantRideNotificationsService.listenForRideUpdates(userId);
        ScheduledRideNotificationsService.listenForRideUpdates(userId);
        debugPrint('✅ Started listening for ride notifications for user: $userId');
      }
      
      if (!mounted) return;
      ErrorHandlerService.showSuccess(context, 'Welcome back!');
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
    
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ErrorHandlerService.showInfo(context, 'Enter your email first');
      return;
    }
    
    await ErrorHandlerService.handleAsync<void>(
      () => Supabase.instance.client.auth.resetPasswordForEmail(email),
      context: context,
      errorMessage: 'Failed to send password reset email.',
    );
    
    if (mounted) {
      ErrorHandlerService.showSuccess(
        context, 
        'Password reset email sent! Check your inbox.',
      );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to your TOURTAXI Passenger account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 24),
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 6),
              AppleButton(
                label: _loading ? 'Signing in…' : 'Sign In',
                onPressed: _loading ? () {} : _login,
              ),
              const Spacer(),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      TextSpan(
                        text: 'Sign up',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.of(context).pushNamed('/signup'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}


