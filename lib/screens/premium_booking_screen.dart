import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/boarding_pass.dart';
import '../models/vehicle_type.dart';
import '../providers/boarding_pass_providers.dart';
import '../providers/auth_providers.dart';

class PremiumBookingScreen extends ConsumerWidget {
  const PremiumBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(premiumBookingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Premium Booking'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    
                    const SizedBox(height: 32),
                    
                    // Vehicle Selection
                    _buildVehicleSelection(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Location Selection
                    _buildLocationSelection(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Date & Time Selection
                    _buildDateTimeSelection(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Passengers
                    _buildPassengerSelection(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Passenger Name Input
                    _buildPassengerNameInput(context, ref, theme),
                    
                    const SizedBox(height: 24),
                    
                    // Fare Estimation
                    if (bookingState.estimatedFare != null)
                      _buildFareEstimation(context, theme, bookingState),
                    
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

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.1),
            Colors.orange.withValues(alpha: 0.05),
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
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.flight,
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
                  'Premium Travel',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Helicopter, Private Jet & Luxury Cruise',
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
    final bookingState = ref.watch(premiumBookingProvider);
    final premiumTypes = VehicleTypeInfo.getPremiumTypes();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Vehicle Type',
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
          itemCount: premiumTypes.length,
          itemBuilder: (context, index) {
            final vehicleInfo = premiumTypes[index];
            final premiumType = _getPremiumVehicleType(vehicleInfo.type);
            final isSelected = bookingState.selectedVehicleType == premiumType;
            
            return _VehicleTypeCard(
              vehicleInfo: vehicleInfo,
              isSelected: isSelected,
              onTap: () {
                ref.read(premiumBookingProvider.notifier).setVehicleType(premiumType!);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocationSelection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final bookingState = ref.watch(premiumBookingProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip Details',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        _LocationInputCard(
          title: 'Origin',
          subtitle: 'Departure location',
          value: bookingState.origin,
          icon: Icons.flight_takeoff,
          onTap: () => _selectLocation(context, ref, true),
        ),
        
        const SizedBox(height: 12),
        
        _LocationInputCard(
          title: 'Destination',
          subtitle: 'Arrival location',
          value: bookingState.destination,
          icon: Icons.flight_land,
          onTap: () => _selectLocation(context, ref, false),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final bookingState = ref.watch(premiumBookingProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Departure Schedule',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: _DateTimeCard(
                title: 'Date',
                value: bookingState.departureDate != null 
                    ? _formatDate(bookingState.departureDate!)
                    : null,
                icon: Icons.calendar_today,
                onTap: () => _selectDepartureDate(context, ref),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTimeCard(
                title: 'Time',
                value: bookingState.departureTime?.format(context),
                icon: Icons.access_time,
                onTap: () => _selectDepartureTime(context, ref),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Arrival Schedule (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _DateTimeCard(
                title: 'Arrival Date',
                value: bookingState.arrivalDate != null 
                    ? _formatDate(bookingState.arrivalDate!)
                    : null,
                icon: Icons.calendar_today_outlined,
                onTap: () => _selectArrivalDate(context, ref),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTimeCard(
                title: 'Arrival Time',
                value: bookingState.arrivalTime?.format(context),
                icon: Icons.access_time_outlined,
                onTap: () => _selectArrivalTime(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPassengerSelection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final bookingState = ref.watch(premiumBookingProvider);
    
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
            'Passengers',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Number of passengers',
                style: theme.textTheme.bodyMedium,
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: bookingState.passengers > 1
                        ? () => ref.read(premiumBookingProvider.notifier).setPassengers(bookingState.passengers - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: theme.colorScheme.primary,
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '${bookingState.passengers}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref.read(premiumBookingProvider.notifier).setPassengers(bookingState.passengers + 1),
                    icon: const Icon(Icons.add_circle_outline),
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerNameInput(BuildContext context, WidgetRef ref, ThemeData theme) {
    final bookingState = ref.watch(premiumBookingProvider);
    
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
          Row(
            children: [
              Icon(
                Icons.people_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Passenger Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter details for all ${bookingState.passengers} passenger${bookingState.passengers > 1 ? 's' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          
          // Generate passenger detail input boxes
          ...List.generate(bookingState.passengers, (index) {
            final passenger = index < bookingState.passengerDetails.length
                ? bookingState.passengerDetails[index]
                : null;
            
            return Padding(
              padding: EdgeInsets.only(bottom: index < bookingState.passengers - 1 ? 20 : 0),
              child: _PassengerDetailBox(
                passengerNumber: index + 1,
                passenger: passenger,
                onNameChanged: (value) {
                  ref.read(premiumBookingProvider.notifier).updatePassengerDetail(
                    index,
                    name: value,
                  );
                },
                onEmailChanged: (value) {
                  ref.read(premiumBookingProvider.notifier).updatePassengerDetail(
                    index,
                    email: value,
                  );
                },
                onPhoneChanged: (value) {
                  ref.read(premiumBookingProvider.notifier).updatePassengerDetail(
                    index,
                    phone: value,
                  );
                },
              ),
            );
          }),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Names must match government-issued IDs for boarding',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareEstimation(BuildContext context, ThemeData theme, PremiumBookingState bookingState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.1),
            Colors.green.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Estimated Fare',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Text(
            'KSh ${bookingState.estimatedFare!.toStringAsFixed(0)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            'For ${bookingState.passengers} passenger${bookingState.passengers > 1 ? 's' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.green[600],
            ),
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

  Widget _buildBookButton(BuildContext context, WidgetRef ref, ThemeData theme, PremiumBookingState bookingState) {
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
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  'Book Premium Ride',
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
  PremiumVehicleType? _getPremiumVehicleType(VehicleType vehicleType) {
    switch (vehicleType) {
      case VehicleType.chopper:
        return PremiumVehicleType.chopper;
      case VehicleType.privateJet:
        return PremiumVehicleType.privateJet;
      case VehicleType.cruise:
        return PremiumVehicleType.cruise;
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
  Future<void> _selectLocation(BuildContext context, WidgetRef ref, bool isOrigin) async {
    final locations = [
      'Nairobi',
      'Mombasa',
      'Kisumu',
      'Eldoret',
      'Nakuru',
      'Thika',
      'Malindi',
      'Lamu',
      'Turkana',
      'Maasai Mara',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _LocationPickerSheet(locations: locations),
    );

    if (selected != null) {
      if (isOrigin) {
        ref.read(premiumBookingProvider.notifier).setOrigin(selected);
      } else {
        ref.read(premiumBookingProvider.notifier).setDestination(selected);
      }
    }
  }

  Future<void> _selectDepartureDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      ref.read(premiumBookingProvider.notifier).setDepartureDate(selectedDate);
    }
  }

  Future<void> _selectDepartureTime(BuildContext context, WidgetRef ref) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      ref.read(premiumBookingProvider.notifier).setDepartureTime(selectedTime);
    }
  }

  Future<void> _selectArrivalDate(BuildContext context, WidgetRef ref) async {
    final bookingState = ref.read(premiumBookingProvider);
    final initialDate = bookingState.departureDate ?? DateTime.now().add(const Duration(days: 1));
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      ref.read(premiumBookingProvider.notifier).setArrivalDate(selectedDate);
    }
  }

  Future<void> _selectArrivalTime(BuildContext context, WidgetRef ref) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      ref.read(premiumBookingProvider.notifier).setArrivalTime(selectedTime);
    }
  }

  Future<void> _handleBooking(BuildContext context, WidgetRef ref) async {
    // Get user name
    final userProfile = ref.read(userProfileProvider).asData?.value;
    final defaultName = userProfile?['name'] as String?;

    final boardingPass = await ref
        .read(premiumBookingProvider.notifier)
        .confirmBooking(defaultName);
    
    if (boardingPass != null && context.mounted) {
      // Show success dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Booking Confirmed! ✈️'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your premium ride has been booked successfully.'),
              const SizedBox(height: 16),
              Text(
                'Booking ID: ${boardingPass.bookingId}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Your boarding pass has been generated automatically.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to dashboard
              },
              child: const Text('Continue'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed(
                  '/boarding-pass',
                  arguments: boardingPass.id,
                );
              },
              child: const Text('View Boarding Pass'),
            ),
          ],
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
              '${vehicleInfo.capacity} seats',
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

class _LocationInputCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const _LocationInputCard({
    required this.title,
    required this.subtitle,
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
        child: Row(
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
                    hasValue ? value! : subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasValue
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
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

class _PassengerDetailBox extends StatelessWidget {
  final int passengerNumber;
  final dynamic passenger; // PassengerDetail or null
  final Function(String) onNameChanged;
  final Function(String) onEmailChanged;
  final Function(String) onPhoneChanged;

  const _PassengerDetailBox({
    required this.passengerNumber,
    required this.passenger,
    required this.onNameChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = passenger?.name ?? '';
    final email = passenger?.email ?? '';
    final phone = passenger?.phone ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$passengerNumber',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Passenger $passengerNumber',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Name field
          TextFormField(
            initialValue: name,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: 'As per ID',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 12),
          
          // Email field (optional)
          TextFormField(
            initialValue: email,
            decoration: InputDecoration(
              labelText: 'Email (Optional)',
              hintText: 'passenger@example.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: onEmailChanged,
          ),
          const SizedBox(height: 12),
          
          // Phone field (optional)
          TextFormField(
            initialValue: phone,
            decoration: InputDecoration(
              labelText: 'Phone (Optional)',
              hintText: '+254 XXX XXX XXX',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            keyboardType: TextInputType.phone,
            onChanged: onPhoneChanged,
          ),
        ],
      ),
    );
  }
}

class _LocationPickerSheet extends StatelessWidget {
  final List<String> locations;

  const _LocationPickerSheet({required this.locations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Select Location',
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
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(location),
                  onTap: () => Navigator.of(context).pop(location),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}