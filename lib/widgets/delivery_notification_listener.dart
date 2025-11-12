import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/delivery_notification_provider.dart';

class DeliveryNotificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const DeliveryNotificationListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<DeliveryNotificationListener> createState() =>
      _DeliveryNotificationListenerState();
}

class _DeliveryNotificationListenerState
    extends ConsumerState<DeliveryNotificationListener> {
  @override
  Widget build(BuildContext context) {
    // Listen to delivery notifications
    ref.listen<DeliveryNotification?>(
      deliveryNotificationProvider,
      (previous, next) {
        if (next != null) {
          _showNotificationSnackBar(context, next);
          // Clear notification after showing
          Future.delayed(const Duration(milliseconds: 100), () {
            ref.read(deliveryNotificationProvider.notifier).clearNotification();
          });
        }
      },
    );

    return widget.child;
  }

  void _showNotificationSnackBar(
      BuildContext context, DeliveryNotification notification) {
    final backgroundColor = _getBackgroundColor(notification.status);
    final icon = _getIcon(notification.status);

    // Find the scaffold messenger and navigator context
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) {
      debugPrint('⚠️ No ScaffoldMessenger found, cannot show notification');
      return;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: InkWell(
          onTap: () {
            scaffoldMessenger.hideCurrentSnackBar();
            if (Navigator.canPop(context)) {
              Navigator.pushNamed(context, '/delivery-tracking');
            }
          },
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to view →',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white,
          onPressed: () {
            scaffoldMessenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Color _getBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'confirmed':
      case 'delivered':
        return Colors.green.shade600;
      case 'rejected':
      case 'cancelled':
        return Colors.red.shade600;
      case 'picked_up':
      case 'in_transit':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'confirmed':
        return Icons.check_circle;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel;
      case 'picked_up':
        return Icons.inventory_2;
      case 'in_transit':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      default:
        return Icons.notifications;
    }
  }
}
