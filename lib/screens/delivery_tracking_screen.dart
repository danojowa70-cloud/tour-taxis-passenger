import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery.dart';
import '../providers/delivery_providers.dart';

class DeliveryTrackingScreen extends ConsumerWidget {
  const DeliveryTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(deliveryListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Track Deliveries'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(deliveryListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: deliveries.when(
        data: (deliveryList) {
          if (deliveryList.isEmpty) {
            return _buildEmptyState(context, theme);
          }
          
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Deliveries
                  _buildActiveDeliveries(context, ref, theme),
                  
                  const SizedBox(height: 24),
                  
                  // All Deliveries
                  _buildAllDeliveries(context, ref, theme, deliveryList),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Failed to load deliveries: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(deliveryListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Deliveries Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your delivery tracking information will appear here once you book a delivery.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/delivery-booking'),
              icon: const Icon(Icons.add),
              label: const Text('Book Delivery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveries(BuildContext context, WidgetRef ref, ThemeData theme) {
    final activeDeliveries = ref.watch(activeDeliveriesProvider);
    
    if (activeDeliveries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_shipping,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Active Deliveries',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${activeDeliveries.length}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        ...activeDeliveries.map((delivery) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DeliveryCard(
            delivery: delivery,
            onTap: () => _showDeliveryDetails(context, delivery),
            isActive: true,
          ),
        )),
      ],
    );
  }

  Widget _buildAllDeliveries(BuildContext context, WidgetRef ref, ThemeData theme, List<DeliveryBooking> deliveries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Deliveries',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ...deliveries.map((delivery) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DeliveryCard(
            delivery: delivery,
            onTap: () => _showDeliveryDetails(context, delivery),
            isActive: delivery.isActive,
          ),
        )),
      ],
    );
  }

  void _showDeliveryDetails(BuildContext context, DeliveryBooking delivery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeliveryDetailsSheet(delivery: delivery),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final DeliveryBooking delivery;
  final VoidCallback onTap;
  final bool isActive;

  const _DeliveryCard({
    required this.delivery,
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(delivery.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(delivery.status),
                    color: _getStatusColor(delivery.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.trackingNumber,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        delivery.statusDisplayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _getStatusColor(delivery.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: delivery.vehicleType == DeliveryVehicleType.cargoPlane
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    delivery.vehicleTypeDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: delivery.vehicleType == DeliveryVehicleType.cargoPlane
                          ? Colors.blue[700]
                          : Colors.cyan[700],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Route
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        delivery.sender.city,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'To',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        delivery.recipient.city,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Package & Cost
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.package.description,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${delivery.package.weight}kg • ${delivery.package.type.displayName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'KSh ${delivery.totalCost.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Colors.orange;
      case DeliveryStatus.confirmed:
        return Colors.blue;
      case DeliveryStatus.pickedUp:
        return Colors.purple;
      case DeliveryStatus.inTransit:
        return Colors.indigo;
      case DeliveryStatus.outForDelivery:
        return Colors.amber;
      case DeliveryStatus.delivered:
        return Colors.green;
      case DeliveryStatus.cancelled:
        return Colors.red;
      case DeliveryStatus.failed:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Icons.pending_actions;
      case DeliveryStatus.confirmed:
        return Icons.check_circle_outline;
      case DeliveryStatus.pickedUp:
        return Icons.inventory_2;
      case DeliveryStatus.inTransit:
        return Icons.local_shipping;
      case DeliveryStatus.outForDelivery:
        return Icons.delivery_dining;
      case DeliveryStatus.delivered:
        return Icons.done_all;
      case DeliveryStatus.cancelled:
        return Icons.cancel_outlined;
      case DeliveryStatus.failed:
        return Icons.error_outline;
    }
  }
}

class _DeliveryDetailsSheet extends StatelessWidget {
  final DeliveryBooking delivery;

  const _DeliveryDetailsSheet({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Delivery Details',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tracking Info
                      _buildInfoCard(
                        theme,
                        'Tracking Information',
                        [
                          _buildInfoRow('Tracking Number', delivery.trackingNumber),
                          _buildInfoRow('Status', delivery.statusDisplayName),
                          _buildInfoRow('Vehicle Type', delivery.vehicleTypeDisplayName),
                          _buildInfoRow('Priority', delivery.priority.name.toUpperCase()),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Addresses
                      _buildInfoCard(
                        theme,
                        'Addresses',
                        [
                          _buildInfoRow('From', '${delivery.sender.name}\n${delivery.sender.fullAddress}'),
                          _buildInfoRow('To', '${delivery.recipient.name}\n${delivery.recipient.fullAddress}'),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Package Info
                      _buildInfoCard(
                        theme,
                        'Package Information',
                        [
                          _buildInfoRow('Description', delivery.package.description),
                          _buildInfoRow('Type', delivery.package.type.displayName),
                          _buildInfoRow('Weight', '${delivery.package.weight} kg'),
                          _buildInfoRow('Dimensions', '${delivery.package.length}×${delivery.package.width}×${delivery.package.height} cm'),
                          if (delivery.package.declaredValue != null)
                            _buildInfoRow('Declared Value', 'KSh ${delivery.package.declaredValue!.toStringAsFixed(0)}'),
                          if (delivery.package.isFragile)
                            _buildInfoRow('Special Handling', 'Fragile'),
                          if (delivery.package.requiresRefrigeration)
                            _buildInfoRow('Temperature Control', 'Refrigerated'),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Timeline
                      _buildTimelineCard(theme, delivery.updates),
                      
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(ThemeData theme, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(ThemeData theme, List<DeliveryUpdate> updates) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Timeline',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          if (updates.isEmpty)
            Text(
              'No updates available yet.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          else
            ...updates.asMap().entries.map((entry) {
              final index = entry.key;
              final update = entry.value;
              final isLast = index == updates.length - 1;
              
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          update.message,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(update.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (update.location != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            update.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}