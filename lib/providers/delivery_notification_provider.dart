import 'package:flutter_riverpod/flutter_riverpod.dart';

// Model for delivery notification
class DeliveryNotification {
  final String trackingNumber;
  final String deliveryId;
  final String status;
  final String title;
  final String message;
  final DateTime timestamp;

  DeliveryNotification({
    required this.trackingNumber,
    required this.deliveryId,
    required this.status,
    required this.title,
    required this.message,
    required this.timestamp,
  });
}

// Notifier for managing delivery notifications
class DeliveryNotificationNotifier extends StateNotifier<DeliveryNotification?> {
  DeliveryNotificationNotifier() : super(null);

  // Show a notification
  void showNotification(DeliveryNotification notification) {
    state = notification;
  }

  // Clear current notification
  void clearNotification() {
    state = null;
  }
}

// Provider instance
final deliveryNotificationProvider = StateNotifierProvider<DeliveryNotificationNotifier, DeliveryNotification?>(
  (ref) => DeliveryNotificationNotifier(),
);
