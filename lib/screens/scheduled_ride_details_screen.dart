import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import 'dart:async';
import '../services/directions_service.dart';

class ScheduledRideDetailsScreen extends StatefulWidget {
  final String rideId;

  const ScheduledRideDetailsScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<ScheduledRideDetailsScreen> createState() => _ScheduledRideDetailsScreenState();
}

class _ScheduledRideDetailsScreenState extends State<ScheduledRideDetailsScreen> {
  late Future<Map<String, dynamic>> _rideFuture;
  GoogleMapController? _mapController;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription? _realtimeSub;
  Set<Polyline> polylines = {};

  @override
  void initState() {
    super.initState();
    dev.log('🚀 ScheduledRideDetailsScreen init with rideId: ${widget.rideId}');
    _rideFuture = _fetchRide();
    _setupRealtimeListener();
  }

  Future<Map<String, dynamic>> _fetchRide() async {
    try {
      dev.log('🔍 Fetching ride with ID: ${widget.rideId}');
      
      // Fetch ride data
      final rideOnly = await Supabase.instance.client
          .from('scheduled_rides')
          .select()
          .eq('id', widget.rideId)
          .maybeSingle();
      
      dev.log('📊 Ride data: $rideOnly');
      
      if (rideOnly == null) {
        dev.log('❌ Ride not found with ID: ${widget.rideId}');
        throw Exception('Ride with ID ${widget.rideId} not found');
      }
      
      // If ride has driver_id, fetch driver separately
      if (rideOnly['driver_id'] != null) {
        try {
          final driver = await Supabase.instance.client
              .from('drivers')
              .select()
              .eq('id', rideOnly['driver_id'])
              .maybeSingle();
          
          if (driver != null) {
            rideOnly['drivers'] = driver;
            dev.log('✅ Fetched driver: $driver');
          }
        } catch (e) {
          dev.log('⚠️ Could not fetch driver: $e');
          // Continue without driver data
        }
      }
      
      dev.log('✅ Fetched ride complete: $rideOnly');
      return rideOnly;
    } catch (e) {
      dev.log('❌ Error fetching ride: $e');
      rethrow;
    }
  }

