import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  final String title;
  final Location? initialLocation;
  final bool showCurrentLocation;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
    this.showCurrentLocation = true,
  });

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  static const String _googleApiKey = "AIzaSyBRYPKaXlRhpzoAmM5-KrS2JaNDxAX_phw";
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;
  Location? _currentLocation;
  List<Location> _savedPlaces = [];
  List<Location> _recentPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAndRecentPlaces();
    _getCurrentLocation();
    
    if (widget.initialLocation != null) {
      _searchController.text = widget.initialLocation!.displayName;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!widget.showCurrentLocation) return;
    
    try {
      final position = await Geolocator.getCurrentPosition();
      
      setState(() {
        _currentLocation = Location.currentLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          formattedAddress: 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
        );
      });
    } catch (e) {
      // Handle location error silently
      debugPrint('Failed to get current location: $e');
    }
  }

  Future<void> _loadSavedAndRecentPlaces() async {
    // In a real app, this would load from local storage/database
    setState(() {
      _savedPlaces = [
        Location.savedPlace(
          name: 'Home',
          latitude: -1.2921,
          longitude: 36.8219,
          formattedAddress: 'Nairobi, Kenya',
        ),
        Location.savedPlace(
          name: 'Office',
          latitude: -1.2841,
          longitude: 36.8155,
          formattedAddress: 'Westlands, Nairobi',
        ),
      ];
      
      _recentPlaces = [
        const Location(
          name: 'JKIA Terminal 1A',
          formattedAddress: 'Jomo Kenyatta International Airport, Nairobi',
          latitude: -1.3192,
          longitude: 36.9278,
          type: LocationType.recentPlace,
        ),
        const Location(
          name: 'Sarit Centre',
          formattedAddress: 'Westlands, Nairobi',
          latitude: -1.2630,
          longitude: 36.8063,
          type: LocationType.recentPlace,
        ),
      ];
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Get current location for bias if available
      String location = '';
      if (_currentLocation != null) {
        location = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
      }
      
      // Build Google Places Autocomplete API URL
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '${location.isNotEmpty ? '&location=$location&radius=50000' : ''}'
          '&language=en'
          '&components=country:in'
          '&key=$_googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['predictions'] != null) {
          final predictions = (data['predictions'] as List)
              .map((p) => {
                    'place_id': p['place_id']?.toString() ?? '',
                    'description': p['description']?.toString() ?? '',
                  })
              .toList();
          
          if (mounted) {
            setState(() {
              _searchResults = predictions;
              _isSearching = false;
            });
          }
        } else {
          debugPrint('Google Places API error: ${data['status']}');
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isSearching = false;
            });
          }
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectPlace(Map<String, String> placeData) async {
    if (!mounted) return;
    
    try {
      final placeId = placeData['place_id'] ?? '';
      final description = placeData['description'] ?? '';
      
      if (placeId.isEmpty) return;
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading location details...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      // Get place details from Google Places API
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry,formatted_address,name'
          '&key=$_googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['result'] != null) {
          final result = data['result'];
          final geometry = result['geometry'];
          final locationData = geometry['location'];
          
          final lat = locationData['lat'] as double;
          final lng = locationData['lng'] as double;
          final formattedAddress = result['formatted_address'] as String?;
          final name = result['name'] as String?;
          
          if (mounted) {
            final location = Location.fromPlaceDetails(
              placeId: placeId,
              name: name ?? description,
              formattedAddress: formattedAddress ?? description,
              latitude: lat,
              longitude: lng,
            );
            
            Navigator.of(context).pop(location);
          }
        } else {
          throw Exception('Place details not found');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error selecting location: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _selectLocation(Location location) {
    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                onChanged: _searchPlaces,
                decoration: InputDecoration(
                  hintText: 'Search for a location...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchPlaces('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: _buildContent(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_searchController.text.isNotEmpty) {
      return _buildSearchResults(theme);
    }
    
    return _buildLocationSuggestions(theme);
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final place = _searchResults[index];
        final description = place['description'] ?? '';
        
        return _LocationTile(
          icon: Icons.place_outlined,
          title: description,
          onTap: () => _selectPlace(place),
        );
      },
    );
  }

  Widget _buildLocationSuggestions(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Current Location
        if (_currentLocation != null && widget.showCurrentLocation) ...[
          _buildSectionTitle('Current Location', theme),
          _LocationTile(
            icon: Icons.my_location,
            title: _currentLocation!.name,
            subtitle: _currentLocation!.formattedAddress,
            iconColor: theme.colorScheme.primary,
            onTap: () => _selectLocation(_currentLocation!),
          ),
          const SizedBox(height: 24),
        ],

        // Saved Places
        if (_savedPlaces.isNotEmpty) ...[
          _buildSectionTitle('Saved Places', theme),
          ..._savedPlaces.map(
            (place) => _LocationTile(
              icon: _getIconForSavedPlace(place.name),
              title: place.name,
              subtitle: place.formattedAddress,
              onTap: () => _selectLocation(place),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Recent Places
        if (_recentPlaces.isNotEmpty) ...[
          _buildSectionTitle('Recent Places', theme),
          ..._recentPlaces.map(
            (place) => _LocationTile(
              icon: Icons.history,
              title: place.name,
              subtitle: place.formattedAddress,
              onTap: () => _selectLocation(place),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  IconData _getIconForSavedPlace(String name) {
    switch (name.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'office':
      case 'work':
        return Icons.business;
      default:
        return Icons.place;
    }
  }
}

class _LocationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _LocationTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.onSurface)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}