import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery.dart';
import '../models/vehicle_type.dart';
import '../providers/delivery_providers.dart';

class DeliveryBookingScreen extends ConsumerWidget {
  const DeliveryBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(deliveryBookingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Delivery Booking'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () => Navigator.pushNamed(context, '/delivery-tracking'),
              icon: const Icon(Icons.track_changes),
              tooltip: 'Track Deliveries',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(context, theme),
                    
                    const SizedBox(height: 16),
                    
                    // Track Deliveries Button
                    _buildTrackDeliveriesButton(context, ref, theme),
                    
                    const SizedBox(height: 32),
                    
                    // Vehicle Selection
                    _buildVehicleSelection(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Sender Details
                    _buildSenderDetails(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Recipient Details
                    _buildRecipientDetails(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Package Details
                    _buildPackageDetails(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Priority & Pickup
                    _buildPriorityAndPickup(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Notes
                    _buildNotesSection(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Error Message
                    if (bookingState.error != null)
                      _buildErrorMessage(context, theme, bookingState.error!),
                    
                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
            ),
          ),
          
          // Book Button
          _buildBookButton(context, ref, theme, bookingState),
        ],
      ),
    );
  }

  Widget _buildTrackDeliveriesButton(BuildContext context, WidgetRef ref, ThemeData theme) {
    final deliveries = ref.watch(activeDeliveriesProvider);
    
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/delivery-tracking'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withValues(alpha: 0.1),
              Colors.teal.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.track_changes,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track My Deliveries',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deliveries.isEmpty 
                        ? 'No active deliveries'
                        : '${deliveries.length} active ${deliveries.length == 1 ? "delivery" : "deliveries"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.green[700],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
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
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Service',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Air & Sea Freight Solutions',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final bookingState = ref.watch(deliveryBookingProvider);
    final deliveryTypes = VehicleTypeInfo.getDeliveryTypes();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Delivery Method',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: deliveryTypes.length,
          itemBuilder: (context, index) {
            final vehicleInfo = deliveryTypes[index];
            final deliveryType = _getDeliveryVehicleType(vehicleInfo.type);
            final isSelected = bookingState.selectedVehicleType == deliveryType;
            
            return _VehicleTypeCard(
              vehicleInfo: vehicleInfo,
              isSelected: isSelected,
              onTap: () {
                if (deliveryType != null) {
                  ref.read(deliveryBookingProvider.notifier).setVehicleType(deliveryType);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSenderDetails(BuildContext context, WidgetRef ref, ThemeData theme) {
    return _ContactDetailsCard(
      title: 'Sender Details',
      subtitle: 'Who is sending the package?',
      icon: Icons.person_outline,
      onTap: () => _showContactDialog(context, ref, true),
      contactDetails: ref.watch(deliveryBookingProvider).sender,
      theme: theme,
    );
  }

  Widget _buildRecipientDetails(BuildContext context, WidgetRef ref, ThemeData theme) {
    return _ContactDetailsCard(
      title: 'Recipient Details',
      subtitle: 'Who will receive the package?',
      icon: Icons.person_add_outlined,
      onTap: () => _showContactDialog(context, ref, false),
      contactDetails: ref.watch(deliveryBookingProvider).recipient,
      theme: theme,
    );
  }

  Widget _buildPackageDetails(BuildContext context, WidgetRef ref, ThemeData theme) {
    final bookingState = ref.watch(deliveryBookingProvider);
    
    return GestureDetector(
      onTap: () => _showPackageDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: bookingState.package != null 
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bookingState.package != null
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: bookingState.package != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Package Details',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookingState.package != null 
                        ? '${bookingState.package!.description} (${bookingState.package!.weight}kg)'
                        : 'Add package information',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: bookingState.package != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: bookingState.package != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityAndPickup(BuildContext context, WidgetRef ref, ThemeData theme) {
    final bookingState = ref.watch(deliveryBookingProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Priority & Pickup',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Priority Selection
        Container(
          padding: const EdgeInsets.all(16),
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
                'Priority Level',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<DeliveryPriority>(
                groupValue: bookingState.selectedPriority,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(deliveryBookingProvider.notifier).setPriority(value);
                  }
                },
                child: Column(
                  children: DeliveryPriority.values.map((priority) {
                    return RadioListTile<DeliveryPriority>(
                      title: Text(priority.name.toUpperCase()),
                      subtitle: Text(priority.description),
                      value: priority,
                      activeColor: theme.colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Pickup Date & Time
        Row(
          children: [
            Expanded(
              child: _DateTimeCard(
                title: 'Pickup Date',
                value: bookingState.pickupDate != null 
                    ? _formatDate(bookingState.pickupDate!)
                    : null,
                icon: Icons.calendar_today,
                onTap: () => _selectPickupDate(context, ref),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTimeCard(
                title: 'Pickup Time',
                value: bookingState.pickupTime?.format(context),
                icon: Icons.access_time,
                onTap: () => _selectPickupTime(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context, WidgetRef ref, ThemeData theme) {
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
            'Special Instructions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            decoration: InputDecoration(
              hintText: 'Any special handling instructions...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            maxLines: 3,
            onChanged: (value) {
              ref.read(deliveryBookingProvider.notifier).setNotes(value.trim());
            },
          ),
        ],
      ),
    );
  }


  Widget _buildErrorMessage(BuildContext context, ThemeData theme, String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton(BuildContext context, WidgetRef ref, ThemeData theme, DeliveryBookingState bookingState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: bookingState.isLoading || !bookingState.canBook
              ? null
              : () => _handleBooking(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: bookingState.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Book Delivery',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // Helper methods
  DeliveryVehicleType? _getDeliveryVehicleType(VehicleType vehicleType) {
    switch (vehicleType) {
      case VehicleType.cargoPlane:
        return DeliveryVehicleType.cargoPlane;
      case VehicleType.cargoShip:
        return DeliveryVehicleType.cargoShip;
      default:
        return null;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(date.year, date.month, date.day);
    
    final difference = selectedDay.difference(today).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Action methods
  Future<void> _selectPickupDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      ref.read(deliveryBookingProvider.notifier).setPickupDate(selectedDate);
    }
  }

  Future<void> _selectPickupTime(BuildContext context, WidgetRef ref) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      ref.read(deliveryBookingProvider.notifier).setPickupTime(selectedTime);
    }
  }

  Future<void> _showContactDialog(BuildContext context, WidgetRef ref, bool isSender) async {
    final result = await showDialog<ContactDetails>(
      context: context,
      builder: (context) => _ContactDialog(
        title: isSender ? 'Sender Details' : 'Recipient Details',
        initialContact: isSender 
            ? ref.read(deliveryBookingProvider).sender
            : ref.read(deliveryBookingProvider).recipient,
      ),
    );

    if (result != null) {
      if (isSender) {
        ref.read(deliveryBookingProvider.notifier).setSender(result);
      } else {
        ref.read(deliveryBookingProvider.notifier).setRecipient(result);
      }
    }
  }

  Future<void> _showPackageDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<PackageDetails>(
      context: context,
      builder: (context) => _PackageDialog(
        initialPackage: ref.read(deliveryBookingProvider).package,
      ),
    );

    if (result != null) {
      ref.read(deliveryBookingProvider.notifier).setPackage(result);
    }
  }

  Future<void> _handleBooking(BuildContext context, WidgetRef ref) async {
    final delivery = await ref
        .read(deliveryBookingProvider.notifier)
        .confirmBooking();
    
    if (delivery != null && context.mounted) {
      // Show success dialog matching design
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const Text(
                  'Booking Confirmed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Icon
                const Text(
                  '📦',
                  style: TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 16),
                
                // Message
                const Text(
                  'Your delivery has been booked successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                
                // Tracking Number
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Tracking Number:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        delivery.trackingNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'You can track your delivery progress from the dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(); // Go back to dashboard
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                          // Navigate to tracking screen
                          Navigator.pushNamed(
                            context,
                            '/delivery-tracking',
                            arguments: delivery.id,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Track Delivery',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// Supporting widgets
class _VehicleTypeCard extends StatelessWidget {
  final VehicleTypeInfo vehicleInfo;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleTypeCard({
    required this.vehicleInfo,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              vehicleInfo.icon,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              vehicleInfo.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              vehicleInfo.estimatedArrivalTime,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactDetailsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final ContactDetails? contactDetails;
  final ThemeData theme;

  const _ContactDetailsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.contactDetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasContact = contactDetails != null;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasContact 
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasContact
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: hasContact
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasContact ? '${contactDetails!.name} - ${contactDetails!.city}' : subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasContact
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: hasContact ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeCard extends StatelessWidget {
  final String title;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateTimeCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasValue 
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasValue
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: hasValue
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasValue ? value! : 'Select',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: hasValue
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog widgets would be implemented here
class _ContactDialog extends StatefulWidget {
  final String title;
  final ContactDetails? initialContact;

  const _ContactDialog({
    required this.title,
    this.initialContact,
  });

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _countryController;
  late final TextEditingController _companyController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialContact?.name ?? '');
    _phoneController = TextEditingController(text: widget.initialContact?.phone ?? '');
    _emailController = TextEditingController(text: widget.initialContact?.email ?? '');
    _addressController = TextEditingController(text: widget.initialContact?.address ?? '');
    _cityController = TextEditingController(text: widget.initialContact?.city ?? '');
    _stateController = TextEditingController(text: widget.initialContact?.state ?? '');
    _postalCodeController = TextEditingController(text: widget.initialContact?.postalCode ?? '');
    _countryController = TextEditingController(text: widget.initialContact?.country ?? 'Kenya');
    _companyController = TextEditingController(text: widget.initialContact?.company ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              _buildTextField('Full Name *', _nameController),
              _buildTextField('Phone Number *', _phoneController),
              _buildTextField('Email Address *', _emailController),
              _buildTextField('Street Address *', _addressController),
              _buildTextField('City *', _cityController),
              _buildTextField('State/Province *', _stateController),
              _buildTextField('Postal Code *', _postalCodeController),
              _buildTextField('Country *', _countryController),
              _buildTextField('Company (Optional)', _companyController),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveContact,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _saveContact() {
    if (_nameController.text.isEmpty || 
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _cityController.text.isEmpty) {
      return;
    }

    final contact = ContactDetails(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      country: _countryController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
    );

    Navigator.of(context).pop(contact);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _companyController.dispose();
    super.dispose();
  }
}

class _PackageDialog extends StatefulWidget {
  final PackageDetails? initialPackage;

  const _PackageDialog({this.initialPackage});

  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _weightController;
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _declaredValueController;
  late final TextEditingController _instructionsController;

  PackageType _selectedType = PackageType.other;
  bool _isFragile = false;
  bool _requiresRefrigeration = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialPackage?.description ?? '');
    _weightController = TextEditingController(text: widget.initialPackage?.weight.toString() ?? '');
    _lengthController = TextEditingController(text: widget.initialPackage?.length.toString() ?? '');
    _widthController = TextEditingController(text: widget.initialPackage?.width.toString() ?? '');
    _heightController = TextEditingController(text: widget.initialPackage?.height.toString() ?? '');
    _declaredValueController = TextEditingController(text: widget.initialPackage?.declaredValue?.toString() ?? '');
    _instructionsController = TextEditingController(text: widget.initialPackage?.specialInstructions ?? '');
    
    if (widget.initialPackage != null) {
      _selectedType = widget.initialPackage!.type;
      _isFragile = widget.initialPackage!.isFragile;
      _requiresRefrigeration = widget.initialPackage!.requiresRefrigeration;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Package Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              _buildTextField('Package Description *', _descriptionController),
              
              // Package Type Dropdown
              DropdownButtonFormField<PackageType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Package Type *',
                  border: OutlineInputBorder(),
                ),
                items: PackageType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text('${type.icon} ${type.displayName}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Dimensions
              Row(
                children: [
                  Expanded(child: _buildTextField('Weight (kg) *', _weightController)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField('Length (cm) *', _lengthController)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField('Width (cm) *', _widthController)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField('Height (cm) *', _heightController)),
                ],
              ),
              
              _buildTextField('Declared Value (KSh)', _declaredValueController),
              _buildTextField('Special Instructions', _instructionsController, maxLines: 3),
              
              // Checkboxes
              CheckboxListTile(
                title: const Text('Fragile item'),
                value: _isFragile,
                onChanged: (value) => setState(() => _isFragile = value ?? false),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Requires refrigeration'),
                value: _requiresRefrigeration,
                onChanged: (value) => setState(() => _requiresRefrigeration = value ?? false),
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _savePackage,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _savePackage() {
    if (_descriptionController.text.isEmpty || 
        _weightController.text.isEmpty ||
        _lengthController.text.isEmpty ||
        _widthController.text.isEmpty ||
        _heightController.text.isEmpty) {
      return;
    }

    final package = PackageDetails(
      description: _descriptionController.text.trim(),
      type: _selectedType,
      weight: double.tryParse(_weightController.text) ?? 0,
      length: double.tryParse(_lengthController.text) ?? 0,
      width: double.tryParse(_widthController.text) ?? 0,
      height: double.tryParse(_heightController.text) ?? 0,
      declaredValue: double.tryParse(_declaredValueController.text),
      isFragile: _isFragile,
      requiresRefrigeration: _requiresRefrigeration,
      specialInstructions: _instructionsController.text.trim().isEmpty 
          ? null 
          : _instructionsController.text.trim(),
    );

    Navigator.of(context).pop(package);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _declaredValueController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }
}