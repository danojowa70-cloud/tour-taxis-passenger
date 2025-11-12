import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/ride.dart';
import '../services/socket_service.dart';

/// Socket service provider
final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService.instance;
});

/// Ride state for socket-based rides
class SocketRideState {
  final Ride? currentRide;
  final String status; // idle, requesting, submitted, accepted, started, completed, cancelled, timeout, no_drivers
  final String? errorMessage;
  final bool isSearching;
  final Map<String, dynamic>? lastEvent;
  final List<Map<String, dynamic>> nearbyDrivers;
  
  const SocketRideState({
    this.currentRide,
    this.status = 'idle',
    this.errorMessage,
    this.isSearching = false,
    this.lastEvent,
    this.nearbyDrivers = const [],
  });

  SocketRideState copyWith({
    Ride? currentRide,
    String? status,
    String? errorMessage,
    bool? isSearching,
    Map<String, dynamic>? lastEvent,
    List<Map<String, dynamic>>? nearbyDrivers,
  }) {
    return SocketRideState(
      currentRide: currentRide ?? this.currentRide,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isSearching: isSearching ?? this.isSearching,
      lastEvent: lastEvent ?? this.lastEvent,
      nearbyDrivers: nearbyDrivers ?? this.nearbyDrivers,
    );
  }

  SocketRideState clearError() {
    return copyWith(errorMessage: null);
  }

  SocketRideState clearRide() {
    return const SocketRideState();
  }
}

/// Socket ride notifier - manages ride state with socket events
class SocketRideNotifier extends StateNotifier<SocketRideState> {
  final SocketService _socketService;
  final List<StreamSubscription> _subscriptions = [];
  
  SocketRideNotifier(this._socketService) : super(const SocketRideState()) {
    _setupSocketListeners();
  }

