import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/schedule_providers.dart';
import '../models/location.dart';
import '../screens/location_picker_screen.dart';

class ScheduleRideScreen extends ConsumerWidget {
  const ScheduleRideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleState = ref.watch(scheduleRideProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Schedule Ride'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header section
                      _buildHeader(context, theme),
                      
                      const SizedBox(height: 32),
                      
                      // Location inputs
                      _buildLocationSection(context, ref, theme),
                      
                      const SizedBox(height: 24),
                      
                      // Date and Time section
                      _buildDateTimeSection(context, ref, theme),
                      
                      const SizedBox(height: 24),
                      
                      // Fare estimation
                      if (scheduleState.canSchedule)
                        _buildFareEstimation(context, theme, scheduleState),
                      
                      const SizedBox(height: 24),
                      
                      // Error message
                      if (scheduleState.error != null)
                        _buildErrorMessage(context, theme, scheduleState.error!),
                      
                      const SizedBox(height: 100), // Space for button
                    ],
                  ),
                ),
              ),
            ),
            
            // Schedule button
            _buildScheduleButton(context, ref, theme, scheduleState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.1),
                theme.colorScheme.primary.withValues(alpha: 0.05),
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
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule,
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
                      'Schedule Your Ride',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plan your trip in advance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final scheduleState = ref.watch(scheduleRideProvider);
    
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
        
        // Pickup location
        _LocationInputCard(
          title: 'Pickup Location',
          subtitle: 'Where should we pick you up?',
          value: scheduleState.pickupLocation?.displayName,
          icon: Icons.my_location,
          onTap: () => _selectLocation(context, ref, true),
        ),
        
        const SizedBox(height: 12),
        
        // Dropoff location
        _LocationInputCard(
          title: 'Dropoff Location',
          subtitle: 'Where are you going?',
          value: scheduleState.dropoffLocation?.displayName,
          icon: Icons.location_on,
          onTap: () => _selectLocation(context, ref, false),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final scheduleState = ref.watch(scheduleRideProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When do you want to go?',
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
                value: scheduleState.selectedDate != null 
                    ? _formatDate(scheduleState.selectedDate!)
                    : null,
                icon: Icons.calendar_today,
                onTap: () => _selectDate(context, ref),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTimeCard(
                title: 'Time',
                value: scheduleState.selectedTime?.format(context),
                icon: Icons.access_time,
                onTap: () => _selectTime(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFareEstimation(BuildContext context, ThemeData theme, ScheduleRideState scheduleState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Fare',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                scheduleState.estimatedFare != null
                    ? 'KSh ${scheduleState.estimatedFare!.toStringAsFixed(0)}'
                    : 'Calculating...',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
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

  Widget _buildScheduleButton(BuildContext context, WidgetRef ref, ThemeData theme, ScheduleRideState state) {
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
          onPressed: state.isLoading || !state.canSchedule
              ? null
              : () => _handleScheduleRide(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: state.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Schedule Ride',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _selectLocation(BuildContext context, WidgetRef ref, bool isPickup) async {
    final currentLocation = isPickup 
        ? ref.read(scheduleRideProvider).pickupLocation
        : ref.read(scheduleRideProvider).dropoffLocation;
    
    final selected = await Navigator.of(context).push<Location>(
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title: isPickup ? 'Select Pickup Location' : 'Select Dropoff Location',
          initialLocation: currentLocation,
          showCurrentLocation: isPickup,
        ),
      ),
    );

    if (selected != null) {
      if (isPickup) {
        ref.read(scheduleRideProvider.notifier).setPickupLocation(selected);
      } else {
        ref.read(scheduleRideProvider.notifier).setDropoffLocation(selected);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (selectedDate != null) {
      ref.read(scheduleRideProvider.notifier).setSelectedDate(selectedDate);
    }
  }

  Future<void> _selectTime(BuildContext context, WidgetRef ref) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      ref.read(scheduleRideProvider.notifier).setSelectedTime(selectedTime);
    }
  }

  Future<void> _handleScheduleRide(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(scheduleRideProvider.notifier).scheduleRide();
    
    if (success && context.mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride scheduled successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back
      if (context.mounted) {
        Navigator.of(context).pop();
      }
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
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                      color: hasValue
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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

