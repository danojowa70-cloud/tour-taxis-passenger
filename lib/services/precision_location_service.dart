import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// High-precision location service with advanced accuracy controls
class PrecisionLocationService {
  static final PrecisionLocationService _instance = PrecisionLocationService._internal();
  factory PrecisionLocationService() => _instance;
  PrecisionLocationService._internal();

  // Location stream controllers
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();
  final StreamController<LocationServiceStatus> _serviceStatusController = StreamController<LocationServiceStatus>.broadcast();
  
  // Current state
  Position? _lastKnownPosition;
  LocationServiceStatus _serviceStatus = LocationServiceStatus.disabled;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  
  // Accuracy settings
  static const double _accuracyThreshold = 10.0; // meters
  static const int _maxLocationAge = 30000; // 30 seconds in milliseconds
  static const Duration _locationUpdateInterval = Duration(seconds: 2);
  static const Duration _timeoutDuration = Duration(seconds: 10);
  
  // Getters
  Stream<Position> get locationStream => _locationController.stream;
  Stream<LocationServiceStatus> get serviceStatusStream => _serviceStatusController.stream;
  Position? get lastKnownPosition => _lastKnownPosition;
  LocationServiceStatus get serviceStatus => _serviceStatus;
  bool get isLocationServiceEnabled => _serviceStatus == LocationServiceStatus.enabled;

