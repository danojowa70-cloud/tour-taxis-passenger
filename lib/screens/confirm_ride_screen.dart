import 'package:flutter/material.dart';
import '../providers/ride_flow_providers.dart';
import '../providers/realtime_providers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/ride_service.dart';
import '../services/fare_service.dart';
import '../models/vehicle_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConfirmRideScreen extends ConsumerStatefulWidget {
  const ConfirmRideScreen({super.key});

  @override
  ConsumerState<ConfirmRideScreen> createState() => _ConfirmRideScreenState();
}

class _ConfirmRideScreenState extends ConsumerState<ConfirmRideScreen> {
  GoogleMapController? _mapController;
  String _selectedVehicle = 'car'; // Default selection
  String _selectedPayment = 'cash';

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(rideFlowProvider);
    final theme = Theme.of(context);
    final polyPoints = flow.polyline ?? [];
    final polyline = polyPoints
        .map((p) => LatLng(p[0], p[1]))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildCustomAppBar(),
            
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route Map Preview
                      _buildRoutePreview(polyline, theme, flow),
                      
                      const SizedBox(height: 24),
                      
                      // Trip Details Card
                      _buildTripDetailsCard(flow, theme),
                      
                      const SizedBox(height: 20),
                      
                      // Vehicle Selection
                      _buildVehicleSelection(theme),
                      
                      const SizedBox(height: 20),
                      
                      // Payment Method
                      _buildPaymentSelection(theme),
                      
                      const SizedBox(height: 20),
                      
                      // Price Breakdown
                      _buildPriceBreakdown(flow, theme),
                      
