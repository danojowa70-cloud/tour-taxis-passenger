import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/backend_api_service.dart';
import '../services/socket_service.dart';
import 'auth_providers.dart';

// Provider for backend API service
final backendApiServiceProvider = Provider<BackendApiService>((ref) {
  return BackendApiService();
});

// Provider for Socket.IO service
final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService.instance;
});

// Provider for backend health status
final backendHealthProvider = FutureProvider<bool>((ref) async {
  return await BackendApiService.healthCheck();
});

// Provider for backend connection status
final backendConnectionStatusProvider = StateProvider<String>((ref) => 'disconnected'); 
// States: 'disconnected', 'connecting', 'connected', 'error'

// Provider for real-time ride updates via Socket.IO
class SocketRideState {
  final bool isConnected;
  final String? currentRideId;
  final Map<String, dynamic>? rideData;
  final List<Map<String, dynamic>> rideUpdates;
  final String? driverInfo;
  final String status; // 'idle', 'requesting', 'matched', 'in_progress', 'completed', 'cancelled'
  final String? errorMessage;

  const SocketRideState({
    this.isConnected = false,
    this.currentRideId,
    this.rideData,
    this.rideUpdates = const [],
    this.driverInfo,
    this.status = 'idle',
    this.errorMessage,
  });

