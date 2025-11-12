import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Comprehensive Socket.IO service for passenger app
/// Implements all events according to the new server specification
class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();
  
  SocketService._();

  // Server URL
  static const String _serverUrl = 'https://tourtaxi-unified-backend.onrender.com';
  
  io.Socket? _socket;
  bool _isConnected = false;
  
  // Stored passenger info for re-emitting on reconnect
  String? _passengerId;
  String? _passengerName;
  String? _passengerPhone;
  String? _passengerImage;
  
  // Stream controllers for events
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _rideRequestSubmittedController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideCompletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationController = StreamController<Map<String, dynamic>>.broadcast();
  final _noDriversAvailableController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideTimeoutController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();
  final _nearbyDriversController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideHistoryController = StreamController<Map<String, dynamic>>.broadcast();
  final _ratingSubmittedController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideCancelledConfirmationController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideOtpController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  bool get isConnected => _isConnected;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get rideRequestSubmittedStream => _rideRequestSubmittedController.stream;
  Stream<Map<String, dynamic>> get rideAcceptedStream => _rideAcceptedController.stream;
  Stream<Map<String, dynamic>> get rideStartedStream => _rideStartedController.stream;
  Stream<Map<String, dynamic>> get rideCompletedStream => _rideCompletedController.stream;
  Stream<Map<String, dynamic>> get rideCancelledStream => _rideCancelledController.stream;
  Stream<Map<String, dynamic>> get driverLocationStream => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get noDriversAvailableStream => _noDriversAvailableController.stream;
  Stream<Map<String, dynamic>> get rideTimeoutStream => _rideTimeoutController.stream;
  Stream<Map<String, dynamic>> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get nearbyDriversStream => _nearbyDriversController.stream;
  Stream<Map<String, dynamic>> get rideHistoryStream => _rideHistoryController.stream;
  Stream<Map<String, dynamic>> get ratingSubmittedStream => _ratingSubmittedController.stream;
  Stream<Map<String, dynamic>> get rideCancelledConfirmationStream => _rideCancelledConfirmationController.stream;
  Stream<Map<String, dynamic>> get rideOtpStream => _rideOtpController.stream;

  /// Initialize and connect to the Socket.IO server
  Future<void> initialize() async {
    if (_socket != null && _isConnected) {
      debugPrint('🔌 Socket.IO already connected');
      return;
    }

    try {
      debugPrint('🔌 Initializing Socket.IO connection to: $_serverUrl');
      
      _socket = io.io(_serverUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(0) // infinite
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setTimeout(60000)
        .build()
      );

      _setupEventListeners();
      _socket?.connect();
      
    } catch (e) {
      debugPrint('⚠️ Socket.IO initialization error: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  /// Set up all event listeners
  void _setupEventListeners() {
    // Connection events
    _socket?.onConnect((_) {
      _isConnected = true;
      _connectionStatusController.add(true);
      debugPrint('✅ Socket.IO connected successfully (id: ${_socket?.id})');
      _emitConnectPassengerIfReady();
    });

    _socket?.onDisconnect((_) {
      _isConnected = false;
      _connectionStatusController.add(false);
      debugPrint('❌ Socket.IO disconnected');
    });

    _socket?.onConnectError((error) {
      _isConnected = false;
      _connectionStatusController.add(false);
      debugPrint('⚠️ Socket.IO connection error: $error');
      _errorController.add({
        'message': 'Connection error',
        'error': error.toString(),
      });
    });

    _socket?.onError((error) {
      debugPrint('⚠️ Socket.IO error: $error');
      _errorController.add({
        'message': 'Socket error',
        'error': error.toString(),
      });
    });

    // Passenger connection confirmation
    _socket?.on('passenger_connected', (data) {
      debugPrint('✅ Passenger connected confirmation: $data');
    });

    // Ride request events
    _socket?.on('ride_request_submitted', (data) {
      debugPrint('📝 Ride request submitted: $data');
      if (data is Map<String, dynamic>) {
        _rideRequestSubmittedController.add(data);
      }
    });

    _socket?.on('ride_accepted', (data) {
      debugPrint('🎉 Ride accepted event: $data');
      if (data is Map<String, dynamic>) {
        _rideAcceptedController.add(data);
      }
    });
    
    // Also listen for ride_accept (in case backend uses different event name)
    _socket?.on('ride_accept', (data) {
      debugPrint('🎉 Ride accept event (driver emitted): $data');
      if (data is Map<String, dynamic>) {
        _rideAcceptedController.add(data);
      }
    });
    
    // Listen for ride_accepted_confirmation from backend
    _socket?.on('ride_accepted_confirmation', (data) {
      debugPrint('🎉 Ride accepted confirmation from backend: $data');
      if (data is Map<String, dynamic>) {
        _rideAcceptedController.add(data);
      }
    });

    _socket?.on('ride_started', (data) {
      debugPrint('🚗 Ride started event: $data');
      if (data is Map<String, dynamic>) {
        _rideStartedController.add(data);
      }
    });
    
    // Also listen for ride_start (in case backend uses different event name)
    _socket?.on('ride_start', (data) {
      debugPrint('🚗 Ride start event (driver emitted): $data');
      if (data is Map<String, dynamic>) {
        _rideStartedController.add(data);
      }
    });
    
    // Listen for ride_started_confirmation from backend
    _socket?.on('ride_started_confirmation', (data) {
      debugPrint('🚗 Ride started confirmation from backend: $data');
      if (data is Map<String, dynamic>) {
        _rideStartedController.add(data);
      }
    });

    _socket?.on('ride_completed', (data) {
      debugPrint('🏁 Ride completed: $data');
      if (data is Map<String, dynamic>) {
        _rideCompletedController.add(data);
      }
    });

    _socket?.on('ride_cancelled', (data) {
      debugPrint('❌ Ride cancelled: $data');
      if (data is Map<String, dynamic>) {
        _rideCancelledController.add(data);
      }
    });

    _socket?.on('ride_driver_location', (data) {
      debugPrint('📍 Driver location update: $data');
      if (data is Map<String, dynamic>) {
        _driverLocationController.add(data);
      }
    });

    _socket?.on('no_drivers_available', (data) {
      debugPrint('🚫 No drivers available: $data');
      if (data is Map<String, dynamic>) {
        _noDriversAvailableController.add(data);
      }
    });

    _socket?.on('ride_timeout', (data) {
      debugPrint('⏰ Ride timeout: $data');
      if (data is Map<String, dynamic>) {
        _rideTimeoutController.add(data);
      }
    });

    _socket?.on('nearby_drivers', (data) {
      debugPrint('👥 Nearby drivers: $data');
      if (data is Map<String, dynamic>) {
        _nearbyDriversController.add(data);
      }
    });

    _socket?.on('ride_history', (data) {
      debugPrint('📜 Ride history: $data');
      if (data is Map<String, dynamic>) {
        _rideHistoryController.add(data);
      }
    });

    _socket?.on('rating_submitted', (data) {
      debugPrint('⭐ Rating submitted: $data');
      if (data is Map<String, dynamic>) {
        _ratingSubmittedController.add(data);
      }
    });

    _socket?.on('ride_cancelled_confirmation', (data) {
      debugPrint('✅ Ride cancelled confirmation: $data');
      if (data is Map<String, dynamic>) {
        _rideCancelledConfirmationController.add(data);
      }
    });
    
    // Listen for OTP event
    _socket?.on('ride_otp', (data) {
      debugPrint('🔐 Ride OTP received: $data');
      if (data is Map<String, dynamic>) {
        _rideOtpController.add(data);
      }
    });

    _socket?.on('error', (data) {
      debugPrint('❌ Server error: $data');
      if (data is Map<String, dynamic>) {
        _errorController.add(data);
      } else if (data is String) {
        _errorController.add({'message': data});
      }
    });
    
    // Catch-all event listener for debugging
    _socket?.onAny((event, data) {
      debugPrint('🎯 Socket event received: $event');
      debugPrint('📦 Event data: $data');
    });
  }

  void _emitConnectPassengerIfReady() {
    if (_socket == null || !_isConnected) return;
    if (_passengerId == null || _passengerName == null || _passengerPhone == null) return;

    final payload = {
      'passenger_id': _passengerId,
      'name': _passengerName,
      'phone': _passengerPhone,
      if (_passengerImage != null) 'image': _passengerImage,
    };
    debugPrint('👤 Emitting connect_passenger: $payload');
    _socket?.emit('connect_passenger', payload);
  }

  /// Connect passenger - emit on app start
  Future<void> connectPassenger({
    required String passengerId,
    required String name,
    required String phone,
    String? image,
  }) async {
    // Save for re-emit on reconnect
    _passengerId = passengerId;
    _passengerName = name;
    _passengerPhone = phone;
    _passengerImage = image;

    if (!_isConnected || _socket == null) {
      await initialize();
      // Give the socket a brief moment to connect, then emit
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot connect passenger');
      return;
    }

    _emitConnectPassengerIfReady();
  }

  /// Request a ride
  Future<void> requestRide({
    required String passengerId,
    required String passengerName,
    required String passengerPhone,
    String? passengerEmail, // Add email parameter
    String? passengerImage,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationAddress,
    String? notes,
    double? fare,
    String? rideId,
    double? distance,
    int? duration,
    String? vehicleType, // Vehicle type selection: 'car', 'suv', 'bike'
  }) async {
    // Auto-initialize if not connected
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, attempting to initialize...');
      await initialize();
      
      // Wait up to 5 seconds for connection
      int attempts = 0;
      while (!_isConnected && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        debugPrint('🔄 Waiting for socket connection... (attempt $attempts/10)');
      }
      
      // If still not connected after waiting, show error
      if (!_isConnected || _socket == null) {
        debugPrint('❌ Socket.IO connection timeout');
        _errorController.add({
          'message': 'Not connected to server',
          'error': 'Please check your internet connection',
        });
        return;
      }
    }

    // Validate required fields
    if (passengerPhone.isEmpty) {
      debugPrint('⚠️ ERROR: passenger_phone is empty!');
      _errorController.add({
        'message': 'Missing passenger phone number',
        'error': 'VALIDATION_ERROR',
      });
      return;
    }
    
    final payload = <String, dynamic>{
      // Passenger info - REQUIRED by RideRequestSchema
      'passenger_id': passengerId,
      'passenger_name': passengerName,
      'passenger_phone': passengerPhone,
      if (passengerEmail != null && passengerEmail.isNotEmpty) 'passenger_email': passengerEmail,
      if (passengerImage != null && passengerImage.isNotEmpty) 'passenger_image': passengerImage,
      
      // Pickup location - REQUIRED
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'pickup_address': pickupAddress,
      
      // Destination location - REQUIRED
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'destination_address': destinationAddress,
      
      // Trip details - Backend will recalculate but we send our values
      if (distance != null && distance > 0) 'distance': distance,
      if (duration != null && duration > 0) 'duration': duration,
      if (fare != null && fare > 0) 'fare': fare,
      
      // Status and timestamp
      'status': 'requested',
      'requested_at': DateTime.now().toIso8601String(),
      
      // Vehicle type for driver matching - IMPORTANT for filtering
      if (vehicleType != null && vehicleType.isNotEmpty) 'vehicle_type': vehicleType,
      
      // Optional notes
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    debugPrint('🚗 emit ride_request $payload');
    _socket?.emit('ride_request', payload);
  }

  /// Cancel a ride
  Future<void> cancelRide({
    required String rideId,
    required String passengerId,
    String? reason,
  }) async {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot cancel ride');
      return;
    }

    final payload = {
      'ride_id': rideId,
      'passenger_id': passengerId,
      if (reason != null) 'reason': reason,
    };

    debugPrint('❌ Cancelling ride: $payload');
    _socket?.emit('ride_cancel', payload);
  }

  /// Rate a driver
  Future<void> rateDriver({
    required String rideId,
    required int rating,
    String? feedback,
  }) async {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot rate driver');
      return;
    }

    final payload = {
      'ride_id': rideId,
      'rating': rating,
      if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
    };

    debugPrint('⭐ Rating driver: $payload');
    _socket?.emit('ride_rating', payload);
  }

  /// Get nearby drivers
  /// radius: search radius in meters (e.g., 5000 = 5km)
  Future<void> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double? radius,
  }) async {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot get nearby drivers');
      return;
    }

    final payload = {
      'latitude': latitude,
      'longitude': longitude,
      if (radius != null) 'radius': radius,
    };

    debugPrint('👥 Getting nearby drivers: $payload');
    _socket?.emit('get_nearby_drivers', payload);
  }

  /// Get ride history
  Future<void> getRideHistory({
    required String passengerId,
    int? limit,
  }) async {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot get ride history');
      return;
    }

    final payload = {
      'passenger_id': passengerId,
      if (limit != null) 'limit': limit,
    };

    debugPrint('📜 Getting ride history: $payload');
    _socket?.emit('get_ride_history', payload);
  }

  /// Disconnect from the Socket.IO server
  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _isConnected = false;
      _connectionStatusController.add(false);
      debugPrint('🔌 Socket.IO disconnected');
    } catch (e) {
      debugPrint('⚠️ Socket.IO disconnect error: $e');
    }
  }

  /// Dispose all stream controllers
  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _rideRequestSubmittedController.close();
    _rideAcceptedController.close();
    _rideStartedController.close();
    _rideCompletedController.close();
    _rideCancelledController.close();
    _driverLocationController.close();
    _noDriversAvailableController.close();
    _rideTimeoutController.close();
    _errorController.close();
    _nearbyDriversController.close();
    _rideHistoryController.close();
    _ratingSubmittedController.close();
    _rideCancelledConfirmationController.close();
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use connectPassenger instead')
  Future<void> connect({String? passengerId}) async {
    await initialize();
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use requestRide instead')
  void emit(String event, Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot emit $event');
      return;
    }
    debugPrint('📤 Emitting $event: $data');
    _socket?.emit(event, data);
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use specific stream listeners instead')
  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }
}