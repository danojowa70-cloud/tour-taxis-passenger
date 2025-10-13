import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ride.dart';

// State class for schedule ride form
class ScheduleRideState {
  final String? pickupLocation;
  final String? dropoffLocation;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final bool isLoading;
  final String? error;

  const ScheduleRideState({
    this.pickupLocation,
    this.dropoffLocation,
    this.selectedDate,
    this.selectedTime,
    this.isLoading = false,
    this.error,
  });

  ScheduleRideState copyWith({
    String? pickupLocation,
    String? dropoffLocation,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    bool? isLoading,
    String? error,
  }) {
    return ScheduleRideState(
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
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

  void setPickupLocation(String location) {
    state = state.copyWith(pickupLocation: location, error: null);
  }

  void setDropoffLocation(String location) {
    state = state.copyWith(dropoffLocation: location, error: null);
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
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Create scheduled ride (would be saved to database/API in real implementation)
      // For now, just simulate the scheduling process
      
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to schedule ride: $e',
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
      // Simulate loading scheduled rides from API/database
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock scheduled rides
      _scheduledRides = [
        Ride.scheduled(
          id: '1',
          pickupLocation: 'Home',
          dropoffLocation: 'Office',
          scheduledDateTime: DateTime.now().add(const Duration(hours: 2)),
          fare: 300.0,
        ),
        Ride.scheduled(
          id: '2',
          pickupLocation: 'Mall',
          dropoffLocation: 'Airport',
          scheduledDateTime: DateTime.now().add(const Duration(days: 1)),
          fare: 800.0,
        ),
      ];
      
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
      // In a real app, this would call API to cancel
      await Future.delayed(const Duration(milliseconds: 500));
      
      _scheduledRides.removeWhere((ride) => ride.id == rideId);
      state = AsyncValue.data([..._scheduledRides]);
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