import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ride.dart';
import '../models/location.dart';
import '../services/directions_service.dart';
import '../services/fare_service.dart';
import '../services/scheduled_rides_service.dart';
import '../services/scheduled_ride_notifications_service.dart';

// State class for schedule ride form
class ScheduleRideState {
  final Location? pickupLocation;
  final Location? dropoffLocation;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final double? estimatedFare;
  final int? distanceMeters;
  final int? durationSeconds;
  final bool isLoading;
  final String? error;

  const ScheduleRideState({
    this.pickupLocation,
    this.dropoffLocation,
    this.selectedDate,
    this.selectedTime,
    this.estimatedFare,
    this.distanceMeters,
    this.durationSeconds,
    this.isLoading = false,
    this.error,
  });

  ScheduleRideState copyWith({
    Location? pickupLocation,
    Location? dropoffLocation,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    double? estimatedFare,
    int? distanceMeters,
    int? durationSeconds,
    bool? isLoading,
    String? error,
  }) {
    return ScheduleRideState(
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get canSchedule {
    return pickupLocation != null &&
        dropoffLocation != null &&
        selectedDate != null &&
        selectedTime != null;
  }

  DateTime? get scheduledDateTime {
    if (selectedDate == null || selectedTime == null) return null;
    return DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );
  }
}

// Notifier for schedule ride form
class ScheduleRideNotifier extends StateNotifier<ScheduleRideState> {
  ScheduleRideNotifier() : super(const ScheduleRideState());

  void setPickupLocation(Location location) {
    state = state.copyWith(pickupLocation: location, error: null);
    _calculateFareIfPossible();
  }

  void setDropoffLocation(Location location) {
    state = state.copyWith(dropoffLocation: location, error: null);
    _calculateFareIfPossible();
  }

  Future<void> _calculateFareIfPossible() async {
    final pickup = state.pickupLocation;
    final dropoff = state.dropoffLocation;
    
    if (pickup?.hasCoordinates == true && dropoff?.hasCoordinates == true) {
      try {
        final directionsService = DirectionsService('AIzaSyBRYPKaXlRhpzoAmM5-KrS2JaNDxAX_phw');
        const fareService = FareService();
        
        final route = await directionsService.routeLatLng(
          pickup!.latitude!,
          pickup.longitude!,
          dropoff!.latitude!,
          dropoff.longitude!,
        );
        
        if (route != null) {
          final fare = fareService.estimate(
            distanceMeters: route.distanceMeters,
            durationSeconds: route.durationSeconds,
          );
          
          state = state.copyWith(
            estimatedFare: fare,
            distanceMeters: route.distanceMeters.toInt(),
            durationSeconds: route.durationSeconds.toInt(),
          );
        }
      } catch (e) {
        // Silently handle fare calculation errors
        debugPrint('Failed to calculate fare: $e');
      }
    }
  }

  void setSelectedDate(DateTime date) {
    state = state.copyWith(selectedDate: date, error: null);
  }

  void setSelectedTime(TimeOfDay time) {
    state = state.copyWith(selectedTime: time, error: null);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = const ScheduleRideState();
  }

  Future<bool> scheduleRide() async {
    if (!state.canSchedule) {
      state = state.copyWith(error: 'Please fill all required fields');
      return false;
    }

    final scheduledDateTime = state.scheduledDateTime!;
    final now = DateTime.now();
    
    // Check if scheduled time is in the future
    if (scheduledDateTime.isBefore(now.add(const Duration(minutes: 30)))) {
      state = state.copyWith(error: 'Please schedule at least 30 minutes in advance');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('📅 Scheduling ride for ${scheduledDateTime.toString()}');
      
      // Save scheduled ride to database/API with proper location coordinates
      final scheduledRidesService = ScheduledRidesService();
      
      final success = await scheduledRidesService.scheduleRide(
        pickupLocation: state.pickupLocation!,
        dropoffLocation: state.dropoffLocation!,
        scheduledDateTime: scheduledDateTime,
        estimatedFare: state.estimatedFare ?? 0.0,
        distanceMeters: state.distanceMeters,
        durationSeconds: state.durationSeconds,
      );
      
      if (!success) {
        debugPrint('❌ Schedule ride failed');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to schedule ride. Please try again.',
        );
        return false;
      }
      
      debugPrint('✅ Ride scheduled successfully');
      
      // Schedule reminder notification for passenger
      try {
        await ScheduledRideNotificationsService.scheduleRideReminder(
          rideId: DateTime.now().millisecondsSinceEpoch.toString(), // Use timestamp as ID
          scheduledTime: scheduledDateTime,
          pickupLocation: state.pickupLocation!.displayName,
          dropoffLocation: state.dropoffLocation!.displayName,
          minutesBefore: 30,
        );
        debugPrint('⏰ Passenger reminder scheduled');
      } catch (e) {
        debugPrint('⚠️ Failed to schedule reminder: $e');
      }
      
      state = state.copyWith(isLoading: false);
      // NOTE: scheduledRidesProvider will be refreshed from the calling code
      return true;
    } catch (e) {
      debugPrint('❌ Error scheduling ride: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to schedule ride. Please try again.',
      );
      return false;
    }
  }

}

// State notifier for managing list of scheduled rides
class ScheduledRidesNotifier extends StateNotifier<AsyncValue<List<Ride>>> {
  ScheduledRidesNotifier() : super(const AsyncValue.loading()) {
    _loadScheduledRides();
  }

  List<Ride> _scheduledRides = [];

  Future<void> _loadScheduledRides() async {
    try {
      final scheduledRidesService = ScheduledRidesService();
      _scheduledRides = await scheduledRidesService.getScheduledRides();
      state = AsyncValue.data(_scheduledRides);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> addScheduledRide(Ride ride) async {
    state = const AsyncValue.loading();
    try {
      // In a real app, this would save to API/database
      await Future.delayed(const Duration(milliseconds: 500));
      
      _scheduledRides.add(ride);
      state = AsyncValue.data([..._scheduledRides]);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> cancelScheduledRide(String rideId) async {
    try {
      final scheduledRidesService = ScheduledRidesService();
      final success = await scheduledRidesService.cancelScheduledRide(rideId);
      
      if (success) {
        _scheduledRides.removeWhere((ride) => ride.id == rideId);
        state = AsyncValue.data([..._scheduledRides]);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void refresh() {
    _loadScheduledRides();
  }
}

// Providers
final scheduleRideProvider = StateNotifierProvider<ScheduleRideNotifier, ScheduleRideState>(
  (ref) => ScheduleRideNotifier(),
);

final scheduledRidesProvider = StateNotifierProvider<ScheduledRidesNotifier, AsyncValue<List<Ride>>>(
  (ref) => ScheduledRidesNotifier(),
);

// Helper provider for next scheduled ride
final nextScheduledRideProvider = Provider<Ride?>((ref) {
  final scheduledRides = ref.watch(scheduledRidesProvider);
  
  return scheduledRides.when(
    data: (rides) {
      if (rides.isEmpty) return null;
      
      final now = DateTime.now();
      final futureRides = rides
          .where((ride) => ride.scheduledDateTime != null && ride.scheduledDateTime!.isAfter(now))
          .toList();
      
      if (futureRides.isEmpty) return null;
      
      futureRides.sort((a, b) => a.scheduledDateTime!.compareTo(b.scheduledDateTime!));
      return futureRides.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});