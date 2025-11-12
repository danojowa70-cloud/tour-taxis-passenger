import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'themes/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/profile_screen.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'screens/search_destination_screen.dart';
import 'screens/confirm_ride_screen.dart';
import 'screens/ride_searching_screen.dart';
import 'screens/ride_details_screen.dart';
import 'screens/payment_method_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/receipts_screen.dart';
import 'screens/schedule_ride_screen.dart';
import 'screens/boarding_pass_screen.dart';
import 'screens/boarding_passes_screen.dart';
import 'screens/premium_booking_screen.dart';
import 'screens/delivery_booking_screen.dart';
import 'screens/delivery_tracking_screen.dart';
import 'screens/scheduled_ride_details_screen.dart';
import 'screens/scheduled_rides_history_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/fcm_config_service.dart';
import 'services/error_handler_service.dart';
import 'services/scheduled_ride_notifications_service.dart';
import 'services/instant_ride_notifications_service.dart';
import 'widgets/delivery_notification_listener.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('🚀 App starting...');
    
    final themeController = await ThemeController.load();
    debugPrint('✅ Theme controller loaded');
    
    // Initialize Firebase (required for notifications)
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialized');
      } catch (e) {
        debugPrint('⚠️ Firebase initialization failed: $e');
        // Continue without Firebase - notifications will be disabled
      }
    }
    
    // Placeholder Supabase initialization; replace with your actual URL and anon key.
    await Supabase.initialize(
      url: 'https://vojjpvxhpofudvpexrjb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvampwdnhocG9mdWR2cGV4cmpiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0MjQ3NzIsImV4cCI6MjA3NTAwMDc3Mn0.AYgP9ww5Lg_VqfqcN_zN3kf4j-otQbAgbYKlQIbE3yc',
      debug: false,
    );
    debugPrint('✅ Supabase initialized');
    
    // Initialize services with error handling (only if Firebase is available)
    try {
      if (!kIsWeb) {
        try {
          await NotificationService().initialize();
          debugPrint('✅ Notification service initialized');
          
          await FCMConfigService().configure();
          debugPrint('✅ FCM service configured');
          
          // Initialize scheduled ride notifications
          await ScheduledRideNotificationsService.initialize();
          debugPrint('✅ Scheduled ride notifications initialized');
          
          // Initialize instant ride notifications
          await InstantRideNotificationsService.initialize();
          debugPrint('✅ Instant ride notifications initialized');
          
          // Start listening for ride updates (if user is logged in)
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            ScheduledRideNotificationsService.listenForRideUpdates(userId);
            InstantRideNotificationsService.listenForRideUpdates(userId);
          }
        } catch (e) {
          debugPrint('⚠️ Service initialization failed: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error during service initialization: $e');
    }
    
    debugPrint('🎉 Starting app with providers...');
    
    runApp(ProviderScope(overrides: [
      themeDarkProvider.overrideWith((ref) => themeController),
    ], child: const MyApp()));
  } catch (e, stackTrace) {
    debugPrint('💥 Fatal error during app initialization: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Run a minimal app that shows the error
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('📱 MyApp build method called');
    
    try {
      final isDark = ref.watch(themeDarkProvider);
      debugPrint('🎨 Theme loaded: ${isDark ? 'dark' : 'light'}');
      
      // Initialize FCM and notifications safely
      try {
        _initFcm();
        _setupNotificationNavigation();
      } catch (e) {
        debugPrint('⚠️ Error setting up notifications: $e');
      }
      
      debugPrint('🛌️ Building MaterialApp...');
      
      return DeliveryNotificationListener(
        child: MaterialApp(
        title: 'TOURTAXI Passenger App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        onGenerateRoute: (settings) {
          debugPrint('🗺 Navigating to: ${settings.name}');
          Widget page;
          try {
            switch (settings.name) {
              case '/':
                page = const SplashScreen();
                break;
              case '/auth':
                page = const LoginScreen();
                break;
              case '/signup':
                page = const SignupScreen();
                break;
              case '/home':
                page = const HomeScreen();
                break;
              case '/search-destination':
                page = const SearchDestinationScreen();
                break;
              case '/confirm':
                page = const ConfirmRideScreen();
                break;
              case '/searching':
                page = const RideSearchingScreen();
                break;
              case '/ride-details':
                page = const RideDetailsScreen();
                break;
              case '/dashboard':
                page = const DashboardScreen();
                break;
              case '/payments':
                final paymentArgs = settings.arguments as Map<String, dynamic>?;
                page = PaymentScreen(
                  rideId: paymentArgs?['rideId'] as String?,
                  fare: paymentArgs?['fare'] as double?,
                  rideType: paymentArgs?['rideType'] as String?,
                );
                break;
              case '/profile':
                page = const ProfileScreen();
                break;
              case '/payment-methods':
                final amount = settings.arguments as double? ?? 0.0;
                page = PaymentMethodScreen(amount: amount);
                break;
              case '/wallet':
                page = const WalletScreen();
                break;
              case '/receipts':
                page = const ReceiptsScreen();
                break;
              case '/schedule':
                page = const ScheduleRideScreen();
                break;
              case '/boarding-pass':
                final boardingPassId = settings.arguments as String?;
                if (boardingPassId != null) {
                  page = BoardingPassScreen(boardingPassId: boardingPassId);
                } else {
                  page = const ErrorScreen(error: 'Boarding pass ID is required');
                }
                break;
              case '/boarding-passes':
                page = const BoardingPassesScreen();
                break;
              case '/premium-booking':
                page = const PremiumBookingScreen();
                break;
              case '/delivery-booking':
                page = const DeliveryBookingScreen();
                break;
              case '/delivery-tracking':
                page = const DeliveryTrackingScreen();
                break;
              case '/scheduled-ride-details':
                final args = settings.arguments as Map<String, dynamic>?;
                final rideId = args?['rideId'] as String?;
                if (rideId != null) {
                  page = ScheduledRideDetailsScreen(rideId: rideId);
                } else {
                  page = const ErrorScreen(error: 'Ride ID is required');
                }
                break;
              case '/scheduled-rides-history':
                final passengerId = settings.arguments as String?;
                if (passengerId != null) {
                  page = ScheduledRidesHistoryScreen(passengerId: passengerId);
                } else {
                  page = const ErrorScreen(error: 'Passenger ID is required');
                }
                break;
              default:
                page = const SplashScreen();
            }
            debugPrint('✅ Page created: ${page.runtimeType}');
          } catch (e) {
            debugPrint('💥 Error creating page for ${settings.name}: $e');
            page = ErrorScreen(error: 'Failed to load ${settings.name}: $e');
          }
          
          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => page,
            transitionsBuilder: (_, animation, __, child) {
              final curve = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
              return FadeTransition(opacity: curve, child: child);
            },
            transitionDuration: const Duration(milliseconds: 250),
          );
        },
        initialRoute: '/',
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('💥 Error in MyApp build: $e');
      debugPrint('Stack trace: $stackTrace');
      
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ErrorScreen(error: 'App build failed: $e'),
      );
    }
  }
}

Future<void> _initFcm() async {
  // FCM is now initialized in fcm_config_service.dart
  // This method is kept for backward compatibility
}

/// Setup navigation handling for notifications
void _setupNotificationNavigation() {
  try {
    if (!kIsWeb) {
      // Listen to notification stream for in-app navigation
      final notificationService = NotificationService();
      notificationService.notificationStream?.listen((notification) {
        // Handle notification tap navigation
        ErrorHandlerService.handleSilently(() {
          // Navigation logic would go here
          // For example: navigatorKey.currentState?.pushNamed(route);
        });
      });
    }
  } catch (e) {
    debugPrint('⚠️ Error setting up notification navigation: $e');
  }
}

/// Error app to show when main app fails to initialize
class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TourTaxi - Error',
      debugShowCheckedModeBanner: false,
      home: ErrorScreen(error: error),
    );
  }
}

/// Error screen to show detailed error information
class ErrorScreen extends StatelessWidget {
  final String error;
  
  const ErrorScreen({super.key, required this.error});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text('App Error'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Details:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                error,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Restart the app
                  debugPrint('🔄 Attempting to restart app...');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
