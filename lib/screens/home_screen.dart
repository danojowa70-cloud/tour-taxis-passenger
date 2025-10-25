import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Using HTTP requests for Google Places API instead of google_places_flutter
// as it appears to have compatibility issues
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../providers/home_providers.dart';
import '../providers/ride_flow_providers.dart';
import '../services/fare_service.dart';
import '../models/vehicle_type.dart';

/// Simple class to represent a place prediction from Google Places API
class PlacePrediction {
  final String placeId;
  final String description;
  
  PlacePrediction({
    required this.placeId,
    required this.description,
  });
  
  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Google Maps API Key - Replace with your actual key
  static const String _googleMapsApiKey = "AIzaSyBRYPKaXlRhpzoAmM5-KrS2JaNDxAX_phw";
  
  // Text controllers for input fields
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  final FocusNode _pickupFocusNode = FocusNode();
  
  // UI state variables
  bool _showVehicleSelection = false;
  bool _isLocationInputExpanded = false;
  String _selectedVehicle = '';
  String _currentLocationName = 'Current Location';
  
  // Autocomplete suggestions
  List<PlacePrediction> _pickupSuggestions = [];
  List<PlacePrediction> _destinationSuggestions = [];
  bool _showPickupSuggestions = false;
  bool _showDestinationSuggestions = false;
  
  // Google Maps controller and markers
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  
  // Default location (Brussels, Belgium)
  static const LatLng _defaultLocation = LatLng(50.8503, 4.3517);
  
  // Timer for search debouncing
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 HomeScreen initializing...');
    
    // Set default pickup location text
    _pickupController.text = 'Current Location';
    
    // Add listeners for text field changes to trigger autocomplete
    _pickupController.addListener(_onPickupTextChanged);
    _destinationController.addListener(_onDestinationTextChanged);
    
