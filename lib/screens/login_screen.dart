import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/inputs.dart';
import '../services/error_handler_service.dart';

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
      ErrorHandlerService.showSuccess(context, 'Welcome back!');
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


