import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_handler_service.dart';
import 'notification_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  debugPrint('📱 Background message received: ${message.messageId}');
  
  // You can process the message here if needed
  // For example, update local storage, sync data, etc.
  
  // Don't show notifications here - they're automatically shown by the system
}

/// FCM Configuration Service
class FCMConfigService {
  static final FCMConfigService _instance = FCMConfigService._internal();
  factory FCMConfigService() => _instance;
  FCMConfigService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _isConfigured = false;

  /// Configure FCM with all necessary settings
  Future<bool> configure() async {
    if (_isConfigured) return true;
    if (kIsWeb) return true; // Skip for web

    // Check if Firebase is available
    try {
      Firebase.app();
    } catch (e) {
      debugPrint('⚠️ Firebase not initialized, skipping FCM configuration');
      return false;
    }

    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request permissions
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        debugPrint('🚫 FCM permissions denied');
        return false;
      }

      // Configure message handlers
      await _configureMessageHandlers();

      // Get and save initial token
      await _handleTokenRefresh();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

      // Subscribe to topics
      await _subscribeToTopics();

      _isConfigured = true;
      debugPrint('✅ FCM configured successfully');
      return true;
    } catch (error) {
      debugPrint('❌ FCM configuration failed: $error');
      ErrorHandlerService().handleError(error, showSnackBar: false);
      return false;
    }
  }

  /// Request FCM permissions
  Future<bool> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('🔔 FCM authorization status: ${settings.authorizationStatus}');
    return authorized;
  }

  /// Configure message handlers for different app states
  Future<void> _configureMessageHandlers() async {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 Foreground message: ${message.notification?.title}');
      _handleForegroundMessage(message);
    });

    // Handle messages when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 App opened from notification: ${message.notification?.title}');
      _handleMessageTap(message);
    });

    // Handle messages when app was terminated and opened from notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 App launched from notification: ${initialMessage.notification?.title}');
      _handleMessageTap(initialMessage);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    // Add to notification stream for in-app handling
    final notificationService = NotificationService();
    if (notificationService.notificationStream != null) {
      // Cannot access private member, handled in NotificationService directly
    }

    // Show local notification
    _showForegroundNotification(message);
  }

  /// Show notification when app is in foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notificationService = NotificationService();
    
    final notificationData = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch,
      title: message.notification?.title ?? 'TourTaxi',
      body: message.notification?.body ?? 'New notification',
      type: _getNotificationTypeFromData(message.data),
      data: message.data,
      timestamp: DateTime.now(),
    );

    await notificationService.sendLocalNotification(
      title: notificationData.title,
      body: notificationData.body,
      type: notificationData.type,
      data: notificationData.data,
    );
  }

  /// Handle notification tap
  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    final type = _getNotificationTypeFromData(data);
    
    // Navigate based on notification type
    _handleNavigationFromNotification(type, data);
  }

  /// Handle navigation based on notification
  void _handleNavigationFromNotification(NotificationType type, Map<String, dynamic> data) {
    // Note: Navigation should be handled in the main app after initialization
    // This method can be called from a callback or stream
    
    switch (type) {
      case NotificationType.rideUpdate:
        final rideId = data['ride_id'];
        if (rideId != null) {
          // Navigate to ride details
          debugPrint('🚗 Navigate to ride: $rideId');
        }
        break;
      case NotificationType.driverMessage:
        // Navigate to driver chat
        debugPrint('💬 Navigate to driver chat');
        break;
      case NotificationType.promotion:
        // Navigate to promotions
        debugPrint('🎉 Navigate to promotions');
        break;
      case NotificationType.general:
        // Navigate to dashboard
        debugPrint('🏠 Navigate to dashboard');
        break;
    }
  }

  /// Get notification type from message data
  NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    switch (type) {
      case 'ride_update':
        return NotificationType.rideUpdate;
      case 'driver_message':
        return NotificationType.driverMessage;
      case 'promotion':
        return NotificationType.promotion;
      default:
        return NotificationType.general;
    }
  }

  /// Handle token refresh and save to database
  Future<void> _handleTokenRefresh() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }
    } catch (error) {
      debugPrint('❌ Failed to get FCM token: $error');
    }
  }

  /// Save FCM token to Supabase
  Future<void> _saveTokenToDatabase(String token) async {
    await ErrorHandlerService.handleAsync<void>(
      () async {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        await Supabase.instance.client.from('user_fcm_tokens').upsert({
          'user_id': user.id,
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'app_version': '1.0.0', // Get from package info
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,platform');

        debugPrint('✅ FCM token saved to database');
      },
      showError: false,
    );
  }

  /// Subscribe to relevant topics
  Future<void> _subscribeToTopics() async {
    final topics = [
      'all_users', // General announcements
      'promotions', // Special offers
      'app_updates', // App update notifications
    ];

    for (final topic in topics) {
      try {
        await _messaging.subscribeToTopic(topic);
        debugPrint('✅ Subscribed to topic: $topic');
      } catch (error) {
        debugPrint('❌ Failed to subscribe to topic $topic: $error');
      }
    }

    // Subscribe to user-specific topic if logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await _messaging.subscribeToTopic('user_${user.id}');
        debugPrint('✅ Subscribed to user topic: user_${user.id}');
      } catch (error) {
        debugPrint('❌ Failed to subscribe to user topic: $error');
      }
    }
  }

  /// Unsubscribe from user-specific topics (on logout)
  Future<void> unsubscribeUserTopics(String userId) async {
    try {
      await _messaging.unsubscribeFromTopic('user_$userId');
      debugPrint('✅ Unsubscribed from user topic: user_$userId');
    } catch (error) {
      debugPrint('❌ Failed to unsubscribe from user topic: $error');
    }
  }

  /// Subscribe to ride-specific topic
  Future<void> subscribeToRideUpdates(String rideId) async {
    try {
      await _messaging.subscribeToTopic('ride_$rideId');
      debugPrint('✅ Subscribed to ride topic: ride_$rideId');
    } catch (error) {
      debugPrint('❌ Failed to subscribe to ride topic: $error');
    }
  }

  /// Unsubscribe from ride-specific topic
  Future<void> unsubscribeFromRideUpdates(String rideId) async {
    try {
      await _messaging.unsubscribeFromTopic('ride_$rideId');
      debugPrint('✅ Unsubscribed from ride topic: ride_$rideId');
    } catch (error) {
      debugPrint('❌ Failed to unsubscribe from ride topic: $error');
    }
  }

  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('❌ Failed to get current FCM token: $error');
      return null;
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('✅ FCM token deleted');
    } catch (error) {
      debugPrint('❌ Failed to delete FCM token: $error');
    }
  }

  /// Check if FCM is supported
  bool isSupported() {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  /// Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _messaging.getNotificationSettings();
  }
}

/// FCM Navigation Handler - to be used in main app
class FCMNavigationHandler {
  static final FCMNavigationHandler _instance = FCMNavigationHandler._internal();
  factory FCMNavigationHandler() => _instance;
  FCMNavigationHandler._internal();

  /// Handle navigation from FCM notification
  static void handleNotificationNavigation(
    Map<String, dynamic> data,
    Function(String route, {Object? arguments}) navigate,
  ) {
    final type = data['type']?.toString().toLowerCase();
    
    switch (type) {
      case 'ride_update':
        final rideId = data['ride_id'];
        if (rideId != null) {
          navigate('/ride-details', arguments: rideId);
        } else {
          navigate('/dashboard');
        }
        break;
      case 'driver_message':
        final rideId = data['ride_id'];
        if (rideId != null) {
          navigate('/ride-details', arguments: rideId);
        }
        break;
      case 'promotion':
        navigate('/dashboard'); // Or specific promotion page
        break;
      default:
        navigate('/dashboard');
    }
  }
}