  /// Initialize the precision location service
  Future<void> initialize() async {
    debugPrint('🎯 Initializing PrecisionLocationService...');
    
    try {
      // Check and update service status
      await _updateServiceStatus();
      
      // Start monitoring service status changes
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
        (ServiceStatus status) async {
          debugPrint('🔄 Location service status changed: $status');
          await _updateServiceStatus();
        },
      );
      
      debugPrint('✅ PrecisionLocationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize PrecisionLocationService: $e');
      rethrow;
    }
  }

  /// Start high-precision location tracking
  Future<bool> startLocationTracking() async {
    debugPrint('🎯 Starting high-precision location tracking...');
    
    try {
      // Ensure permissions are granted
      final hasPermission = await _ensureLocationPermissions();
      if (!hasPermission) {
        debugPrint('❌ Location permissions not granted');
        return false;
      }
      
      // Ensure location services are enabled
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('❌ Location services are disabled');
        _serviceStatus = LocationServiceStatus.disabled;
        _serviceStatusController.add(_serviceStatus);
        return false;
      }
      
      // Configure high-precision location settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // Highest accuracy
        distanceFilter: 3, // Update every 3 meters (reduces jitter)
        timeLimit: _timeoutDuration,
      );
      
      // Start position stream with high accuracy settings
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onLocationUpdate,
        onError: _onLocationError,
        onDone: () {
          debugPrint('🎯 Location stream completed');
        },
      );
      
      // Get initial high-accuracy position
      try {
        final initialPosition = await getCurrentPositionWithPrecision();
        if (initialPosition != null) {
          _lastKnownPosition = initialPosition;
          _locationController.add(initialPosition);
        }
      } catch (e) {
        debugPrint('⚠️ Failed to get initial position: $e');
      }
      
      debugPrint('✅ High-precision location tracking started');
      return true;
      
    } catch (e) {
      debugPrint('❌ Failed to start location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void stopLocationTracking() {
    debugPrint('🛑 Stopping location tracking...');
    
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    debugPrint('✅ Location tracking stopped');
  }

  /// Get current position with highest precision and comprehensive error handling
  Future<Position?> getCurrentPositionWithPrecision({
    int maxAttempts = 3,
    Duration timeout = _timeoutDuration,
  }) async {
    debugPrint('🎯 Getting high-precision current position...');
    
    // First check permissions and services
    if (!await _ensureLocationPermissions()) {
      debugPrint('❌ Cannot get location - permissions not granted');
      return _lastKnownPosition;
    }
    
    // Try different accuracy levels if high precision fails
    final accuracyLevels = [
      LocationAccuracy.bestForNavigation,
      LocationAccuracy.best,
      LocationAccuracy.high,
      LocationAccuracy.medium,
    ];
    
    for (final accuracy in accuracyLevels) {
      debugPrint('🔄 Trying accuracy level: $accuracy');
      
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          debugPrint('🔄 Position attempt $attempt/$maxAttempts with $accuracy');
          
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: accuracy,
          ).timeout(timeout);
          
          debugPrint('📍 Position received: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m');
          
          // For high precision, validate accuracy. For others, accept any result
          if (accuracy == LocationAccuracy.bestForNavigation || accuracy == LocationAccuracy.best) {
            if (_isPositionAccurate(position)) {
              debugPrint('✅ High-precision position obtained: accuracy=${position.accuracy}m');
              _lastKnownPosition = position;
              return position;
            } else {
              debugPrint('⚠️ Position accuracy too low (${position.accuracy}m), trying next level...');
              break; // Try next accuracy level
            }
          } else {
            // Accept medium/high accuracy positions
            debugPrint('✅ Position obtained with $accuracy: accuracy=${position.accuracy}m');
            _lastKnownPosition = position;
            return position;
          }
          
        } catch (e) {
          debugPrint('⚠️ Position attempt $attempt failed with $accuracy: $e');
          
          // If it's a permission error, stop trying
          if (e.toString().contains('permission') || e.toString().contains('Permission')) {
            debugPrint('❌ Permission error detected, stopping attempts');
            return _lastKnownPosition;
          }
          
          if (attempt == maxAttempts) {
            debugPrint('⚠️ All attempts failed for $accuracy, trying next level');
            break;
          }
        }
        
        // Wait before retry (except on last attempt)
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
    
    // Fallback to last known position if available
    if (_lastKnownPosition != null) {
      debugPrint('🔄 Using last known position as final fallback');
      return _lastKnownPosition;
    }
    
    debugPrint('❌ No location available after all attempts');
    return null;
  }

  /// Calculate distance between two positions
  double calculateDistance(Position from, Position to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Convert Position to LatLng
  LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }

  /// Check if a position is recent and accurate
  bool isPositionValid(Position position) {
    return _isPositionRecent(position) && _isPositionAccurate(position);
  }

  /// Get the accuracy status of the last known position
  CustomLocationAccuracyStatus getAccuracyStatus() {
    if (_lastKnownPosition == null) {
      return CustomLocationAccuracyStatus.unknown;
    }
    
    if (!_isPositionRecent(_lastKnownPosition!)) {
      return CustomLocationAccuracyStatus.stale;
    }
    
    final accuracy = _lastKnownPosition!.accuracy;
    if (accuracy <= 5) return CustomLocationAccuracyStatus.excellent;
    if (accuracy <= 10) return CustomLocationAccuracyStatus.good;
    if (accuracy <= 20) return CustomLocationAccuracyStatus.fair;
    return CustomLocationAccuracyStatus.poor;
  }

  /// Handle location updates
  void _onLocationUpdate(Position position) {
    debugPrint('🎯 Location update: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m');
    
    // Validate position quality
    if (!_isPositionAccurate(position)) {
      debugPrint('⚠️ Rejecting inaccurate position (accuracy: ${position.accuracy}m)');
      return;
    }
    
    // Filter out positions that are too close to previous position (noise reduction)
    if (_lastKnownPosition != null) {
      final distance = calculateDistance(_lastKnownPosition!, position);
      final timeDiff = position.timestamp.difference(_lastKnownPosition!.timestamp).inSeconds;
      
      // Filter out position if:
      // 1. Distance is very small (< 3m) and accuracy is worse than previous
      // 2. Time difference is too small (< 2 seconds) and distance is minimal
      if ((distance < 3.0 && position.accuracy > _lastKnownPosition!.accuracy) ||
          (timeDiff < 2 && distance < 1.0)) {
        debugPrint('🔇 Filtering out noisy position (distance: ${distance.toStringAsFixed(1)}m, time: ${timeDiff}s)');
        return;
      }
    }
    
    _lastKnownPosition = position;
    _locationController.add(position);
  }

  /// Handle location errors
  void _onLocationError(dynamic error) {
    debugPrint('❌ Location error: $error');
    // Could implement retry logic or fallback here
  }

  /// Ensure location permissions are granted with detailed logging
  Future<bool> _ensureLocationPermissions() async {
    try {
      // Check if location services are enabled first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled on device');
        return false;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('🔍 Current location permission: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('📱 Requesting location permissions...');
        permission = await Geolocator.requestPermission();
        debugPrint('📱 Permission request result: $permission');
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permissions permanently denied - user must enable in settings');
        return false;
      }
      
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permissions denied by user');
        return false;
      }
      
      debugPrint('✅ Location permissions granted: $permission');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking location permissions: $e');
      return false;
    }
  }

  /// Update service status
  Future<void> _updateServiceStatus() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    _serviceStatus = isEnabled 
        ? LocationServiceStatus.enabled 
        : LocationServiceStatus.disabled;
    _serviceStatusController.add(_serviceStatus);
  }

  /// Check if position meets accuracy requirements
  bool _isPositionAccurate(Position position) {
    return position.accuracy <= _accuracyThreshold;
  }

  /// Check if position is recent enough
  bool _isPositionRecent(Position position) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final positionTime = position.timestamp.millisecondsSinceEpoch;
    return (now - positionTime) <= _maxLocationAge;
  }

  /// Force a location update (useful when user manually requests current location)
  Future<bool> forceLocationUpdate() async {
    debugPrint('📲 Forcing location update...');
    
    try {
      final position = await getCurrentPositionWithPrecision();
      if (position != null) {
        _lastKnownPosition = position;
        _locationController.add(position);
        debugPrint('✅ Forced location update successful');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Forced location update failed: $e');
    }
    
    return false;
  }
  
  /// Check if location tracking is currently active
  bool get isTrackingActive => _positionStreamSubscription != null;
  
  /// Get the time since last location update
  Duration? get timeSinceLastUpdate {
    if (_lastKnownPosition == null) return null;
    return DateTime.now().difference(_lastKnownPosition!.timestamp);
  }

  /// Dispose resources
  void dispose() {
    debugPrint('🗯f Disposing PrecisionLocationService...');
    
    stopLocationTracking();
    _serviceStatusSubscription?.cancel();
    _locationController.close();
    _serviceStatusController.close();
    
    debugPrint('✅ PrecisionLocationService disposed');
  }
}

/// Location service status
enum LocationServiceStatus {
  enabled,
  disabled,
  unknown,
}

/// Custom location accuracy status for our app
enum CustomLocationAccuracyStatus {
  excellent, // <= 5m
  good,      // <= 10m
  fair,      // <= 20m
  poor,      // > 20m
  stale,     // Position too old
  unknown,   // No position available
}
