import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/precision_location_service.dart';

/// Enhanced map widget with precision location tracking and accurate markers
class PrecisionMapWidget extends StatefulWidget {
  final LatLng? initialPosition;
  final double initialZoom;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final Function(GoogleMapController)? onMapCreated;
  final Function(LatLng)? onMapTap;
  final Function(CameraPosition)? onCameraMove;
  final Function()? onCameraIdle;
  final bool showMyLocationButton;
  final bool showAccuracyIndicator;
  final bool trackUserLocation;
  final MapType mapType;
  final bool enableLocationUpdates;

  const PrecisionMapWidget({
    super.key,
    this.initialPosition,
    this.initialZoom = 14.0,
    this.markers,
    this.polylines,
    this.onMapCreated,
    this.onMapTap,
    this.onCameraMove,
    this.onCameraIdle,
    this.showMyLocationButton = true,
    this.showAccuracyIndicator = true,
    this.trackUserLocation = true,
    this.mapType = MapType.normal,
    this.enableLocationUpdates = true,
  });

  @override
  State<PrecisionMapWidget> createState() => _PrecisionMapWidgetState();
}

class _PrecisionMapWidgetState extends State<PrecisionMapWidget>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final PrecisionLocationService _locationService = PrecisionLocationService();
  
  // Location tracking state
  StreamSubscription<Position>? _locationSubscription;
  Position? _currentPosition;
  Circle? _accuracyCircle;
  Marker? _precisionLocationMarker;
  bool _isLocationTrackingActive = false;
  
  // Map markers and overlays
  final Set<Marker> _allMarkers = <Marker>{};
  final Set<Circle> _circles = <Circle>{};
  BitmapDescriptor? _customLocationIcon;
  
  // Default location (fallback)
  static const LatLng _defaultLocation = LatLng(50.8503, 4.3517);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocationTracking();
    _loadCustomMarkerIcon();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationTracking();
    _locationService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.trackUserLocation && !_isLocationTrackingActive) {
          _startLocationTracking();
        }
        break;
      case AppLifecycleState.paused:
        if (_isLocationTrackingActive) {
          _pauseLocationTracking();
        }
        break;
      case AppLifecycleState.detached:
        _stopLocationTracking();
        break;
      default:
        break;
    }
  }

  /// Initialize location tracking service
  Future<void> _initializeLocationTracking() async {
    try {
      await _locationService.initialize();
      if (widget.trackUserLocation && widget.enableLocationUpdates) {
        await _startLocationTracking();
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize location tracking: $e');
    }
  }

  /// Start precision location tracking
  Future<void> _startLocationTracking() async {
    if (_isLocationTrackingActive) return;
    
    debugPrint('🎯 Starting precision location tracking in map widget...');
    
    try {
      final success = await _locationService.startLocationTracking();
      if (success) {
        _locationSubscription = _locationService.locationStream.listen(
          _onLocationUpdate,
          onError: (error) {
            debugPrint('❌ Location stream error: $error');
          },
        );
        
        _isLocationTrackingActive = true;
        debugPrint('✅ Precision location tracking started in map widget');
        
        // Get initial position if available
        final initialPosition = _locationService.lastKnownPosition;
        if (initialPosition != null) {
          _onLocationUpdate(initialPosition);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to start location tracking: $e');
    }
  }

  /// Pause location tracking (keep service running but stop updates)
  void _pauseLocationTracking() {
    _locationSubscription?.pause();
    debugPrint('⏸️ Location tracking paused');
  }

  /// Stop location tracking completely
  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopLocationTracking();
    _isLocationTrackingActive = false;
    debugPrint('🛑 Location tracking stopped in map widget');
  }

  /// Handle location updates with precision
  void _onLocationUpdate(Position position) {
    if (!mounted) return;
    
    debugPrint('🎯 Map widget received location update: accuracy=${position.accuracy}m');
    
    setState(() {
      _currentPosition = position;
      _updatePrecisionLocationMarker(position);
      _updateAccuracyCircle(position);
    });
  }

  /// Update precision location marker
  void _updatePrecisionLocationMarker(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);
    
    _precisionLocationMarker = Marker(
      markerId: const MarkerId('precision_current_location'),
      position: latLng,
      icon: _customLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: 'Your Location',
        snippet: 'Accuracy: ${position.accuracy.toStringAsFixed(1)}m',
      ),
      zIndex: 999, // Ensure it's on top
    );
    
    _updateAllMarkers();
  }

  /// Update accuracy circle around location
  void _updateAccuracyCircle(Position position) {
    if (!widget.showAccuracyIndicator) {
      _accuracyCircle = null;
      return;
    }
    
    final latLng = LatLng(position.latitude, position.longitude);
    
    // Color based on accuracy
    Color circleColor;
    double strokeWidth;
    
    if (position.accuracy <= 5) {
      circleColor = Colors.green;
      strokeWidth = 2.0;
    } else if (position.accuracy <= 10) {
      circleColor = Colors.blue;
      strokeWidth = 2.0;
    } else if (position.accuracy <= 20) {
      circleColor = Colors.orange;
      strokeWidth = 3.0;
    } else {
      circleColor = Colors.red;
      strokeWidth = 3.0;
    }
    
    _accuracyCircle = Circle(
      circleId: const CircleId('accuracy_circle'),
      center: latLng,
      radius: position.accuracy,
      fillColor: circleColor.withValues(alpha: 0.1),
      strokeColor: circleColor.withValues(alpha: 0.8),
      strokeWidth: strokeWidth.toInt(),
    );
    
    _updateCircles();
  }

  /// Update all markers on the map
  void _updateAllMarkers() {
    _allMarkers.clear();
    
    // Add external markers
    if (widget.markers != null) {
      _allMarkers.addAll(widget.markers!);
    }
    
    // Add precision location marker
    if (_precisionLocationMarker != null) {
      _allMarkers.add(_precisionLocationMarker!);
    }
  }

  /// Update all circles on the map
  void _updateCircles() {
    _circles.clear();
    
    // Add accuracy circle
    if (_accuracyCircle != null) {
      _circles.add(_accuracyCircle!);
    }
  }

  /// Load custom marker icon for precise location
  Future<void> _loadCustomMarkerIcon() async {
    try {
      const iconSize = 48.0;
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      // Draw custom location icon
      final paint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      
      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      // Draw outer circle (white border)
      canvas.drawCircle(
        const Offset(iconSize / 2, iconSize / 2),
        iconSize / 2,
        strokePaint,
      );
      
      // Draw inner circle (blue fill)
      canvas.drawCircle(
        const Offset(iconSize / 2, iconSize / 2),
        (iconSize / 2) - 2,
        paint,
      );
      
      // Draw center dot
      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        const Offset(iconSize / 2, iconSize / 2),
        4.0,
        centerPaint,
      );
      
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(iconSize.toInt(), iconSize.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (bytes != null) {
        _customLocationIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('⚠️ Failed to create custom marker icon: $e');
    }
  }

  /// Handle map creation
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Move to current location if available
    if (_currentPosition != null) {
      _animateToPosition(_currentPosition!);
    } else if (widget.initialPosition != null) {
      _animateToLocation(widget.initialPosition!);
    }
    
    // Call external callback
    widget.onMapCreated?.call(controller);
  }

  /// Animate camera to position
  void _animateToPosition(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);
    _animateToLocation(latLng);
  }

  /// Animate camera to location
  void _animateToLocation(LatLng location, {double? zoom}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: zoom ?? widget.initialZoom,
        ),
      ),
    );
  }

  /// Move to current location (public method)
  void moveToCurrentLocation() {
    if (_currentPosition != null) {
      _animateToPosition(_currentPosition!);
    } else {
      // Try to get current position
      _getCurrentLocationAndMove();
    }
  }

  /// Get current location and move camera
  Future<void> _getCurrentLocationAndMove() async {
    try {
      final position = await _locationService.getCurrentPositionWithPrecision();
      if (position != null && mounted) {
        _animateToPosition(position);
      }
    } catch (e) {
      debugPrint('❌ Failed to get current location: $e');
    }
  }

  /// Get current position for external use
  Position? get currentPosition => _currentPosition;
  
  /// Get location accuracy status
  CustomLocationAccuracyStatus get accuracyStatus => _locationService.getAccuracyStatus();

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      
      // Initial camera position
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition ?? _defaultLocation,
        zoom: widget.initialZoom,
      ),
      
      // Markers and overlays
      markers: _allMarkers,
      circles: _circles,
      polylines: widget.polylines ?? <Polyline>{},
      
      // Map interaction settings
      myLocationEnabled: false, // We handle this with precision tracking
      myLocationButtonEnabled: false, // Custom button
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      
      // Map style
      mapType: widget.mapType,
      
      // Callbacks
      onTap: widget.onMapTap,
      onCameraMove: widget.onCameraMove,
      onCameraIdle: () {
        widget.onCameraIdle?.call();
      },
    );
  }
}