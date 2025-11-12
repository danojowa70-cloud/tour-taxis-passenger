import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Hide system UI for full screen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    
    // Navigate after delay
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _navigateToNextScreen();
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
  
  void _navigateToNextScreen() {
    // Check if user is authenticated
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user != null) {
      // User is logged in, go to dashboard screen
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      // User not logged in, go to login screen
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo Image
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.15),
                            blurRadius: 25,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: -5,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to text if image fails to load
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.withValues(alpha: 0.8),
                                    Colors.blue.shade900,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.local_taxi,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'TOURTAXI',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // App Name Below Logo
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'TOURTAXI',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: Colors.blue.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Tagline
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Your Ride, Your Way',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Loading indicator
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