  void _setupRealtimeListener() {
    try {
      dev.log('\n========== 📡 SETUP REALTIME LISTENER START ==========');
      dev.log('🔘 Setting up realtime listener for ride: ${widget.rideId}');
      
      _realtimeChannel = Supabase.instance.client
          .channel('scheduled_ride_${widget.rideId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'scheduled_rides',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.rideId,
            ),
            callback: (payload) {
              dev.log('\n=== 📡 REALTIME UPDATE RECEIVED ===');
              dev.log('Event: ${payload.eventType}');
              dev.log('Table: ${payload.table}');
              dev.log('Schema: ${payload.schema}');
              dev.log('Old Record: ${payload.oldRecord}');
              dev.log('New Record: ${payload.newRecord}');
              
              if (mounted) {
                final newStatus = payload.newRecord['status'] as String? ?? '';
                final oldStatus = payload.oldRecord['status'] as String? ?? '';
                
                dev.log('🔄 Status change: "$oldStatus" → "$newStatus"');
                dev.log('Is completed? ${newStatus == 'completed'}');
                dev.log('Old was not completed? ${oldStatus != 'completed'}');
                
                setState(() {
                  _rideFuture = Future.value(payload.newRecord);
                });
                
                // If ride is completed, show a brief message then navigate to payments
                if (newStatus == 'completed') {
                  dev.log('✅ ✅ ✅ RIDE COMPLETED - SHOULD NAVIGATE NOW ✅ ✅ ✅');
                  _navigateToPayment(payload.newRecord);
                }
              } else {
                dev.log('⚠️ Widget not mounted - ignoring realtime update');
              }
              dev.log('=== 📡 REALTIME UPDATE PROCESSED ===\n');
            },
          )
          .subscribe();
      
      dev.log('✅ Realtime listener subscribed for ride: ${widget.rideId}');
      dev.log('========== 📡 SETUP REALTIME LISTENER END ==========\n');
      
      // Start polling as backup in case realtime fails
      _startPolling();
    } catch (e) {
      dev.log('❌ Error setting up realtime listener: $e');
      // Start polling if realtime fails
      _startPolling();
    }
  }
  
  Timer? _pollingTimer;
  
  String? _lastKnownStatus;
  
  void _startPolling() {
    dev.log('🔄 Starting polling as backup for realtime updates');
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final rideData = await Supabase.instance.client
            .from('scheduled_rides')
            .select()
            .eq('id', widget.rideId)
            .maybeSingle();
        
        if (rideData != null && mounted) {
          final currentStatus = rideData['status'] as String?;
          
          // Only log and update if status changed
          if (currentStatus != _lastKnownStatus) {
            dev.log('🔄 Polling: Status changed from $_lastKnownStatus to $currentStatus');
            _lastKnownStatus = currentStatus;
            
            // Fetch driver data if available
            if (rideData['driver_id'] != null) {
              try {
                final driver = await Supabase.instance.client
                    .from('drivers')
                    .select()
                    .eq('id', rideData['driver_id'])
                    .maybeSingle();
                
                if (driver != null) {
                  rideData['drivers'] = driver;
                }
              } catch (e) {
                dev.log('⚠️ Could not fetch driver during polling: $e');
              }
            }
            
            if (currentStatus == 'completed') {
              timer.cancel();
              dev.log('✅ Polling detected completed status - navigating to payment');
              setState(() {
                _rideFuture = Future.value(rideData);
              });
              _navigateToPayment(rideData);
            } else {
              // Only update state if status changed to avoid rebuilding
              setState(() {
                _rideFuture = Future.value(rideData);
              });
            }
          }
        }
      } catch (e) {
        dev.log('⚠️ Polling error: $e');
      }
    });
  }
  
  void _navigateToPayment(Map<String, dynamic> rideData) {
    // Show completion message immediately
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Ride completed! Proceeding to payment...'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    }
    
    // Navigate with small delay to ensure UI is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        dev.log('🚀 NAVIGATING TO PAYMENT SCREEN NOW');
        final fare = (rideData['estimated_fare'] as num?)?.toDouble() ?? 0.0;
        dev.log('Fare: $fare');
        Navigator.of(context).pushReplacementNamed(
          '/payments',
          arguments: {
            'rideId': widget.rideId,
            'fare': fare,
            'rideType': 'scheduled',
          },
        );
      } else {
        dev.log('⚠️ Cannot navigate - widget not mounted');
      }
    });
  }

  void _updateCameraPosition(GoogleMapController controller, double pickupLat, double pickupLng, double destLat, double destLng) {
    if (pickupLat != 0 && pickupLng != 0 && destLat != 0 && destLng != 0) {
      // If both coordinates are valid, fit bounds
      final bounds = LatLngBounds(
        southwest: LatLng(
          pickupLat < destLat ? pickupLat : destLat,
          pickupLng < destLng ? pickupLng : destLng,
        ),
        northeast: LatLng(
          pickupLat > destLat ? pickupLat : destLat,
          pickupLng > destLng ? pickupLng : destLng,
        ),
      );
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
      // Fetch route polyline
      _fetchAndDrawRoute(pickupLat, pickupLng, destLat, destLng);
    } else if (pickupLat != 0 && pickupLng != 0) {
      // Only pickup coordinates available
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pickupLat, pickupLng), 15));
    }
  }
  
  Future<void> _fetchAndDrawRoute(double pickupLat, double pickupLng, double destLat, double destLng) async {
    try {
      // Google Maps API Key
      const apiKey = 'AIzaSyBRYPKaXlRhpzoAmM5-KrS2JaNDxAX_phw';
      final directionsService = DirectionsService(apiKey);
      
      final result = await directionsService.routeLatLng(
        pickupLat,
        pickupLng,
        destLat,
        destLng,
      );
      
      if (result != null && mounted) {
        // Convert polyline points to LatLng
        final points = result.polyline.map((p) => LatLng(p[0], p[1])).toList();
        
        setState(() {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: Colors.blue,
              width: 5,
              geodesic: true,
            ),
          );
        });
        
        dev.log('✅ Route polyline drawn with ${points.length} points');
      } else if (result == null) {
        dev.log('⚠️ Could not fetch route from directions API');
      }
    } catch (e) {
      dev.log('❌ Error fetching route: $e');
    }
  }

  Set<Marker> _buildMarkers(double pickupLat, double pickupLng, double destLat, double destLng) {
    Set<Marker> markers = {};
    
    if (pickupLat != 0 && pickupLng != 0) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickupLat, pickupLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );
    }
    
    if (destLat != 0 && destLng != 0) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat, destLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }
    
    return markers;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController?.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _realtimeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Ride'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _rideFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            dev.log('❌ Error in FutureBuilder: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ride not found (${widget.rideId})'),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final ride = snapshot.data!;
          final status = ride['status'] as String;
          
          // Handle driver data - could be null, object, or list
          var driverName = 'Driver pending...';
          if (ride['drivers'] != null) {
            if (ride['drivers'] is List && (ride['drivers'] as List).isNotEmpty) {
              driverName = (ride['drivers'] as List)[0]['name'] ?? 'Driver pending...';
            } else if (ride['drivers'] is Map) {
              driverName = ride['drivers']['name'] ?? 'Driver pending...';
            }
          }
          
          // Handle location data with null checks
          double pickupLat = 0.0;
          double pickupLng = 0.0;
          double destLat = 0.0;
          double destLng = 0.0;
          
          try {
            if (ride['pickup_latitude'] != null) {
              pickupLat = (ride['pickup_latitude'] as num).toDouble();
            }
            if (ride['pickup_longitude'] != null) {
              pickupLng = (ride['pickup_longitude'] as num).toDouble();
            }
            if (ride['destination_latitude'] != null) {
              destLat = (ride['destination_latitude'] as num).toDouble();
            }
            if (ride['destination_longitude'] != null) {
              destLng = (ride['destination_longitude'] as num).toDouble();
            }
          } catch (e) {
            dev.log('Error parsing coordinates: $e');
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver info
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Text(driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D'),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _getStatusText(status),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Map
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: (pickupLat != 0 && pickupLng != 0) 
                            ? LatLng(pickupLat, pickupLng)
                            : const LatLng(-1.2921, 36.8219), // Default to Nairobi
                          zoom: 14,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _updateCameraPosition(controller, pickupLat, pickupLng, destLat, destLng);
                        },
                        markers: _buildMarkers(pickupLat, pickupLng, destLat, destLng),
                        polylines: polylines,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // OTP and route info
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip OTP',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ride['otp'] ?? '----',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'From: ${ride['pickup_location']}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'To: ${ride['destination_location']}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled':
        return 'Looking for driver...';
      case 'confirmed':
        return 'Driver accepted';
      case 'in_progress':
        return 'Ride in progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
