import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_handler_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  StreamController<NotificationData>? _notificationController;
  Stream<NotificationData>? get notificationStream => _notificationController?.stream;

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _notificationController = StreamController<NotificationData>.broadcast();

      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Initialize Firebase messaging (only on mobile)
      if (!kIsWeb) {
        await _initializeFirebaseMessaging();
      }

      _isInitialized = true;
      debugPrint('✅ Notification service initialized successfully');
    } catch (error) {
      debugPrint('❌ Failed to initialize notification service: $error');
      ErrorHandlerService().handleError(
        error,
        showSnackBar: false, // Don't show snackbar during initialization
      );
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Initialize Firebase messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Request permissions
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('User denied notification permissions');
      return;
    }

    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

    // Handle initial message (when app is launched from terminated state)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessageTap(initialMessage);
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'ride_updates',
        'Ride Updates',
        description: 'Notifications about your rides',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
      AndroidNotificationChannel(
        'driver_messages',
        'Driver Messages',
        description: 'Messages from your driver',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'promotions',
        'Promotions',
        description: 'Special offers and promotions',
        importance: Importance.defaultImportance,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Save FCM token to Supabase
  Future<void> _saveFCMToken(String token) async {
    await ErrorHandlerService.handleAsync<void>(
      () async {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client.from('user_tokens').upsert({
            'user_id': user.id,
            'fcm_token': token,
            'platform': Platform.isIOS ? 'ios' : 'android',
            'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint('✅ FCM token saved successfully');
        }
      },
      showError: false, // Handle silently
    );
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = NotificationData.fromRemoteMessage(message);
    
    // Show local notification
    _showLocalNotification(notification);
    
    // Add to stream for in-app handling
    _notificationController?.add(notification);
  }

  /// Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    final notification = NotificationData.fromRemoteMessage(message);
    _notificationController?.add(notification);
  }

  /// Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final notification = NotificationData.fromPayload(response.payload!);
      _notificationController?.add(notification);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(NotificationData notification) async {
    await ErrorHandlerService.handleAsync<void>(
      () async {
        const androidDetails = AndroidNotificationDetails(
          'ride_updates',
          'Ride Updates',
          channelDescription: 'Notifications about your rides',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        const details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _localNotifications.show(
          notification.id,
          notification.title,
          notification.body,
          details,
          payload: notification.toPayload(),
        );
      },
      showError: false, // Handle silently for notifications
    );
  }

  /// Show in-app notification
  Future<void> showInAppNotification(
    BuildContext context,
    NotificationData notification,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (notification.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(notification.body),
            ],
          ],
        ),
        backgroundColor: _getNotificationColor(notification.type),
        duration: const Duration(seconds: 4),
        action: notification.actionLabel != null
            ? SnackBarAction(
                label: notification.actionLabel!,
                onPressed: () {
                  // Handle action based on notification type
                  _handleNotificationAction(context, notification);
                },
              )
            : null,
      ),
    );
  }

  /// Handle notification actions
  void _handleNotificationAction(BuildContext context, NotificationData notification) {
    switch (notification.type) {
      case NotificationType.rideUpdate:
        // Navigate to ride details
        if (notification.data['ride_id'] != null) {
          Navigator.of(context).pushNamed('/ride-details', arguments: notification.data['ride_id']);
        }
        break;
      case NotificationType.driverMessage:
        // Navigate to chat or ride details
        Navigator.of(context).pushNamed('/ride-details');
        break;
      case NotificationType.promotion:
        // Navigate to promotions or specific offer
        Navigator.of(context).pushNamed('/dashboard');
        break;
      case NotificationType.general:
        // Default action
        break;
    }
  }

  /// Get notification color based on type
  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.rideUpdate:
        return Colors.blue;
      case NotificationType.driverMessage:
        return Colors.green;
      case NotificationType.promotion:
        return Colors.orange;
      case NotificationType.general:
        return Colors.grey.shade700;
    }
  }

  /// Send local notification manually
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    Map<String, dynamic>? data,
    String? actionLabel,
  }) async {
    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      type: type,
      data: data ?? {},
      actionLabel: actionLabel,
      timestamp: DateTime.now(),
    );

    await _showLocalNotification(notification);
    _notificationController?.add(notification);
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;

    final notificationPermission = await Permission.notification.request();
    
    if (Platform.isIOS) {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    }

    return notificationPermission == PermissionStatus.granted;
  }

  /// Subscribe to topic for targeted notifications
  Future<void> subscribeToTopic(String topic) async {
    if (!kIsWeb) {
      await _firebaseMessaging.subscribeToTopic(topic);
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!kIsWeb) {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationController?.close();
    _notificationController = null;
  }
}

enum NotificationType {
  rideUpdate,
  driverMessage,
  promotion,
  general,
}

class NotificationData {
  final int id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final String? actionLabel;
  final DateTime timestamp;

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    this.actionLabel,
    required this.timestamp,
  });

  factory NotificationData.fromRemoteMessage(RemoteMessage message) {
    return NotificationData(
      id: DateTime.now().millisecondsSinceEpoch,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      type: _parseNotificationType(message.data['type']),
      data: message.data,
      actionLabel: message.data['action_label'],
      timestamp: DateTime.now(),
    );
  }

  factory NotificationData.fromPayload(String payload) {
    // Simple payload parsing - in production, use JSON
    final parts = payload.split('|');
    return NotificationData(
      id: int.tryParse(parts[0]) ?? 0,
      title: parts.length > 1 ? parts[1] : '',
      body: parts.length > 2 ? parts[2] : '',
      type: NotificationType.values[int.tryParse(parts[3]) ?? 0],
      data: {},
      timestamp: DateTime.now(),
    );
  }

  String toPayload() {
    return '$id|$title|$body|${type.index}';
  }

  static NotificationType _parseNotificationType(String? type) {
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
}