    // Load current location
    _loadCurrentLocationAndSetupMap();
  }

  @override
  void dispose() {
    // Dispose controllers and focus nodes
    _pickupController.dispose();
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    _pickupFocusNode.dispose();
    
    // Cancel any pending search timer
    _searchTimer?.cancel();
    
    super.dispose();
  }

  /// Load current location and initialize map
  Future<void> _loadCurrentLocationAndSetupMap() async {
    debugPrint('🗺 Loading current location...');
    
    try {
      // Check location permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Location permissions denied');
          _setDefaultLocation();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permissions permanently denied');
        _setDefaultLocation();
        return;
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugPrint('✅ Current location: ${position.latitude}, ${position.longitude}');
      
      // Set pickup location to current position
      setState(() {
        _pickupLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Reverse geocode to get readable address
      await _reverseGeocodeCurrentLocation(position.latitude, position.longitude);
      
      // Update map markers
      _updateMapMarkers();
      
    } catch (e) {
      debugPrint('⚠️ Error getting location: $e');
      _setDefaultLocation();
    }
  }
  
  /// Set default location when GPS is unavailable
  void _setDefaultLocation() {
    setState(() {
      _pickupLocation = _defaultLocation;
      _currentLocationName = 'Brussels, Belgium';
      _pickupController.text = 'Brussels, Belgium';
    });
    _updateMapMarkers();
  }
  
  /// Reverse geocode current location to get readable address
  Future<void> _reverseGeocodeCurrentLocation(double lat, double lng) async {
    try {
      // For demo purposes, using a simple location name
      // In production, you would use Google Places API reverse geocoding
      final locationName = 'Near ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      
      setState(() {
        _currentLocationName = locationName;
        _pickupController.text = locationName;
      });
      
      debugPrint('✅ Location name: $locationName');
    } catch (e) {
      debugPrint('⚠️ Reverse geocoding failed: $e');
      setState(() {
        _currentLocationName = 'Current Location';
        _pickupController.text = 'Current Location';
      });
    }
  }
  
  /// Handle pickup text field changes for autocomplete
  void _onPickupTextChanged() {
    final query = _pickupController.text;
    debugPrint('🔍 Pickup text changed: $query');
    
    // Cancel previous timer
    _searchTimer?.cancel();
    
    // Don't search for "Current Location" or empty text
    if (query.isEmpty || query == 'Current Location') {
      setState(() {
        _showPickupSuggestions = false;
        _pickupSuggestions = [];
      });
      return;
    }
    
    // Debounce search requests (wait 500ms after user stops typing)
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query, isPickup: true);
    });
  }
  
  /// Handle destination text field changes for autocomplete
  void _onDestinationTextChanged() {
    final query = _destinationController.text;
    debugPrint('🔍 Destination text changed: $query');
    
    // Cancel previous timer
    _searchTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _showDestinationSuggestions = false;
        _destinationSuggestions = [];
      });
      return;
    }
    
    // Debounce search requests
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query, isPickup: false);
    });
  }
  
  /// Search places using Google Places Autocomplete API
  Future<void> _searchPlaces(String query, {required bool isPickup}) async {
    debugPrint('🔍 Searching places for: $query (pickup: $isPickup)');
    
    try {
      // Build API URL for Google Places Autocomplete
      final location = _pickupLocation != null 
          ? '${_pickupLocation!.latitude},${_pickupLocation!.longitude}'
          : '${_defaultLocation.latitude},${_defaultLocation.longitude}';
      
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&location=$location'
          '&radius=50000'
          '&language=en'
          '&types=establishment|geocode'
          '&key=$_googleMapsApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['predictions'] != null) {
          final predictions = (data['predictions'] as List)
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
          
          debugPrint('✅ Found ${predictions.length} suggestions');
          
          setState(() {
            if (isPickup) {
              _pickupSuggestions = predictions;
              _showPickupSuggestions = predictions.isNotEmpty;
            } else {
              _destinationSuggestions = predictions;
              _showDestinationSuggestions = predictions.isNotEmpty;
            }
          });
        } else {
          debugPrint('⚠️ API returned: ${data['status']}');
          _clearSuggestions(isPickup);
        }
      } else {
        debugPrint('⚠️ HTTP error: ${response.statusCode}');
        _clearSuggestions(isPickup);
      }
    } catch (e) {
      debugPrint('⚠️ Places search error: $e');
      _clearSuggestions(isPickup);
    }
  }
  
  /// Clear suggestions for pickup or destination
  void _clearSuggestions(bool isPickup) {
    setState(() {
      if (isPickup) {
        _showPickupSuggestions = false;
        _pickupSuggestions = [];
      } else {
        _showDestinationSuggestions = false;
        _destinationSuggestions = [];
      }
    });
  }
  
  /// Handle selection of a place from autocomplete suggestions
  Future<void> _selectPlace(PlacePrediction prediction, {required bool isPickup}) async {
    debugPrint('🗺 Selecting place: ${prediction.description} (pickup: $isPickup)');
    
    try {
      // Get place details to obtain coordinates using Google Places Details API
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${prediction.placeId}'
          '&fields=geometry'
          '&key=$_googleMapsApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['result'] != null) {
          final geometry = data['result']['geometry'];
          if (geometry != null && geometry['location'] != null) {
            final location = geometry['location'];
            final latLng = LatLng(
              location['lat'].toDouble(), 
              location['lng'].toDouble(),
            );
            
            setState(() {
              if (isPickup) {
                _pickupLocation = latLng;
                _pickupController.text = prediction.description;
                _showPickupSuggestions = false;
                _pickupSuggestions = [];
              } else {
                _destinationLocation = latLng;
                _destinationController.text = prediction.description;
                _showDestinationSuggestions = false;
                _destinationSuggestions = [];
                _showVehicleSelection = true; // Show vehicle options when destination is set
              }
            });
            
            // Update markers and calculate route
            _updateMapMarkers();
            if (_pickupLocation != null && _destinationLocation != null) {
              _calculateRouteData();
            }
            
            // Hide keyboard
            if (mounted) {
              FocusScope.of(context).unfocus();
            }
            
            debugPrint('✅ Place selected and location updated');
          } else {
            debugPrint('⚠️ No geometry data in place details');
          }
        } else {
          debugPrint('⚠️ Place details API returned: ${data['status']}');
        }
      } else {
        debugPrint('⚠️ Place details HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Error selecting place: $e');
    }
  }
  
  /// Use current GPS location for pickup with automatic permission handling
  void _useCurrentLocation() async {
    debugPrint('🗺️ Using current GPS location for pickup');
    
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }
    
    // Check and request permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedForeverDialog();
      return;
    }
    
    try {
      // Show loading state
      setState(() {
        _pickupController.text = 'Getting location...';
      });
      
      // Get fresh location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _pickupLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _pickupController.text = _currentLocationName;
        _showPickupSuggestions = false;
      });
      
      _updateMapMarkers();
      if (mounted) {
        FocusScope.of(context).unfocus();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Current location set as pickup'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      debugPrint('✅ Current location set for pickup');
    } catch (e) {
      debugPrint('⚠️ Error getting current location: $e');
      if (mounted) {
        setState(() {
          _pickupController.text = 'From';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get location. Please check GPS settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  void _updateMapMarkers() {
    _markers.clear();
    
    if (_pickupLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ));
    }
    
    if (_destinationLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    }
    
    setState(() {});
    
    // Fit markers in view if both are set
    if (_pickupLocation != null && _destinationLocation != null && _mapController != null) {
      _fitMarkersInView();
    }
  }
  
  void _fitMarkersInView() {
    if (_mapController == null || _pickupLocation == null || _destinationLocation == null) return;
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        _pickupLocation!.latitude < _destinationLocation!.latitude 
            ? _pickupLocation!.latitude : _destinationLocation!.latitude,
        _pickupLocation!.longitude < _destinationLocation!.longitude 
            ? _pickupLocation!.longitude : _destinationLocation!.longitude,
      ),
      northeast: LatLng(
        _pickupLocation!.latitude > _destinationLocation!.latitude 
            ? _pickupLocation!.latitude : _destinationLocation!.latitude,
        _pickupLocation!.longitude > _destinationLocation!.longitude 
            ? _pickupLocation!.longitude : _destinationLocation!.longitude,
      ),
    );
    
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }
  
  /// Calculate route data using Google Directions API
  Future<void> _calculateRouteData() async {
    if (_pickupLocation == null || _destinationLocation == null) return;
    
    try {
      debugPrint('🗺 Calculating route data...');
      
      // Show loading state in ride flow
      ref.read(rideFlowProvider.notifier).updateFrom(
        pickup: _pickupController.text,
        destination: _destinationController.text,
      );
      
      final directionsService = ref.read(directionsServiceProvider);
      
      final result = await directionsService.routeLatLng(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _destinationLocation!.latitude,
        _destinationLocation!.longitude,
      );
      
      if (result != null && mounted) {
        debugPrint('✅ Route calculated: ${result.distanceMeters}m, ${result.durationSeconds}s');
        
        // Update ride flow provider with real data
        ref.read(rideFlowProvider.notifier).updateFrom(
          pickup: _pickupController.text,
          destination: _destinationController.text,
          pickupLatLng: {
            'lat': _pickupLocation!.latitude,
            'lng': _pickupLocation!.longitude,
          },
          destinationLatLng: {
            'lat': _destinationLocation!.latitude,
            'lng': _destinationLocation!.longitude,
          },
          distanceMeters: result.distanceMeters,
          durationSeconds: result.durationSeconds,
          polyline: result.polyline,
          estimatedFare: _calculateFare(result.distanceMeters, result.durationSeconds),
        );
      }
    } catch (e) {
      debugPrint('💥 Route calculation failed: $e');
      // Use fallback data if API fails
      _setFallbackRouteData();
    }
  }
  
  /// Calculate fare based on distance and duration
  double _calculateFare(double distanceMeters, double durationSeconds) {
    // Base fare: KSh 200
    // Distance rate: KSh 50 per km
    // Time rate: KSh 5 per minute
    
    const baseFare = 200.0;
    final distanceFare = (distanceMeters / 1000) * 50.0; // KSh per km
    final timeFare = (durationSeconds / 60) * 5.0; // KSh per minute
    
    final totalFare = baseFare + distanceFare + timeFare;
    return totalFare.roundToDouble();
  }
  
  /// Set fallback route data if API fails
  void _setFallbackRouteData() {
    if (_pickupLocation == null || _destinationLocation == null) return;
    
    // Calculate straight-line distance for fallback
    final distanceKm = _calculateStraightLineDistance(
      _pickupLocation!.latitude,
      _pickupLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );
    
    final estimatedDuration = distanceKm * 3 * 60; // 3 minutes per km
    final estimatedFare = _calculateFare(distanceKm * 1000, estimatedDuration);
    
    ref.read(rideFlowProvider.notifier).updateFrom(
      pickup: _pickupController.text,
      destination: _destinationController.text,
      pickupLatLng: {
        'lat': _pickupLocation!.latitude,
        'lng': _pickupLocation!.longitude,
      },
      destinationLatLng: {
        'lat': _destinationLocation!.latitude,
        'lng': _destinationLocation!.longitude,
      },
      distanceMeters: distanceKm * 1000,
      durationSeconds: estimatedDuration,
      polyline: [
        [_pickupLocation!.latitude, _pickupLocation!.longitude],
        [_destinationLocation!.latitude, _destinationLocation!.longitude],
      ],
      estimatedFare: estimatedFare,
    );
  }
  
  /// Calculate straight-line distance between two points (Haversine formula)
  double _calculateStraightLineDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusKm = 6371.0;
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    
    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
         sin(dLng / 2) * sin(dLng / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }
  
  /// Navigate to confirm screen with route data
  void _navigateToConfirmScreen() async {
    // Ensure route data is calculated before navigating
    if (_pickupLocation != null && _destinationLocation != null) {
      await _calculateRouteData();
    }
    
    if (mounted) {
      Navigator.of(context).pushNamed('/confirm');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    debugPrint('🏠 HomeScreen building...');
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Google Maps Background - Always show map
          Positioned.fill(
            child: _buildGoogleMapBackground(theme),
          ),
          
          // Custom App Bar
          _buildCustomAppBar(),
          
          // Location Input Card with Autocomplete
          _buildLocationInputCard(),
          
          // Pickup Suggestions Overlay
          if (_showPickupSuggestions && _pickupSuggestions.isNotEmpty)
            _buildPickupSuggestionsOverlay(theme),
            
          // Destination Suggestions Overlay  
          if (_showDestinationSuggestions && _destinationSuggestions.isNotEmpty)
            _buildDestinationSuggestionsOverlay(theme),
          
          // Map Controls
          _buildMapControls(),
          
          // Vehicle Selection Panel
          if (_showVehicleSelection)
            _buildVehicleSelectionPanel(),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    final theme = Theme.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInputCard() {
    final theme = Theme.of(context);
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main input section - always visible
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Route indicator
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 24,
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Input fields
                  Expanded(
                    child: Column(
                      children: [
                        // Compact pickup input
                        _buildCompactLocationInput(
                          controller: _pickupController,
                          focusNode: _pickupFocusNode,
                          hintText: 'From',
                          showLocationButton: true,
                        ),
                        const SizedBox(height: 8),
                        // Compact destination input
                        _buildCompactLocationInput(
                          controller: _destinationController,
                          focusNode: _destinationFocusNode,
                          hintText: 'Where to?',
                          showLocationButton: false,
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLocationInputExpanded = !_isLocationInputExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isLocationInputExpanded ? Icons.expand_less : Icons.expand_more,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Expandable section with quick destinations
            if (_isLocationInputExpanded && _destinationController.text.isEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: _buildQuickDestinations(),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompactLocationInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required bool showLocationButton,
  }) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              // Note: onChanged is handled by listeners added in initState
              // This ensures proper debouncing of search requests
              onTap: () {
                if (controller == _destinationController) {
                  setState(() => _isLocationInputExpanded = true);
                }
              },
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (showLocationButton)
            GestureDetector(
              onTap: _useCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.my_location,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickDestinations() {
    final theme = Theme.of(context);
    final destinations = [
      {'icon': Icons.work_outline, 'title': 'Work', 'subtitle': 'Tech Hub'},
      {'icon': Icons.home_outlined, 'title': 'Home', 'subtitle': 'Kileleshwa'},
      {'icon': Icons.local_airport, 'title': 'Airport', 'subtitle': 'JKIA'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick destinations',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        ...destinations.map((dest) => _QuickDestinationTile(
          icon: dest['icon'] as IconData,
          title: dest['title'] as String,
          subtitle: dest['subtitle'] as String,
          onTap: () {
            _destinationController.text = dest['title'] as String;
            
            // Set destination location for quick destinations
            if (_pickupLocation != null) {
              // Set different locations for each destination
              switch (dest['title']) {
                case 'Work':
                  _destinationLocation = LatLng(
                    _pickupLocation!.latitude + 0.008,
                    _pickupLocation!.longitude + 0.012,
                  );
                  break;
                case 'Home':
                  _destinationLocation = LatLng(
                    _pickupLocation!.latitude - 0.005,
                    _pickupLocation!.longitude + 0.008,
                  );
                  break;
                case 'Airport':
                  _destinationLocation = LatLng(
                    _pickupLocation!.latitude + 0.015,
                    _pickupLocation!.longitude - 0.010,
                  );
                  break;
              }
              _updateMapMarkers();
              
              // Calculate real route data for quick destination
              _calculateRouteData();
            }
            
            setState(() {
              _showVehicleSelection = true;
              _isLocationInputExpanded = false;
            });
          },
        )),
      ],
    );
  }

  Widget _buildPickupSuggestionsOverlay(ThemeData theme) {
    return Positioned(
      top: 150, // Position below the location input card
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            itemCount: _pickupSuggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _pickupSuggestions[index];
              return ListTile(
                leading: Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  suggestion.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _selectPlace(suggestion, isPickup: true),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildMapControls() {
    final theme = Theme.of(context);
    return Positioned(
      bottom: _showVehicleSelection ? 320 : 100,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom In Button
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _mapController?.animateCamera(CameraUpdate.zoomIn());
                },
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add,
                    color: theme.colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // Divider
          Container(
            width: 44,
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          // Zoom Out Button  
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                },
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.remove,
                    color: theme.colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // My Location Button
          FloatingActionButton(
            mini: true,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 4,
            onPressed: () async {
              if (_mapController != null) {
                try {
                  final position = await ref.read(currentPositionProvider.future);
                  _mapController!.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(position.latitude, position.longitude),
                        zoom: 15.0,
                      ),
                    ),
                  );
                } catch (e) {
                  // Handle error silently
                }
              }
            },
            child: const Icon(Icons.my_location, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelectionPanel() {
    final theme = Theme.of(context);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {}, // Prevent dismissal on tap
        child: Container(
          height: 300, // Fixed height to show map above
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle and Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                child: Column(
                  children: [
                    // Drag handle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showVehicleSelection = false;
                          _selectedVehicle = '';
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Header with close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Choose your ride',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showVehicleSelection = false;
                              _selectedVehicle = '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.outline.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Vehicle options - scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: _buildVehicleOptions(),
                  ),
                ),
              ),
              // Bottom button area
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _selectedVehicle.isNotEmpty
                        ? () => _navigateToConfirmScreen()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _selectedVehicle.isNotEmpty 
                          ? 'Book ${_getVehicleName(_selectedVehicle)}'
                          : 'Select a ride',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getVehicleName(String vehicle) {
    switch (vehicle) {
      case 'car': return 'Car';
      case 'suv': return 'SUV';
      case 'bike': return 'Bike';
      default: return 'Ride';
    }
  }
  
  /// Build vehicle options with dynamic pricing
  List<Widget> _buildVehicleOptions() {
    const fareService = FareService();
    
    // Calculate estimated distance for fare calculation (fallback to 5km if not available)
    double estimatedDistance = 5000; // Default 5km in meters
    double estimatedDuration = 900; // Default 15 minutes in seconds
    
    // Use actual distance if available from route calculation
    if (_pickupLocation != null && _destinationLocation != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _destinationLocation!.latitude,
        _destinationLocation!.longitude,
      );
      estimatedDistance = distanceInMeters;
      // Rough estimate: 30 km/h average speed in city
      estimatedDuration = (distanceInMeters / 1000) * 2 * 60; // 2 minutes per km
    }
    
    return VehicleTypeInfo.getStandardTypes().map((vehicleInfo) {
      final calculatedFare = fareService.estimateByVehicleType(
        distanceMeters: estimatedDistance,
        durationSeconds: estimatedDuration,
        vehicleType: vehicleInfo.type,
      );
      
      return Column(
        children: [
          _VehicleOption(
            icon: vehicleInfo.icon,
            title: vehicleInfo.name,
            subtitle: vehicleInfo.description,
            price: 'KSh ${calculatedFare.round()}',
            time: vehicleInfo.estimatedArrivalTime,
            isSelected: _selectedVehicle == vehicleInfo.id,
            onTap: () => setState(() => _selectedVehicle = vehicleInfo.id),
          ),
          if (vehicleInfo.id != 'bike') const SizedBox(height: 10),
          if (vehicleInfo.id == 'bike') const SizedBox(height: 16),
        ],
      );
    }).toList();
  }
  
  /// Build Google Maps background with proper initialization
  Widget _buildGoogleMapBackground(ThemeData theme) {
    debugPrint('🗺 Building Google Maps background...');
    
    return GoogleMap(
      // Map initialization
      onMapCreated: (GoogleMapController controller) {
        debugPrint('✅ Google Map created successfully');
        _mapController = controller;
        
        // Move camera to current/default location
        final targetLocation = _pickupLocation ?? _defaultLocation;
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: targetLocation,
              zoom: 14.0,
            ),
          ),
        );
      },
      
      // Initial camera position
      initialCameraPosition: CameraPosition(
        target: _pickupLocation ?? _defaultLocation,
        zoom: 14.0,
      ),
      
      // Map markers (pickup and destination)
      markers: _markers,
      
      // Map interaction settings
      myLocationEnabled: true,
      myLocationButtonEnabled: false, // We'll use custom button
      zoomControlsEnabled: false, // We'll use custom zoom controls
      mapToolbarEnabled: false,
      compassEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      
      // Map style (you can customize this)
      mapType: MapType.normal,
      
      // Handle map tap for destination selection
      onTap: (LatLng tappedPoint) {
        debugPrint('🗺 Map tapped at: $tappedPoint');
        
        // If destination is not set, allow setting it by tapping map
        if (_destinationLocation == null) {
          setState(() {
            _destinationLocation = tappedPoint;
            _destinationController.text = 'Selected Location';
            _showVehicleSelection = true;
          });
          _updateMapMarkers();
          
          // Calculate route if both locations are set
          if (_pickupLocation != null) {
            _calculateRouteData();
          }
        }
      },
      
      // Error handling
      onCameraIdle: () {
        debugPrint('📷 Camera idle - map loaded successfully');
      },
    );
  }

  
  /// Build destination suggestions overlay
  Widget _buildDestinationSuggestionsOverlay(ThemeData theme) {
    return Positioned(
      top: 200, // Position below the location input card
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            itemCount: _destinationSuggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _destinationSuggestions[index];
              return ListTile(
                leading: Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  suggestion.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _selectPlace(suggestion, isPickup: false),
              );
            },
          ),
        ),
      ),
    );
  }
  
  /// Show dialog when location services are disabled
  void _showLocationServiceDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_off,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text('Enable Location Services'),
            ],
          ),
          content: const Text(
            'Location services are turned off. To get your current location, please enable GPS in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
  
  /// Show dialog when location permission is denied
  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_disabled,
                color: theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text('Location Permission'),
            ],
          ),
          content: const Text(
            'Location permission is required to get your current location. Please allow location access when prompted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _useCurrentLocation(); // Try again
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }
  
  /// Show dialog when location permission is permanently denied
  void _showPermissionDeniedForeverDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.block,
                color: theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text('Permission Required'),
            ],
          ),
          content: const Text(
            'Location permission has been permanently denied. To use your current location, please enable it manually in the app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}

class _QuickDestinationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  
  const _QuickDestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleOption extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String price;
  final String time;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _VehicleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.time,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        price,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