  /// Set up all socket event listeners
  void _setupSocketListeners() {
    // Connection status
    _subscriptions.add(
      _socketService.connectionStatusStream.listen((isConnected) {
        debugPrint('🔌 Socket connection status: $isConnected');
        if (!isConnected && state.isSearching) {
          state = state.copyWith(
            errorMessage: 'Lost connection to server',
            isSearching: false,
          );
        }
      })
    );

    // Ride request submitted
    _subscriptions.add(
      _socketService.rideRequestSubmittedStream.listen((data) {
        debugPrint('📝 Ride request submitted: $data');
        
        final rideId = data['ride_id'] as String?;
        final estimatedFare = data['estimated_fare']?.toString();
        final distance = data['distance']?.toString();
        final duration = data['duration']?.toString();

        if (rideId != null && state.currentRide != null) {
          state = state.copyWith(
            currentRide: state.currentRide!.copyWith(
              id: rideId,
              fare: estimatedFare,
              distance: distance,
              duration: duration,
              status: 'submitted',
            ),
            status: 'submitted',
            isSearching: true,
            lastEvent: data,
          );
        }
      })
    );

    // Ride accepted
    _subscriptions.add(
      _socketService.rideAcceptedStream.listen((data) {
        debugPrint('🎉 Ride accepted event received!');
        debugPrint('📝 Ride accepted data: $data');
        
        final ride = Ride.fromSocketData(data);
        debugPrint('🚗 Ride object created: ${ride.id}, status: ${ride.status}');
        
        state = state.copyWith(
          currentRide: ride.copyWith(status: 'accepted'),
          status: 'accepted',
          isSearching: false,
          lastEvent: data,
        );
        
        debugPrint('✅ Socket ride state updated to accepted');
      })
    );

    // Driver location updates
    _subscriptions.add(
      _socketService.driverLocationStream.listen((data) {
        debugPrint('📍 Driver location update: $data');
        
        if (state.currentRide != null) {
          final lat = data['latitude'] as num?;
          final lng = data['longitude'] as num?;
          
          if (lat != null && lng != null) {
            state = state.copyWith(
              currentRide: state.currentRide!.copyWith(
                driverLatitude: lat.toDouble(),
                driverLongitude: lng.toDouble(),
              ),
              lastEvent: data,
            );
          }
        }
      })
    );

    // Ride started
    _subscriptions.add(
      _socketService.rideStartedStream.listen((data) {
        debugPrint('🚗 Ride started event received!');
        debugPrint('📝 Ride started data: $data');
        
        if (state.currentRide != null) {
          state = state.copyWith(
            currentRide: state.currentRide!.copyWith(
              status: 'started',
              startedAt: DateTime.now(),
            ),
            status: 'started',
            lastEvent: data,
          );
          debugPrint('✅ Socket ride state updated to started');
        } else {
          debugPrint('⚠️ Ride started but no current ride in state!');
          // Try to create ride from data
          try {
            final ride = Ride.fromSocketData(data);
            state = state.copyWith(
              currentRide: ride.copyWith(status: 'started', startedAt: DateTime.now()),
              status: 'started',
              isSearching: false,
              lastEvent: data,
            );
            debugPrint('✅ Created ride from started event and updated state');
          } catch (e) {
            debugPrint('❌ Error creating ride from started event: $e');
          }
        }
      })
    );

    // Ride completed
    _subscriptions.add(
      _socketService.rideCompletedStream.listen((data) {
        debugPrint('🏁 Ride completed: $data');
        
        if (state.currentRide != null) {
          state = state.copyWith(
            currentRide: state.currentRide!.copyWith(
              status: 'completed',
              completedAt: DateTime.now(),
              fare: data['fare']?.toString() ?? state.currentRide!.fare,
              distance: data['distance']?.toString() ?? state.currentRide!.distance,
              duration: data['duration']?.toString() ?? state.currentRide!.duration,
            ),
            status: 'completed',
            lastEvent: data,
          );
        }
      })
    );

    // Ride cancelled
    _subscriptions.add(
      _socketService.rideCancelledStream.listen((data) {
        debugPrint('❌ Ride cancelled: $data');
        
        final reason = data['reason'] as String? ?? 'Ride was cancelled';
        
        state = state.copyWith(
          status: 'cancelled',
          errorMessage: reason,
          isSearching: false,
          lastEvent: data,
        );
      })
    );

    // No drivers available
    _subscriptions.add(
      _socketService.noDriversAvailableStream.listen((data) {
        debugPrint('🚫 No drivers available: $data');
        
        // Ignore if ride is already accepted or started
        if (state.status == 'accepted' || state.status == 'started') {
          debugPrint('⚠️ Ignoring no_drivers event - ride already ${state.status}');
          return;
        }
        
        // Validate ride ID if present in the event
        final eventRideId = data['ride_id'] as String?;
        if (eventRideId != null && state.currentRide != null && state.currentRide!.id != 'pending') {
          if (eventRideId != state.currentRide!.id) {
            debugPrint('⚠️ Ignoring no_drivers event for old ride: $eventRideId (current: ${state.currentRide!.id})');
            return;
          }
        }
        
        // Only apply if currently searching
        if (!state.isSearching && state.status != 'requesting' && state.status != 'submitted') {
          debugPrint('⚠️ Ignoring no_drivers event - not currently searching (status: ${state.status})');
          return;
        }
        
        final message = data['message'] as String? ?? 'No drivers available in your area';
        
        state = state.copyWith(
          status: 'no_drivers',
          errorMessage: message,
          isSearching: false,
          lastEvent: data,
        );
      })
    );

    // Ride timeout
    _subscriptions.add(
      _socketService.rideTimeoutStream.listen((data) {
        debugPrint('⏰ Ride timeout: $data');
        
        // Ignore if ride is already accepted or started
        if (state.status == 'accepted' || state.status == 'started') {
          debugPrint('⚠️ Ignoring timeout event - ride already ${state.status}');
          return;
        }
        
        // Validate ride ID if present in the event
        final eventRideId = data['ride_id'] as String?;
        if (eventRideId != null && state.currentRide != null && state.currentRide!.id != 'pending') {
          if (eventRideId != state.currentRide!.id) {
            debugPrint('⚠️ Ignoring timeout event for old ride: $eventRideId (current: ${state.currentRide!.id})');
            return;
          }
        }
        
        // Only apply if currently searching
        if (!state.isSearching && state.status != 'requesting' && state.status != 'submitted') {
          debugPrint('⚠️ Ignoring timeout event - not currently searching (status: ${state.status})');
          return;
        }
        
        final message = data['message'] as String? ?? 'No driver accepted your ride request';
        
        state = state.copyWith(
          status: 'timeout',
          errorMessage: message,
          isSearching: false,
          lastEvent: data,
        );
      })
    );

    // Errors
    _subscriptions.add(
      _socketService.errorStream.listen((data) {
        debugPrint('❌ Socket error: $data');
        
        final message = data['message'] as String? ?? 'An error occurred';
        
        state = state.copyWith(
          errorMessage: message,
          isSearching: false,
        );
      })
    );

    // Nearby drivers
    _subscriptions.add(
      _socketService.nearbyDriversStream.listen((data) {
        debugPrint('👥 Nearby drivers: $data');
        
        final drivers = data['drivers'] as List<dynamic>? ?? [];
        
        state = state.copyWith(
          nearbyDrivers: drivers.map((d) => d as Map<String, dynamic>).toList(),
        );
      })
    );

    // Ride cancelled confirmation
    _subscriptions.add(
      _socketService.rideCancelledConfirmationStream.listen((data) {
        debugPrint('✅ Ride cancellation confirmed: $data');
        
        state = state.copyWith(
          status: 'cancelled',
          isSearching: false,
          lastEvent: data,
        );
      })
    );
  }

