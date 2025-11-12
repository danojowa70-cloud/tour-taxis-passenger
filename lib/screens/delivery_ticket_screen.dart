import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/delivery.dart';
import '../providers/delivery_providers.dart';

class DeliveryTicketScreen extends ConsumerStatefulWidget {
  final String trackingNumber;

  const DeliveryTicketScreen({
    required this.trackingNumber,
    super.key,
  });

  @override
  ConsumerState<DeliveryTicketScreen> createState() => _DeliveryTicketScreenState();
}

class _DeliveryTicketScreenState extends ConsumerState<DeliveryTicketScreen> {
  @override
  Widget build(BuildContext context) {
    final delivery = ref.watch(deliveryByIdProvider(widget.trackingNumber));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Delivery Ticket'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: GestureDetector(
                onTap: () => _shareTicket(context, delivery),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.share,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: delivery == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ticket Header
                    _buildTicketHeader(context, delivery, theme),
                    const SizedBox(height: 24),

                    // Status Timeline
                    _buildStatusTimeline(context, delivery, theme),
                    const SizedBox(height: 24),

                    // Sender Information
                    _buildContactSection(
                      context: context,
                      theme: theme,
                      title: 'Sender Information',
                      icon: Icons.person_outline,
                      contact: delivery.sender,
                    ),
                    const SizedBox(height: 16),

                    // Recipient Information
                    _buildContactSection(
                      context: context,
                      theme: theme,
                      title: 'Recipient Information',
                      icon: Icons.location_on_outlined,
                      contact: delivery.recipient,
                    ),
                    const SizedBox(height: 16),

                    // Package Details
                    _buildPackageSection(context, delivery, theme),
                    const SizedBox(height: 16),

                    // Delivery Information
                    _buildDeliveryInfoSection(context, delivery, theme),
                    const SizedBox(height: 16),

                    // Cost Breakdown
                    _buildCostSection(context, delivery, theme),
                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(context, delivery, theme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTicketHeader(BuildContext context, DeliveryBooking delivery, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.1),
            Colors.cyan.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracking Number',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delivery.trackingNumber,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(delivery.status, theme),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildIconBadge(
                icon: delivery.vehicleType == DeliveryVehicleType.cargoPlane
                    ? Icons.airplanemode_active
                    : Icons.directions_boat,
                label: delivery.vehicleTypeDisplayName,
                theme: theme,
              ),
              const SizedBox(width: 16),
              _buildIconBadge(
                icon: Icons.local_shipping,
                label: delivery.priorityDisplayName,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(DeliveryStatus status, ThemeData theme) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case DeliveryStatus.pending:
        backgroundColor = Colors.yellow.withValues(alpha: 0.2);
        textColor = Colors.yellow[700]!;
        icon = Icons.schedule;
        break;
      case DeliveryStatus.confirmed:
        backgroundColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue[700]!;
        icon = Icons.check_circle;
        break;
      case DeliveryStatus.pickedUp:
        backgroundColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange[700]!;
        icon = Icons.shopping_bag;
        break;
      case DeliveryStatus.inTransit:
        backgroundColor = Colors.purple.withValues(alpha: 0.2);
        textColor = Colors.purple[700]!;
        icon = Icons.directions;
        break;
      case DeliveryStatus.outForDelivery:
        backgroundColor = Colors.indigo.withValues(alpha: 0.2);
        textColor = Colors.indigo[700]!;
        icon = Icons.local_shipping;
        break;
      case DeliveryStatus.delivered:
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green[700]!;
        icon = Icons.task_alt;
        break;
      case DeliveryStatus.cancelled:
      case DeliveryStatus.failed:
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red[700]!;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBadge({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(BuildContext context, DeliveryBooking delivery, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Timeline',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...delivery.updates.asMap().entries.map((entry) {
          int index = entry.key;
          DeliveryUpdate update = entry.value;
          bool isLast = index == delivery.updates.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(update.status),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.status.name.toUpperCase(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        update.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      if (update.location != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              update.location!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(update.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  IconData _getStatusIcon(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Icons.schedule;
      case DeliveryStatus.confirmed:
        return Icons.check_circle;
      case DeliveryStatus.pickedUp:
        return Icons.shopping_bag;
      case DeliveryStatus.inTransit:
        return Icons.directions;
      case DeliveryStatus.outForDelivery:
        return Icons.local_shipping;
      case DeliveryStatus.delivered:
        return Icons.task_alt;
      case DeliveryStatus.cancelled:
      case DeliveryStatus.failed:
        return Icons.cancel;
    }
  }

  Widget _buildContactSection({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required IconData icon,
    required ContactDetails contact,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContactDetail('Name', contact.name, theme),
          _buildContactDetail('Email', contact.email, theme),
          _buildContactDetail('Phone', contact.phone, theme),
          if (contact.company != null)
            _buildContactDetail('Company', contact.company!, theme),
          _buildContactDetail('Address', contact.fullAddress, theme),
        ],
      ),
    );
  }

  Widget _buildContactDetail(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSection(BuildContext context, DeliveryBooking delivery, ThemeData theme) {
    final packageDetails = delivery.package;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Package Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContactDetail('Description', packageDetails.description, theme),
          _buildContactDetail('Type', packageDetails.type.displayName, theme),
          _buildContactDetail('Weight', '${packageDetails.weight} kg', theme),
          _buildContactDetail(
            'Dimensions',
            '${packageDetails.length}cm × ${packageDetails.width}cm × ${packageDetails.height}cm',
            theme,
          ),
          _buildContactDetail(
            'Volume',
            '${packageDetails.volume.toStringAsFixed(3)} m³',
            theme,
          ),
          if (packageDetails.declaredValue != null)
            _buildContactDetail('Declared Value', 'KSh ${packageDetails.declaredValue}', theme),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Fragile:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Text(
                packageDetails.isFragile ? '✓ Yes' : '✗ No',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 110,
                child: Text(
                  'Refrigeration:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Text(
                packageDetails.requiresRefrigeration ? '✓ Yes' : '✗ No',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (packageDetails.specialInstructions != null) ...[
            const SizedBox(height: 8),
            _buildContactDetail('Special Instructions', packageDetails.specialInstructions!, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoSection(BuildContext context, DeliveryBooking delivery, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Delivery Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContactDetail('Vehicle Type', delivery.vehicleTypeDisplayName, theme),
          _buildContactDetail('Priority', delivery.priorityDisplayName, theme),
          if (delivery.estimatedPickupTime != null)
            _buildContactDetail(
              'Estimated Pickup',
              DateFormat('MMM dd, yyyy • hh:mm a').format(delivery.estimatedPickupTime!),
              theme,
            ),
          if (delivery.estimatedDeliveryTime != null)
            _buildContactDetail(
              'Estimated Delivery',
              DateFormat('MMM dd, yyyy • hh:mm a').format(delivery.estimatedDeliveryTime!),
              theme,
            ),
          if (delivery.actualPickupTime != null)
            _buildContactDetail(
              'Actual Pickup',
              DateFormat('MMM dd, yyyy • hh:mm a').format(delivery.actualPickupTime!),
              theme,
            ),
          if (delivery.actualDeliveryTime != null)
            _buildContactDetail(
              'Actual Delivery',
              DateFormat('MMM dd, yyyy • hh:mm a').format(delivery.actualDeliveryTime!),
              theme,
            ),
        ],
      ),
    );
  }

  Widget _buildCostSection(BuildContext context, DeliveryBooking delivery, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.1),
            Colors.green.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 20, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'Delivery Cost',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'KSh ${delivery.totalCost.toStringAsFixed(0)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${delivery.priorityDisplayName} • ${delivery.vehicleTypeDisplayName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, DeliveryBooking delivery, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _shareTicket(context, delivery),
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _downloadTicket(context, delivery),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _shareTicket(BuildContext context, DeliveryBooking? delivery) {
    if (delivery == null) return;
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _downloadTicket(BuildContext context, DeliveryBooking? delivery) {
    if (delivery == null) return;
    // TODO: Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download functionality coming soon')),
    );
  }
}
