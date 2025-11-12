import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstantRideNotificationsService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;
  static RealtimeChannel? _realtimeChannel;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    _initialized = true;
    debugPrint('✅ Instant ride notifications initialized');
  }

  static Future<void> _requestPermissions() async {
    // Android 13+ permission
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS permission
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');
    // TODO: Navigate to ride details screen
  }

  /// Listen for ride status updates in real-time
  static void listenForRideUpdates(String userId) {
    _realtimeChannel?.unsubscribe();
    
    _realtimeChannel = Supabase.instance.client
        .channel('instant_ride_updates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'passenger_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            
            debugPrint('🔔 Ride update: ${newRecord['status']}');
            
            // Driver accepted the ride
            if (oldRecord['status'] == 'searching' && 
                newRecord['status'] == 'accepted') {
              _showDriverAcceptedNotification(newRecord);
            }
            
            // Driver is on the way
            if (oldRecord['status'] == 'accepted' && 
                newRecord['status'] == 'on_the_way') {
              _showDriverOnTheWayNotification(newRecord);
            }
            
            // Driver arrived
            if (newRecord['status'] == 'arrived') {
              _showDriverArrivedNotification(newRecord);
            }
            
            // Ride started
            if (newRecord['status'] == 'in_progress') {
              _showRideStartedNotification(newRecord);
            }
            
            // Ride completed
            if (newRecord['status'] == 'completed') {
              _showRideCompletedNotification(newRecord);
            }
            
            // Ride cancelled by driver
            if (newRecord['status'] == 'cancelled' && 
                newRecord['cancelled_by'] == 'driver') {
              _showDriverCancelledNotification(newRecord);
            }
          },
        )
        .subscribe();
    
    debugPrint('🔔 Listening for ride updates for passenger: $userId');
  }

  /// Stop listening to updates
  static void stopListening() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  /// Show notification when driver accepts ride
  static Future<void> _showDriverAcceptedNotification(Map<String, dynamic> ride) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_rides',
      'Instant Rides',
      channelDescription: 'Notifications for instant ride updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification'),
      playSound: true,
      enableVibration: true,
      ticker: 'Driver Accepted Your Ride',
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

    final driverName = ride['driver_name'] ?? 'Your driver';
    final vehiclePlate = ride['vehicle_plate'] ?? '';
    
    await _notifications.show(
      ride['id'].hashCode,
      '✅ Driver Accepted Your Ride!',
      '$driverName is preparing to pick you up${vehiclePlate.isNotEmpty ? ' - $vehiclePlate' : ''}',
      details,
      payload: 'ride_accepted:${ride['id']}',
    );

    debugPrint('✅ Showed driver accepted notification');
  }

  /// Show notification when driver is on the way
  static Future<void> _showDriverOnTheWayNotification(Map<String, dynamic> ride) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_rides',
      'Instant Rides',
      channelDescription: 'Notifications for instant ride updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification'),
      playSound: true,
      enableVibration: true,
      ticker: 'Driver is On The Way',
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

    final driverName = ride['driver_name'] ?? 'Your driver';
    final eta = ride['estimated_arrival_time'] ?? '5 mins';
    
    await _notifications.show(
      ride['id'].hashCode,
      '🚗 $driverName is On The Way!',
      'Your driver will arrive in approximately $eta',
      details,
      payload: 'driver_on_way:${ride['id']}',
    );

    debugPrint('✅ Showed driver on the way notification');
  }

  /// Show notification when driver arrived
  static Future<void> _showDriverArrivedNotification(Map<String, dynamic> ride) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_rides',
      'Instant Rides',
      channelDescription: 'Notifications for instant ride updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      ticker: 'Driver Has Arrived',
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

    final driverName = ride['driver_name'] ?? 'Your driver';
    
    await _notifications.show(
      ride['id'].hashCode,
      '📍 $driverName Has Arrived!',
      'Your driver is waiting at the pickup location',
      details,
      payload: 'driver_arrived:${ride['id']}',
    );

    debugPrint('✅ Showed driver arrived notification');
  }

  /// Show notification when ride starts
  static Future<void> _showRideStartedNotification(Map<String, dynamic> ride) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_rides',
      'Instant Rides',
      channelDescription: 'Notifications for instant ride updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

    await _notifications.show(
      ride['id'].hashCode,
      '🚀 Ride Started!',
      'Enjoy your ride to ${ride['dropoff_location'] ?? 'your destination'}',
      details,
      payload: 'ride_started:${ride['id']}',
    );

    debugPrint('✅ Showed ride started notification');
  }

  /// Show notification when ride completes
  static Future<void> _showRideCompletedNotification(Map<String, dynamic> ride) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_rides',
      'Instant Rides',
      channelDescription: 'Notifications for instant ride updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

    final fare = ride['fare'] ?? 0;
    
    await _notifications.show(
      ride['id'].hashCode,
      '✅ Ride Completed!',
      'Total fare: KSh $fare - Please rate your driver',
      details,
      payload: 'ride_completed:${ride['id']}',
    );

    debugPrint('✅ Showed ride completed notification');
  }

  /// Show notification when driver cancels
  static Future<void> _showDriverCancelledNotification(Map<String, dynamic> ride) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_rides',
      'Instant Rides',
      channelDescription: 'Notifications for instant ride updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

    final reason = ride['cancellation_reason'] ?? 'No reason provided';
    
    await _notifications.show(
      ride['id'].hashCode,
      '❌ Driver Cancelled Ride',
      'Reason: $reason - Finding you another driver...',
      details,
      payload: 'driver_cancelled:${ride['id']}',
    );

    debugPrint('✅ Showed driver cancelled notification');
  }

  /// Show immediate notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_rides',
      'Instant Rides',
      channelDescription: 'Notifications for instant ride updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
