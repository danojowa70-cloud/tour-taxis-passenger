import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class ScheduledRideNotificationsService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;
  static RealtimeChannel? _realtimeChannel;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

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
    debugPrint('✅ Scheduled ride notifications initialized');
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
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Listen for ride confirmations in real-time
  static void listenForRideUpdates(String userId) {
    _realtimeChannel?.unsubscribe();
    
    _realtimeChannel = Supabase.instance.client
        .channel('passenger_ride_updates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'scheduled_rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'passenger_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            
            // Driver accepted the ride
            if (oldRecord['status'] == 'scheduled' && 
                newRecord['status'] == 'confirmed' &&
                newRecord['driver_id'] != null) {
              _showDriverAcceptedNotification(newRecord);
            }
            
            // Driver cancelled the ride
            if (newRecord['status'] == 'scheduled' && 
                oldRecord['driver_id'] != null &&
                newRecord['driver_id'] == null) {
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
      'scheduled_rides',
      'Scheduled Rides',
      channelDescription: 'Notifications for scheduled ride updates',
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
      '✅ Driver Accepted Your Ride!',
      'Your scheduled ride to ${ride['destination_location']} has been confirmed.',
      details,
      payload: 'ride_confirmed:${ride['id']}',
    );

    debugPrint('✅ Showed driver accepted notification');
  }

  /// Show notification when driver cancels
  static Future<void> _showDriverCancelledNotification(Map<String, dynamic> ride) async {
    const androidDetails = AndroidNotificationDetails(
      'scheduled_rides',
      'Scheduled Rides',
      channelDescription: 'Notifications for scheduled ride updates',
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
      '❌ Driver Cancelled',
      'Your scheduled ride has been cancelled. Please book another driver.',
      details,
      payload: 'ride_cancelled:${ride['id']}',
    );
  }

  /// Schedule reminder notification before ride time
  static Future<void> scheduleRideReminder({
    required String rideId,
    required DateTime scheduledTime,
    required String pickupLocation,
    required String dropoffLocation,
    int minutesBefore = 30,
  }) async {
    final reminderTime = scheduledTime.subtract(Duration(minutes: minutesBefore));
    
    // Don't schedule if the reminder time is in the past
    if (reminderTime.isBefore(DateTime.now())) {
      debugPrint('⏰ Reminder time is in the past, skipping');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'ride_reminders',
      'Ride Reminders',
      channelDescription: 'Reminders for upcoming scheduled rides',
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

    await _notifications.zonedSchedule(
      rideId.hashCode,
      '🚗 Upcoming Ride in $minutesBefore minutes',
      'Your ride from $pickupLocation to $dropoffLocation is coming up soon!',
      tz.TZDateTime.from(reminderTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'ride_reminder:$rideId',
    );

    debugPrint('⏰ Scheduled reminder for $reminderTime');
  }

  /// Cancel a scheduled reminder
  static Future<void> cancelRideReminder(String rideId) async {
    await _notifications.cancel(rideId.hashCode);
    debugPrint('🔕 Cancelled reminder for ride: $rideId');
  }

  /// Show immediate notification (for testing)
  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test',
      'Test Notifications',
      channelDescription: 'Test notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,
      'Test Notification',
      'This is a test notification',
      details,
    );
  }
}
