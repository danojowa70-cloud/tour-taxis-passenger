import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/delivery.dart';
import '../providers/delivery_providers.dart';
import 'delivery_ticket_screen.dart';

class DeliveryHistoryScreen extends ConsumerStatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  ConsumerState<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends ConsumerState<DeliveryHistoryScreen> {
  String selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final deliveriesAsync = ref.watch(deliveryListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: deliveriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              const Text('Failed to load deliveries'),
            ],
          ),
        ),
        data: (deliveries) {
          final filtered = _filterDeliveries(deliveries, selectedFilter);

          return Column(
            children: [
              // Filter Tabs
              _buildFilterTabs(context, theme),
              
              // Delivery List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 64,
                              color: theme.colorScheme.outline.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No deliveries found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final delivery = filtered[index];
                          return _buildDeliveryCard(context, delivery, theme);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildFilterTab('All', 'all', theme),
            const SizedBox(width: 8),
            _buildFilterTab('Active', 'active', theme),
            const SizedBox(width: 8),
            _buildFilterTab('Completed', 'completed', theme),
            const SizedBox(width: 8),
            _buildFilterTab('Cancelled', 'cancelled', theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String value, ThemeData theme) {
    final isSelected = selectedFilter == value;

    return GestureDetector(
      onTap: () => setState(() => selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<DeliveryBooking> _filterDeliveries(List<DeliveryBooking> deliveries, String filter) {
    switch (filter) {
      case 'active':
        return deliveries.where((d) => d.isActive).toList();
      case 'completed':
        return deliveries.where((d) => d.status == DeliveryStatus.delivered).toList();
      case 'cancelled':
        return deliveries.where((d) => 
          d.status == DeliveryStatus.cancelled || d.status == DeliveryStatus.failed
        ).toList();
      default:
        return deliveries;
    }
  }

  Widget _buildDeliveryCard(BuildContext context, DeliveryBooking delivery, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryTicketScreen(
              trackingNumber: delivery.trackingNumber,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            // Header: Tracking and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      delivery.trackingNumber,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(delivery.status, theme),
              ],
            ),
            const SizedBox(height: 16),

            // Route Information
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        delivery.sender.city,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'To',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        delivery.recipient.city,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Package Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Package',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          delivery.package.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Type',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        delivery.vehicleType == DeliveryVehicleType.cargoPlane
                            ? '✈️ Air'
                            : '🚢 Sea',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bottom Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cost',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      'KSh ${delivery.totalCost.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(delivery.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DeliveryStatus status, ThemeData theme) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status) {
      case DeliveryStatus.pending:
        backgroundColor = Colors.yellow.withValues(alpha: 0.2);
        textColor = Colors.yellow[700]!;
        displayText = 'Pending';
        break;
      case DeliveryStatus.confirmed:
        backgroundColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue[700]!;
        displayText = 'Confirmed';
        break;
      case DeliveryStatus.pickedUp:
        backgroundColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange[700]!;
        displayText = 'Picked Up';
        break;
      case DeliveryStatus.inTransit:
        backgroundColor = Colors.purple.withValues(alpha: 0.2);
        textColor = Colors.purple[700]!;
        displayText = 'In Transit';
        break;
      case DeliveryStatus.outForDelivery:
        backgroundColor = Colors.indigo.withValues(alpha: 0.2);
        textColor = Colors.indigo[700]!;
        displayText = 'Out for Delivery';
        break;
      case DeliveryStatus.delivered:
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green[700]!;
        displayText = 'Delivered';
        break;
      case DeliveryStatus.cancelled:
      case DeliveryStatus.failed:
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red[700]!;
        displayText = status == DeliveryStatus.cancelled ? 'Cancelled' : 'Failed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
