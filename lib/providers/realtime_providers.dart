import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ride_service.dart';

// Provider for ride service
final rideServiceProvider = Provider<RideService>((ref) {
  return RideService(Supabase.instance.client);
});

// Provider for current ride ID
final currentRideIdProvider = StateProvider<String?>((ref) => null);

// Provider for nearby drivers
final nearbyDriversProvider = FutureProvider.family<List<Map<String, dynamic>>, Map<String, double>>((ref, location) async {
  final rideService = ref.read(rideServiceProvider);
  return rideService.getNearbyDrivers(
    location['lat']!,
    location['lng']!,
    radiusKm: location['radius'] ?? 5.0,
  );
});

// Provider for ride status stream
final rideStatusStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, rideId) {
  final rideService = ref.read(rideServiceProvider);
  return rideService.subscribeToRideStatus(rideId);
});

// Provider for ride events stream
final rideEventsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, rideId) {
  final rideService = ref.read(rideServiceProvider);
  return rideService.subscribeToRideEvents(rideId);
});

// Provider for current ride status
final currentRideStatusProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// Provider for driver search status
final driverSearchStatusProvider = StateProvider<String>((ref) => 'idle'); // idle, searching, found, no_drivers

// Provider for assigned driver
final assignedDriverProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// Real-time ride management state
class RideRealtimeState {
  final String? rideId;
  final String status; // requested, driver_found, accepted, started, completed, cancelled
  final Map<String, dynamic>? driver;
  final List<Map<String, dynamic>> events;
  final bool isSearching;
  final String? errorMessage;

  RideRealtimeState({
    this.rideId,
    this.status = 'idle',
    this.driver,
    this.events = const [],
    this.isSearching = false,
    this.errorMessage,
  });

  RideRealtimeState copyWith({
    String? rideId,
    String? status,
    Map<String, dynamic>? driver,
    List<Map<String, dynamic>>? events,
    bool? isSearching,
    String? errorMessage,
  }) {
    return RideRealtimeState(
      rideId: rideId ?? this.rideId,
      status: status ?? this.status,
      driver: driver ?? this.driver,
      events: events ?? this.events,
      isSearching: isSearching ?? this.isSearching,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Real-time ride state notifier
class RideRealtimeNotifier extends StateNotifier<RideRealtimeState> {
  final RideService _rideService;
  
  RideRealtimeNotifier(this._rideService) : super(RideRealtimeState());

  void setRideId(String rideId) {
    state = state.copyWith(rideId: rideId, status: 'requested', isSearching: true);
    _subscribeToRideUpdates(rideId);
  }

  void _subscribeToRideUpdates(String rideId) {
    // Subscribe to ride status changes
    _rideService.subscribeToRideStatus(rideId).listen(
      (rideDataList) {
        if (rideDataList.isNotEmpty) {
          final rideData = rideDataList.first;
          final rideStatus = rideData['status'] as String;
          Map<String, dynamic>? driver;
          
          if (rideData['driver_id'] != null) {
            // If there's a driver assigned, we should fetch driver details
            // For now, we'll create a basic driver object
            driver = {
              'id': rideData['driver_id'],
              'name': 'Alex Johnson', // This should be fetched from drivers table
              'phone': '+32456789012',
              'vehicle_type': 'Tesla Model 3',
              'vehicle_number': '1-ABC-123',
              'rating': 4.8,
            };
          }

          state = state.copyWith(
            status: rideStatus,
            driver: driver,
            isSearching: rideStatus == 'requested',
          );
        }
      },
      onError: (error) {
        state = state.copyWith(
          errorMessage: error.toString(),
          isSearching: false,
        );
      },
    );

    // Subscribe to ride events
    _rideService.subscribeToRideEvents(rideId).listen(
      (eventList) {
        if (eventList.isNotEmpty) {
          // Process new events
          for (final event in eventList) {
            final currentEvents = List<Map<String, dynamic>>.from(state.events);
            
            // Check if we already have this event to avoid duplicates
            final eventId = event['id'];
            final eventExists = currentEvents.any((e) => e['id'] == eventId);
            
            if (!eventExists) {
              currentEvents.add(event);
              
              // Handle specific event types
              final eventType = event['event_type'] as String;
              switch (eventType) {
                case 'ride:drivers_found':
                  state = state.copyWith(
                    events: currentEvents,
                    status: 'drivers_found',
                    isSearching: true,
                  );
                  break;
                case 'ride:no_drivers':
                  state = state.copyWith(
                    events: currentEvents,
                    status: 'no_drivers',
                    isSearching: false,
                    errorMessage: 'No drivers available in your area',
                  );
                  break;
                case 'ride:driver_accepted':
                  final payload = event['payload'] as Map<String, dynamic>?;
                  if (payload != null && payload.containsKey('driver_data')) {
                    state = state.copyWith(
                      events: currentEvents,
                      status: 'accepted',
                      driver: payload['driver_data'],
                      isSearching: false,
                    );
                  }
                  break;
                case 'ride:started':
                  state = state.copyWith(
                    events: currentEvents,
                    status: 'started',
                    isSearching: false,
                  );
                  break;
                case 'ride:completed':
                  state = state.copyWith(
                    events: currentEvents,
                    status: 'completed',
                    isSearching: false,
                  );
                  break;
                case 'ride:cancel':
                  state = state.copyWith(
                    events: currentEvents,
                    status: 'cancelled',
                    isSearching: false,
                  );
                  break;
                default:
                  state = state.copyWith(events: currentEvents);
              }
            }
          }
        }
      },
      onError: (error) {
        state = state.copyWith(
          errorMessage: error.toString(),
          isSearching: false,
        );
      },
    );
  }

  void clearRide() {
    state = RideRealtimeState();
  }

  Future<void> cancelRide({String? reason}) async {
    if (state.rideId != null) {
      await _rideService.cancelRide(rideId: state.rideId!, reason: reason);
    }
  }
}

// Provider for ride realtime state
final rideRealtimeProvider = StateNotifierProvider<RideRealtimeNotifier, RideRealtimeState>((ref) {
  final rideService = ref.read(rideServiceProvider);
  return RideRealtimeNotifier(rideService);
});