  /// Initialize socket connection
  Future<void> initialize({
    required String passengerId,
    required String name,
    required String phone,
    String? image,
  }) async {
    await _socketService.initialize();
    await _socketService.connectPassenger(
      passengerId: passengerId,
      name: name,
      phone: phone,
      image: image,
    );
  }

  /// Request a ride
  Future<void> requestRide({
    required String passengerId,
    required String passengerName,
    required String passengerPhone,
    String? passengerImage,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationAddress,
    String? notes,
    double? fare,
  }) async {
    // Create initial ride object
    final ride = Ride(
      id: 'pending',
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      passengerImage: passengerImage,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupAddress: pickupAddress,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      destinationAddress: destinationAddress,
      notes: notes,
      fare: fare?.toString(),
      status: 'requesting',
      requestedAt: DateTime.now(),
    );

    state = state.copyWith(
      currentRide: ride,
      status: 'requesting',
      isSearching: true,
      errorMessage: null,
    );

    await _socketService.requestRide(
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      passengerImage: passengerImage,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupAddress: pickupAddress,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      destinationAddress: destinationAddress,
      notes: notes,
      fare: fare,
      distance: 0,
      duration: 0,
    );
  }

  /// Cancel current ride
  Future<void> cancelRide({String? reason}) async {
    if (state.currentRide != null) {
      await _socketService.cancelRide(
        rideId: state.currentRide!.id,
        passengerId: state.currentRide!.passengerId,
        reason: reason,
      );
    }
  }

  /// Rate the driver
  Future<void> rateDriver({
    required int rating,
    String? feedback,
  }) async {
    if (state.currentRide != null) {
      await _socketService.rateDriver(
        rideId: state.currentRide!.id,
        rating: rating,
        feedback: feedback,
      );

      state = state.copyWith(
        currentRide: state.currentRide!.copyWith(
          rating: rating,
          feedback: feedback,
        ),
      );
    }
  }

  /// Get nearby drivers
  Future<void> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double? radius,
  }) async {
    await _socketService.getNearbyDrivers(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    );
  }

  /// Clear error message
  void clearError() {
    state = state.clearError();
  }

  /// Reset ride state
  void reset() {
    state = state.clearRide();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

/// Socket ride provider
final socketRideProvider = StateNotifierProvider<SocketRideNotifier, SocketRideState>((ref) {
  final socketService = ref.watch(socketServiceProvider);
  return SocketRideNotifier(socketService);
});

/// Helper providers for specific ride states
final isRideActiveProvider = Provider<bool>((ref) {
  final rideState = ref.watch(socketRideProvider);
  return rideState.status == 'accepted' || 
         rideState.status == 'started' ||
         rideState.isSearching;
});

final currentDriverLocationProvider = Provider<Map<String, double>?>((ref) {
  final rideState = ref.watch(socketRideProvider);
  final ride = rideState.currentRide;
  
  if (ride != null && ride.driverLatitude != null && ride.driverLongitude != null) {
    return {
      'lat': ride.driverLatitude!,
      'lng': ride.driverLongitude!,
    };
  }
  
  return null;
});

final shouldShowRatingProvider = Provider<bool>((ref) {
  final rideState = ref.watch(socketRideProvider);
  return rideState.status == 'completed' && rideState.currentRide?.rating == null;
});