  SocketRideState copyWith({
    bool? isConnected,
    String? currentRideId,
    Map<String, dynamic>? rideData,
    List<Map<String, dynamic>>? rideUpdates,
    String? driverInfo,
    String? status,
    String? errorMessage,
  }) {
    return SocketRideState(
      isConnected: isConnected ?? this.isConnected,
      currentRideId: currentRideId ?? this.currentRideId,
      rideData: rideData ?? this.rideData,
      rideUpdates: rideUpdates ?? this.rideUpdates,
      driverInfo: driverInfo ?? this.driverInfo,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Socket ride state notifier
class SocketRideNotifier extends StateNotifier<SocketRideState> {
  final SocketService _socketService;
  final Ref _ref;

  SocketRideNotifier(this._socketService, this._ref) : super(const SocketRideState()) {
    _initializeSocketListeners();
  }

  void _initializeSocketListeners() {
    // Listen for ride acceptance
    _socketService.onRideAccepted((data) {
      debugPrint('🚗 Ride accepted via Socket: $data');
      state = state.copyWith(
        status: 'matched',
        rideData: data,
        driverInfo: data['driver']?.toString(),
        currentRideId: data['rideId']?.toString(),
      );
    });

    // Listen for ride updates
    _socketService.onRideUpdate((data) {
      debugPrint('📍 Ride update via Socket: $data');
      final currentUpdates = List<Map<String, dynamic>>.from(state.rideUpdates);
      currentUpdates.add({
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      });
      
      state = state.copyWith(
        rideUpdates: currentUpdates,
        rideData: data,
      );
    });

    // Listen for ride completion
    _socketService.onRideEnd((data) {
      debugPrint('🏁 Ride completed via Socket: $data');
      state = state.copyWith(
        status: 'completed',
        rideData: data,
      );
    });

    // Listen for ride cancellation
    _socketService.onRideCancelled((data) {
      debugPrint('❌ Ride cancelled via Socket: $data');
      state = state.copyWith(
        status: 'cancelled',
        rideData: data,
        errorMessage: data['reason']?.toString(),
      );
    });

    // Listen for no driver found
    _socketService.onNoDriverFound((data) {
      debugPrint('🚫 No driver found via Socket: $data');
      state = state.copyWith(
        status: 'idle',
        errorMessage: 'No drivers available in your area',
      );
    });

    // Listen for fare information
    _socketService.onRideFare((data) {
      debugPrint('💰 Ride fare via Socket: $data');
      final updatedRideData = Map<String, dynamic>.from(state.rideData ?? {});
      updatedRideData.addAll(data);
      
      state = state.copyWith(
        rideData: updatedRideData,
      );
    });

    // Listen for general notifications
    _socketService.onNotification((data) {
      debugPrint('🔔 Notification via Socket: $data');
      // Handle general notifications
    });
  }

  // Connect to the backend Socket.IO server
  Future<void> connectToBackend() async {
    final currentUser = _ref.read(currentUserProvider);
    final passengerId = currentUser?.id;

    state = state.copyWith(isConnected: false, errorMessage: null);
    _ref.read(backendConnectionStatusProvider.notifier).state = 'connecting';

    try {
      await _socketService.connect(passengerId: passengerId);
      state = state.copyWith(isConnected: true);
      _ref.read(backendConnectionStatusProvider.notifier).state = 'connected';
      debugPrint('✅ Backend Socket.IO connected');
    } catch (e) {
      state = state.copyWith(
        isConnected: false,
        errorMessage: e.toString(),
      );
      _ref.read(backendConnectionStatusProvider.notifier).state = 'error';
      debugPrint('❌ Backend Socket.IO connection failed: $e');
    }
  }

  // Disconnect from the backend
  void disconnectFromBackend() {
    _socketService.disconnect();
    state = state.copyWith(isConnected: false);
    _ref.read(backendConnectionStatusProvider.notifier).state = 'disconnected';
    debugPrint('🔌 Backend Socket.IO disconnected');
  }

  // Request a ride via Socket.IO
  void requestRideViaSocket({
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> destination,
    String? vehicleType,
    Map<String, dynamic>? additionalData,
  }) {
    final currentUser = _ref.read(currentUserProvider);
    final passengerId = currentUser?.id;

    if (passengerId == null) {
      state = state.copyWith(errorMessage: 'User not authenticated');
      return;
    }

    if (!state.isConnected) {
      state = state.copyWith(errorMessage: 'Not connected to backend');
      return;
    }

    state = state.copyWith(
      status: 'requesting',
      errorMessage: null,
      rideUpdates: [],
    );

    _socketService.requestRide(
      passengerId: passengerId,
      pickup: pickup,
      destination: destination,
      vehicleType: vehicleType,
      additionalData: additionalData,
    );

    debugPrint('🚗 Ride requested via Socket.IO');
  }

  // Cancel current ride
  void cancelCurrentRide({String? reason}) {
    if (state.currentRideId == null) {
      debugPrint('⚠️ No current ride to cancel');
      return;
    }

    final currentUser = _ref.read(currentUserProvider);
    final passengerId = currentUser?.id;

    if (passengerId == null) {
      state = state.copyWith(errorMessage: 'User not authenticated');
      return;
    }

    _socketService.cancelRide(
      rideId: state.currentRideId!,
      passengerId: passengerId,
      reason: reason,
    );

    state = state.copyWith(
      status: 'cancelled',
      errorMessage: reason,
    );
  }

  // Confirm payment via Socket.IO
  void confirmPaymentViaSocket({
    required double amount,
    required String method,
    Map<String, dynamic>? paymentData,
  }) {
    if (state.currentRideId == null) {
      debugPrint('⚠️ No current ride for payment');
      return;
    }

    final currentUser = _ref.read(currentUserProvider);
    final passengerId = currentUser?.id;

    if (passengerId == null) {
      state = state.copyWith(errorMessage: 'User not authenticated');
      return;
    }

    _socketService.confirmPayment(
      rideId: state.currentRideId!,
      passengerId: passengerId,
      amount: amount,
      method: method,
      paymentData: paymentData,
    );
  }

  // Clear current ride state
  void clearRideState() {
    state = SocketRideState(isConnected: state.isConnected);
  }

  @override
  void dispose() {
    _socketService.removeAllListeners();
    _socketService.disconnect();
    super.dispose();
  }
}

// Provider for socket ride state
final socketRideProvider = StateNotifierProvider<SocketRideNotifier, SocketRideState>((ref) {
  final socketService = ref.read(socketServiceProvider);
  return SocketRideNotifier(socketService, ref);
});

// Provider for ride history via backend API
final rideHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final currentUser = ref.read(currentUserProvider);
  if (currentUser?.id == null) return [];

  try {
    return await BackendApiService.getRideHistory(currentUser!.id);
  } catch (e) {
    debugPrint('⚠️ Failed to fetch ride history: $e');
    return [];
  }
});

// Provider for backend API info
final backendApiInfoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    return await BackendApiService.getApiInfo();
  } catch (e) {
    debugPrint('⚠️ Failed to fetch API info: $e');
    return null;
  }
});