                      const SizedBox(height: 100), // Space for button
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom Actions
            _buildBottomActions(flow),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm your ride',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Review trip details',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePreview(List<LatLng> polyline, ThemeData theme, dynamic flow) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: polyline.isNotEmpty 
          ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: polyline.first,
                zoom: 12,
              ),
              polylines: {
                // Main route polyline with enhanced styling
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: polyline,
                  color: theme.colorScheme.primary,
                  width: 8,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                  patterns: [
                    PatternItem.dot,
                    PatternItem.gap(10),
                  ],
                ),
                // Background polyline for better visibility
                Polyline(
                  polylineId: const PolylineId('route_background'),
                  points: polyline,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 12,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                ),
              },
              markers: {
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: polyline.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(
                    title: 'Pickup Location',
                    snippet: flow.pickup ?? 'Starting point',
                  ),
                ),
                if (polyline.length > 1)
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: polyline.last,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: InfoWindow(
                      title: 'Destination',
                      snippet: flow.destination ?? 'Drop-off point',
                    ),
                  ),
              },
              onMapCreated: (c) async {
                _mapController = c;
                if (polyline.length > 1) {
                  final bounds = _computeBounds(polyline);
                  await Future.delayed(const Duration(milliseconds: 100));
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 40),
                  );
                }
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              mapToolbarEnabled: false,
            )
          : _buildRouteFallback(theme),
    );
  }

  Widget _buildRouteFallback(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Route Preview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetailsCard(flow, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Route visualization
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pickup
                    Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pickup',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      flow.pickup ?? 'Tour & Taxis, Brussels',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    
                    // Destination
                    Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Destination',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      flow.destination ?? 'Brussels Airport (BRU)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Trip info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: flow.distanceMeters != null 
                      ? '${(flow.distanceMeters! / 1000).toStringAsFixed(1)} km'
                      : 'Calculating...',
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                _InfoItem(
                  icon: Icons.access_time,
                  label: 'Duration',
                  value: flow.durationSeconds != null 
                      ? '${(flow.durationSeconds! / 60).round()} min'
                      : 'Calculating...',
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                _InfoItem(
                  icon: Icons.schedule,
                  label: 'ETA',
                  value: _getEstimatedArrival(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelection(ThemeData theme) {
    final flow = ref.watch(rideFlowProvider);
    const fareService = FareService();
    
    // Get all vehicle types and calculate fares for each
    final vehicles = VehicleTypeInfo.getAllTypes().map((vehicleInfo) {
      double calculatedPrice = 0;
      
      if (flow.distanceMeters != null && flow.durationSeconds != null) {
        calculatedPrice = fareService.estimateByVehicleType(
          distanceMeters: flow.distanceMeters!,
          durationSeconds: flow.durationSeconds!,
          vehicleType: vehicleInfo.type,
        );
      }
      
      return {
        'id': vehicleInfo.id,
        'icon': vehicleInfo.icon,
        'name': vehicleInfo.name,
        'description': vehicleInfo.description,
        'price': calculatedPrice.round(),
        'time': vehicleInfo.estimatedArrivalTime,
        'pricePerKm': vehicleInfo.pricePerKm,
      };
    }).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Vehicle',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...vehicles.map((vehicle) => _VehicleSelectionTile(
            vehicle: vehicle,
            isSelected: _selectedVehicle == vehicle['id'],
            onTap: () => setState(() => _selectedVehicle = vehicle['id'] as String),
          )),
        ],
      ),
    );
  }

  Widget _buildPaymentSelection(ThemeData theme) {
    final paymentMethods = [
      {
        'id': 'cash',
        'icon': Icons.money,
        'name': 'Cash',
        'description': 'Pay with cash'
      },
      {
        'id': 'card',
        'icon': Icons.credit_card,
        'name': 'Credit Card',
        'description': 'Visa •••• 1234'
      },
      {
        'id': 'wallet',
        'icon': Icons.account_balance_wallet,
        'name': 'TourTaxi Wallet',
        'description': 'Balance: KSh 2,500'
      },
    ];
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...paymentMethods.map((method) => _PaymentMethodTile(
            method: method,
            isSelected: _selectedPayment == method['id'],
            onTap: () => setState(() => _selectedPayment = method['id'] as String),
          )),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown(flow, ThemeData theme) {
    const fareService = FareService();
    FareBreakdown? fareBreakdown;
    
    // Calculate detailed fare breakdown if distance and duration are available
    if (flow.distanceMeters != null && flow.durationSeconds != null && _selectedVehicle.isNotEmpty) {
      final vehicleType = VehicleTypeInfo.getTypeById(_selectedVehicle);
      if (vehicleType != null) {
        fareBreakdown = fareService.getFareBreakdown(
          distanceMeters: flow.distanceMeters!,
          durationSeconds: flow.durationSeconds!,
          vehicleType: vehicleType,
        );
      }
    }
    
    // Fallback values if breakdown not available
    final baseFare = fareBreakdown?.baseFare ?? 50.0;
    final distanceFare = fareBreakdown?.distanceFare ?? 0.0;
    final timeFare = fareBreakdown?.timeFare ?? 0.0;
    final total = fareBreakdown?.total ?? (flow.estimatedFare ?? 200).toDouble();
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (fareBreakdown != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${fareBreakdown.distance.toStringAsFixed(1)} km',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          _PriceRow('Base fare', baseFare, theme),
          const SizedBox(height: 8),
          if (fareBreakdown != null && distanceFare > 0) ...[
            _PriceRow(
              'Distance (${fareBreakdown.distance.toStringAsFixed(1)} km @ KSh${VehicleTypeInfo.getInfo(fareBreakdown.vehicleType).pricePerKm}/km)',
              distanceFare,
              theme,
            ),
            const SizedBox(height: 8),
          ],
          if (fareBreakdown != null && timeFare > 0) ...[
            _PriceRow(
              'Time (${fareBreakdown.duration.toStringAsFixed(0)} min)',
              timeFare,
              theme,
            ),
            const SizedBox(height: 8),
          ],
          
          const SizedBox(height: 8),
          
          Container(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'KSh ${total.toStringAsFixed(0)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(flow) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final rideId = ref.read(rideFlowProvider).rideId;
                  if (rideId != null) {
                    await RideService(Supabase.instance.client)
                        .cancelRide(rideId: rideId, reason: 'Passenger cancelled');
                  }
                  if (mounted) Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => _confirmRide(flow),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm Ride',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEstimatedArrival() {
    final flow = ref.watch(rideFlowProvider);
    final now = DateTime.now();
    
    // Use real duration if available, otherwise use default
    final durationMinutes = flow.durationSeconds != null 
        ? (flow.durationSeconds! / 60).round()
        : 25;
    
    // Add 5 minutes for pickup time
    final totalMinutes = durationMinutes + 5;
    final arrival = now.add(Duration(minutes: totalMinutes));
    
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmRide(flow) async {
    try {
      final service = ref.read(rideServiceProvider);
      final f = ref.read(rideFlowProvider);
      
      // Use default values if data is missing (for demo purposes)
      final pickupLatLng = f.pickupLatLng ?? {'lat': 50.8503, 'lng': 4.3517}; // Brussels coordinates
      final destinationLatLng = f.destinationLatLng ?? {'lat': 50.9014, 'lng': 4.4844}; // Brussels Airport
      final distanceMeters = f.distanceMeters ?? 12500.0;
      final durationSeconds = f.durationSeconds ?? 1500.0;
      final estimatedFare = f.estimatedFare ?? 850.0;
      
      // Show loading state
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      final rideId = await service.createRide(
        passengerName: 'John Doe', // In real app, get from user profile
        passengerPhone: '+32456789012', // In real app, get from user profile
        pickupLat: pickupLatLng['lat']!,
        pickupLng: pickupLatLng['lng']!,
        pickupAddress: f.pickup ?? 'Tour & Taxis, Brussels',
        destLat: destinationLatLng['lat']!,
        destLng: destinationLatLng['lng']!,
        destAddress: f.destination ?? 'Brussels Airport (BRU)',
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        fare: estimatedFare,
      );
      
      // Set the ride ID in both providers
      ref.read(rideFlowProvider.notifier).setRideId(rideId);
      ref.read(rideRealtimeProvider.notifier).setRideId(rideId);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pushNamed('/searching');
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ride: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  LatLngBounds _computeBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      if (minLat == null || p.latitude < minLat) minLat = p.latitude;
      if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
      if (minLng == null || p.longitude < minLng) minLng = p.longitude;
      if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLng ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLng ?? 0),
    );
  }
}

// Helper Widgets
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _VehicleSelectionTile extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _VehicleSelectionTile({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Text(
              vehicle['icon'] as String,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle['name'] as String,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    vehicle['description'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KSh ${vehicle['price']}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  vehicle['time'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final Map<String, dynamic> method;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _PaymentMethodTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              method['icon'] as IconData,
              color: isSelected 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['name'] as String,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    method['description'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final ThemeData theme;
  
  const _PriceRow(this.label, this.amount, this.theme);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Text(
          'KSh ${amount.toStringAsFixed(0)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


