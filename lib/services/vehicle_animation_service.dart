import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Enhanced vehicle animation service for Uber-like smooth 2D vehicle movement
/// Handles real-time vehicle tracking with interpolation, rotation, and smooth animations
class VehicleAnimationService {
  // Singleton pattern
  static final VehicleAnimationService _instance = VehicleAnimationService._internal();
  factory VehicleAnimationService() => _instance;
  VehicleAnimationService._internal();
  
  // Animation state
  Timer? _animationTimer;
  LatLng? _currentPosition;
  LatLng? _targetPosition;
  double _currentHeading = 0.0;
  double _targetHeading = 0.0;
  int _animationStep = 0;
  static const int _totalAnimationSteps = 60; // 60 frames at 16ms = ~1 second
  static const Duration _stepDuration = Duration(milliseconds: 16); // ~60 FPS
  
  // Vehicle icon cache by vehicle type
  final Map<String, BitmapDescriptor> _iconCache = {};
  
  // Callbacks
  Function(LatLng position, double heading)? onPositionUpdate;
  
  /// Start animating vehicle from current position to target position
  void animateVehicle({
    required LatLng from,
    required LatLng to,
    double? heading,
    required Function(LatLng position, double heading) onUpdate,
  }) {
    // Cancel any existing animation
    _animationTimer?.cancel();
    
    _currentPosition = from;
    _targetPosition = to;
    _animationStep = 0;
    onPositionUpdate = onUpdate;
    
    // Calculate heading if not provided
    if (heading != null) {
      _targetHeading = heading;
    } else {
      _targetHeading = _calculateBearing(from, to);
    }
    
    // Don't animate if distance is too small (< 5 meters)
    final distance = _calculateDistance(from, to);
    if (distance < 5) {
      _currentPosition = to;
      _currentHeading = _targetHeading;
      onUpdate(to, _targetHeading);
      return;
    }
    
    // Start animation loop
    _animationTimer = Timer.periodic(_stepDuration, (_) {
      _animateStep();
    });
  }
  
  /// Stop current animation
  void stopAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }
  
  /// Perform single animation step
  void _animateStep() {
    if (_currentPosition == null || _targetPosition == null) {
      stopAnimation();
      return;
    }
    
    _animationStep++;
    
    // Calculate progress (0.0 to 1.0)
    final progress = (_animationStep / _totalAnimationSteps).clamp(0.0, 1.0);
    
    // Use cubic ease-out for smoother deceleration (Uber-like)
    final easedProgress = 1 - math.pow(1 - progress, 3);
    
    // Interpolate position
    final lat = _currentPosition!.latitude + 
                (_targetPosition!.latitude - _currentPosition!.latitude) * easedProgress;
    final lng = _currentPosition!.longitude + 
                (_targetPosition!.longitude - _currentPosition!.longitude) * easedProgress;
    
    // Smooth heading interpolation (shortest rotation path)
    final headingDiff = _shortestAngleDiff(_currentHeading, _targetHeading);
    _currentHeading = (_currentHeading + headingDiff * easedProgress) % 360;
    
    final newPosition = LatLng(lat, lng);
    
    // Notify listener
    onPositionUpdate?.call(newPosition, _currentHeading);
    
    // Stop animation when complete
    if (_animationStep >= _totalAnimationSteps) {
      _currentPosition = _targetPosition;
      _currentHeading = _targetHeading;
      stopAnimation();
    }
  }
  
  /// Calculate bearing (heading) between two points
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
              math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360; // Normalize to 0-360
  }
  
  /// Calculate distance between two points (Haversine formula) in meters
  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371000.0; // meters
    
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(from.latitude * math.pi / 180) *
              math.cos(to.latitude * math.pi / 180) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
  
  /// Calculate shortest angle difference (for smooth rotation)
  double _shortestAngleDiff(double current, double target) {
    double diff = target - current;
    while (diff < -180) {
      diff += 360;
    }
    while (diff > 180) {
      diff -= 360;
    }
    return diff;
  }
  
  /// Create custom 2D vehicle icon based on vehicle type with high quality
  Future<BitmapDescriptor> createVehicleIcon({
    required String vehicleType,
    double heading = 0.0,
    bool forceRecreate = false,
  }) async {
    // Check cache first
    final cacheKey = '${vehicleType.toLowerCase()}_$heading';
    if (!forceRecreate && _iconCache.containsKey(cacheKey)) {
      return _iconCache[cacheKey]!;
    }
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 120.0;
    const center = Offset(size / 2, size / 2);
    
    // Save canvas state
    canvas.save();
    
    // Translate to center and rotate based on heading
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    
    // Determine vehicle appearance based on type
    final vehicleConfig = _getVehicleConfig(vehicleType);
    
    // Draw shadow for depth (larger and softer for realism)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx + 2, center.dy + 3), 32, shadowPaint);
    
    // Draw white border/outline
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 30, borderPaint);
    
    // Draw main vehicle color circle
    final vehiclePaint = Paint()
      ..color = vehicleConfig.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 28, vehiclePaint);
    
    // Draw vehicle icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(vehicleConfig.iconCodePoint),
        style: const TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: 36,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );
    
    // Draw direction indicator (small triangle pointing forward)
    final trianglePath = Path();
    trianglePath.moveTo(center.dx, center.dy - 36); // Point
    trianglePath.lineTo(center.dx - 6, center.dy - 28); // Left
    trianglePath.lineTo(center.dx + 6, center.dy - 28); // Right
    trianglePath.close();
    
    final trianglePaint = Paint()
      ..color = vehicleConfig.color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(trianglePath, trianglePaint);
    
    // Restore canvas
    canvas.restore();
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    final icon = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    
    // Cache the icon
    _iconCache[cacheKey] = icon;
    
    return icon;
  }
  
  /// Get vehicle configuration based on type
  _VehicleConfig _getVehicleConfig(String vehicleType) {
    final type = vehicleType.toLowerCase().trim();
    
    if (type.contains('bike') || type.contains('motorcycle') || 
        type.contains('scooter') || type.contains('motorbike')) {
      return const _VehicleConfig(
        color: Color(0xFFFF6B35), // Orange
        iconCodePoint: 0xe1ca, // two_wheeler
        name: 'Bike',
      );
    } else if (type.contains('suv')) {
      return const _VehicleConfig(
        color: Color(0xFF2ECC71), // Green
        iconCodePoint: 0xe158, // airport_shuttle
        name: 'SUV',
      );
    } else if (type.contains('auto') || type.contains('rickshaw')) {
      return const _VehicleConfig(
        color: Color(0xFFF39C12), // Yellow
        iconCodePoint: 0xe158, // airport_shuttle
        name: 'Auto',
      );
    } else {
      // Default: Car/Sedan
      return const _VehicleConfig(
        color: Color(0xFF3498DB), // Blue
        iconCodePoint: 0xe1b9, // directions_car
        name: 'Car',
      );
    }
  }
  
  /// Clear icon cache (call when vehicle type changes)
  void clearCache() {
    _iconCache.clear();
  }
  
  /// Dispose resources
  void dispose() {
    stopAnimation();
    clearCache();
    onPositionUpdate = null;
  }
}

/// Vehicle configuration class
class _VehicleConfig {
  final Color color;
  final int iconCodePoint;
  final String name;
  
  const _VehicleConfig({
    required this.color,
    required this.iconCodePoint,
    required this.name,
  });
}
