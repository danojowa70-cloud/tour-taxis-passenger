import 'package:flutter_riverpod/flutter_riverpod.dart';

class RideFlowState {
  final String? pickup;
  final String? destination;
  final double? estimatedFare;
  final Map<String, double>? pickupLatLng;      // {lat, lng}
  final Map<String, double>? destinationLatLng; // {lat, lng}
  final double? distanceMeters;
  final double? durationSeconds;
  final List<List<double>>? polyline;
  final String? rideId;
  final String? vehicleType; // Selected vehicle type from home screen
  const RideFlowState({this.pickup, this.destination, this.estimatedFare, this.pickupLatLng, this.destinationLatLng, this.distanceMeters, this.durationSeconds, this.polyline, this.rideId, this.vehicleType});

  RideFlowState copyWith({String? pickup, String? destination, double? estimatedFare, Map<String, double>? pickupLatLng, Map<String, double>? destinationLatLng, double? distanceMeters, double? durationSeconds, List<List<double>>? polyline, String? rideId, String? vehicleType}) {
    return RideFlowState(
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      pickupLatLng: pickupLatLng ?? this.pickupLatLng,
      destinationLatLng: destinationLatLng ?? this.destinationLatLng,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      polyline: polyline ?? this.polyline,
      rideId: rideId ?? this.rideId,
      vehicleType: vehicleType ?? this.vehicleType,
    );
  }
}

class RideFlowNotifier extends StateNotifier<RideFlowState> {
  RideFlowNotifier() : super(const RideFlowState());

  void setPickup(String value) => state = state.copyWith(pickup: value);
  void setDestination(String value) => state = state.copyWith(destination: value);
  void estimateFare() {
    if (state.pickup != null && state.destination != null) {
      state = state.copyWith(estimatedFare: 12.5);
    }
  }
  void reset() => state = const RideFlowState();
  
  // Force clear all ride state including ride ID
  void clearAll() {
    state = const RideFlowState();
  }

  void updateFrom({
    String? pickup,
    String? destination,
    double? estimatedFare,
    Map<String, double>? pickupLatLng,
    Map<String, double>? destinationLatLng,
    double? distanceMeters,
    double? durationSeconds,
    List<List<double>>? polyline,
    String? vehicleType,
  }) {
    state = state.copyWith(
      pickup: pickup,
      destination: destination,
      estimatedFare: estimatedFare,
      pickupLatLng: pickupLatLng,
      destinationLatLng: destinationLatLng,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      polyline: polyline,
      vehicleType: vehicleType,
    );
  }

  void setRideId(String rideId) {
    state = state.copyWith(rideId: rideId);
  }
}

final rideFlowProvider = StateNotifierProvider<RideFlowNotifier, RideFlowState>((ref) => RideFlowNotifier());


