import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();
  
  SocketService._();

  // Production backend URL - your deployed Render backend
  static const String _serverUrl = 'https://tourtaxi-unified-backend.onrender.com';
  
  io.Socket? _socket;
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;

  /// Initialize and connect to the backend Socket.IO server
  Future<void> connect({String? passengerId}) async {
    try {
      debugPrint('🔌 Connecting to Socket.IO server: $_serverUrl');
      
      _socket = io.io(_serverUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .enableForceNew()
        .setTimeout(5000)
        .setExtraHeaders({
          'passenger-id': passengerId ?? 'anonymous',
          'client-type': 'passenger-app',
        })
        .build()
      );

      _socket?.onConnect((_) {
        _isConnected = true;
        debugPrint('✅ Socket.IO connected successfully');
        
        // Join passenger room for personalized updates
        if (passengerId != null) {
          _socket?.emit('join-passenger-room', {'passengerId': passengerId});
        }
      });

      _socket?.onDisconnect((_) {
        _isConnected = false;
        debugPrint('❌ Socket.IO disconnected');
      });

      _socket?.onConnectError((error) {
        _isConnected = false;
        debugPrint('⚠️ Socket.IO connection error: $error');
      });

      _socket?.onError((error) {
        debugPrint('⚠️ Socket.IO error: $error');
      });

      _socket?.connect();
      
    } catch (e) {
      debugPrint('⚠️ Socket.IO initialization error: $e');
      _isConnected = false;
    }
  }

  /// Disconnect from the Socket.IO server
  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _isConnected = false;
      debugPrint('🔌 Socket.IO disconnected');
    } catch (e) {
      debugPrint('⚠️ Socket.IO disconnect error: $e');
    }
  }

  /// Send a ride request to the backend
  void requestRide({
    required String passengerId,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> destination,
    String? vehicleType,
    Map<String, dynamic>? additionalData,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot send ride request');
      return;
    }

    final data = {
      'passengerId': passengerId,
      'pickup': pickup,
      'destination': destination,
      'vehicleType': vehicleType ?? 'sedan',
      'timestamp': DateTime.now().toIso8601String(),
      ...?additionalData,
    };

    debugPrint('🚗 Sending ride request: $data');
    _socket?.emit('ride:request', data);
  }

  /// Listen for ride acceptance from drivers
  void onRideAccepted(Function(Map<String, dynamic>) callback) {
    _socket?.on('ride:accepted', (data) {
      debugPrint('✅ Ride accepted: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  /// Listen for ride updates (driver location, status changes)
  void onRideUpdate(Function(Map<String, dynamic>) callback) {
    _socket?.on('ride:update', (data) {
      debugPrint('📍 Ride update: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  /// Listen for ride completion
  void onRideEnd(Function(Map<String, dynamic>) callback) {
    _socket?.on('ride:end', (data) {
      debugPrint('🏁 Ride ended: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  /// Listen for fare information
  void onRideFare(Function(Map<String, dynamic>) callback) {
    _socket?.on('ride:fare', (data) {
      debugPrint('💰 Ride fare: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  /// Listen for ride cancellation
  void onRideCancelled(Function(Map<String, dynamic>) callback) {
    _socket?.on('ride:cancelled', (data) {
      debugPrint('❌ Ride cancelled: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  /// Listen for driver not found
  void onNoDriverFound(Function(Map<String, dynamic>) callback) {
    _socket?.on('ride:no-driver', (data) {
      debugPrint('🚫 No driver found: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  /// Send ride cancellation
  void cancelRide({
    required String rideId,
    required String passengerId,
    String? reason,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot cancel ride');
      return;
    }

    final data = {
      'rideId': rideId,
      'passengerId': passengerId,
      'reason': reason ?? 'Passenger cancelled',
      'timestamp': DateTime.now().toIso8601String(),
    };

    debugPrint('❌ Cancelling ride: $data');
    _socket?.emit('ride:cancel', data);
  }

  /// Send payment confirmation
  void confirmPayment({
    required String rideId,
    required String passengerId,
    required double amount,
    required String method,
    Map<String, dynamic>? paymentData,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot confirm payment');
      return;
    }

    final data = {
      'rideId': rideId,
      'passengerId': passengerId,
      'amount': amount,
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
      ...?paymentData,
    };

    debugPrint('💳 Confirming payment: $data');
    _socket?.emit('payment:confirm', data);
  }

  /// Listen for general notifications
  void onNotification(Function(Map<String, dynamic>) callback) {
    _socket?.on('notification', (data) {
      debugPrint('🔔 Notification: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  /// Remove all listeners (call when disposing the service)
  void removeAllListeners() {
    _socket?.clearListeners();
  }

  /// Get connection status
  bool get connectionStatus => _isConnected;

  /// Manually emit any custom event
  void emit(String event, Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Socket.IO not connected, cannot emit $event');
      return;
    }

    debugPrint('📤 Emitting $event: $data');
    _socket?.emit(event, data);
  }

  /// Manually listen for any custom event
  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }
}