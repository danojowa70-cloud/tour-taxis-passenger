import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/ride_flow_providers.dart';
import '../providers/socket_ride_providers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as dev;
import 'dart:async';
import 'dart:ui' as ui;
import '../services/socket_service.dart';
import 'package:geolocator/geolocator.dart';
import '../services/directions_service.dart';
import '../config/env.dart';

class RideDetailsScreen extends ConsumerStatefulWidget {
  const RideDetailsScreen({super.key});

  @override
  ConsumerState<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends ConsumerState<RideDetailsScreen> {
  RealtimeChannel? _realtime;
  RealtimeChannel? _driverLocationChannel;
  StreamSubscription? _socketDriverLocSub;
  StreamSubscription? _socketAcceptedSub;
  StreamSubscription? _socketOtpSub;
  StreamSubscription? _socketStartedSub;
  StreamSubscription? _socketCompletedSub;
  StreamSubscription? _socketCancelledSub;
  GoogleMapController? _mapController;
  LatLng? _driverLatLng;
  String? _driverName;
  String? _driverCar;
  String? _driverPhone;
  String? _driverImage;
  double? _driverRating;
  String? _vehicleNumber;
  String? _vehicleType; // bike, car, auto, etc.
  double _driverHeading = 0.0; // Direction driver is facing
  BitmapDescriptor? _driverMarkerIcon;
  bool _isLoading = true;
  bool _locationPermissionGranted = false;
  Timer? _markerAnimationTimer;

  // Ride state
  bool _driverArrived = false;
  bool _rideStarted = false;
  Timer? _routeDebounce;
  List<LatLng> _dynamicRoute = const [];
  String? _rideOtp;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    
    // Initialize with delay to ensure provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final rideId = ref.read(rideFlowProvider).rideId;
      if (rideId == null || rideId.isEmpty) {
        dev.log('ERROR: No ride ID found in provider!', name: 'RideDetailsScreen');
        _showErrorAndGoBack('Ride information not found');
        return;
      }
      
      // Try to get driver info from socket state first
      _loadDriverFromSocketState();
      
      _fetchRideAndDriverData(rideId);
      _setupRealtimeListeners(rideId);
      _setupSocketListeners();
      _loadOtp(rideId);
    });
  }
  
  Future<void> _checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    setState(() {
      _locationPermissionGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });
  }

  Future<void> _fetchRideAndDriverData(String rideId) async {
    if (!mounted) return;
    
    try {
      dev.log('Fetching ride and driver data for ride: $rideId', name: 'RideDetailsScreen');
      
      // Fetch ride data with error handling
      final rideResponse = await Supabase.instance.client
          .from('rides')
          .select('*, drivers(*)')
          .eq('id', rideId)
          .maybeSingle();
      
      if (rideResponse == null) {
        dev.log('ERROR: Ride not found in database', name: 'RideDetailsScreen');
        if (mounted) {
          _showErrorAndGoBack('Ride not found');
        }
        return;
      }
      
      dev.log('🔍 RIDE DATA FETCHED: $rideResponse', name: 'RideDetailsScreen');
      dev.log('🔍 RIDE STATUS: ${rideResponse['status']}', name: 'RideDetailsScreen');
      dev.log('🔍 DRIVERS DATA: ${rideResponse['drivers']}', name: 'RideDetailsScreen');
      
      // Check ride status - if cancelled, go back
      final rideStatus = rideResponse['status'] as String?;
      if (rideStatus == 'cancelled') {
        dev.log('Ride was cancelled', name: 'RideDetailsScreen');
        if (mounted) {
          _showErrorAndGoBack('This ride has been cancelled');
        }
        return;
      }
      
      final driverId = rideResponse['driver_id'] as String?;
      dev.log('🔍 Driver ID from ride: $driverId', name: 'RideDetailsScreen');
      
      // Try to get driver data from the joined drivers table
      final driversData = rideResponse['drivers'];
      dev.log('🔍 Joined drivers data: $driversData', name: 'RideDetailsScreen');
      
      // Also try to get driver data from the ride table itself (for completed rides)
      final rideDriverName = rideResponse['driver_name'] as String?;
      final rideDriverPhone = rideResponse['driver_phone'] as String?;
      dev.log('🔍 Driver info from ride table: name=$rideDriverName, phone=$rideDriverPhone', name: 'RideDetailsScreen');
      
      // First, try to use the joined drivers data if available
      if (driversData != null && driversData is Map) {
        dev.log('🎯 Using joined drivers data', name: 'RideDetailsScreen');
        if (mounted) {
          setState(() {
            _driverName = driversData['name'] as String? ?? rideDriverName;
            _driverPhone = driversData['phone'] as String? ?? rideDriverPhone;
            _driverRating = (driversData['rating'] as num?)?.toDouble() ?? 4.5;
            _driverImage = driversData['profile_image'] as String?;
            
            final make = driversData['vehicle_make']?.toString().trim() ?? '';
            final model = driversData['vehicle_model']?.toString().trim() ?? '';
            _driverCar = '$make $model'.trim();
            if (_driverCar == null || _driverCar!.isEmpty) {
              _driverCar = driversData['vehicle_type'] as String? ?? 'Vehicle';
            }
            
            _vehicleNumber = driversData['vehicle_number'] as String?;
            _vehicleType = (driversData['vehicle_type'] as String?)?.toLowerCase();
            
            final lat = (driversData['current_latitude'] as num?)?.toDouble();
            final lng = (driversData['current_longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _driverLatLng = LatLng(lat, lng);
            }
            
            dev.log('✅ Vehicle type set to: $_vehicleType', name: 'RideDetailsScreen');
            
            _isLoading = false;
            
            dev.log('✅ Set driver name from joined data: $_driverName', name: 'RideDetailsScreen');
          });
        }
      } else if (driverId != null && driverId.isNotEmpty) {
        // Fetch driver data separately if join didn't work
        dev.log('📡 Fetching driver separately with ID: $driverId', name: 'RideDetailsScreen');
        try {
          final driver = await Supabase.instance.client
              .from('drivers')
              .select('*')
              .eq('id', driverId)
              .single();
          
          dev.log('✅ Driver data from drivers table: $driver', name: 'RideDetailsScreen');
          
          if (mounted) {
            setState(() {
              // Use driver data from drivers table, fallback to ride table
              _driverName = driver['name'] as String? ?? rideDriverName;
              _driverPhone = driver['phone'] as String? ?? rideDriverPhone;
              
              dev.log('Set driver name: $_driverName', name: 'RideDetailsScreen');
              
              // Safe vehicle name construction
              final make = driver['vehicle_make']?.toString().trim() ?? '';
              final model = driver['vehicle_model']?.toString().trim() ?? '';
              _driverCar = '$make $model'.trim();
              if (_driverCar == null || _driverCar!.isEmpty) {
                _driverCar = driver['vehicle_type'] as String? ?? 'Vehicle';
              }
              
              _vehicleNumber = driver['vehicle_number'] as String?;
              _vehicleType = (driver['vehicle_type'] as String?)?.toLowerCase();
              _driverRating = (driver['rating'] as num?)?.toDouble() ?? 4.5;
              _driverImage = driver['profile_image'] as String?;
              
              dev.log('✅ Vehicle type set to: $_vehicleType', name: 'RideDetailsScreen');
              
              // Set initial driver location
              final lat = (driver['current_latitude'] as num?)?.toDouble();
              final lng = (driver['current_longitude'] as num?)?.toDouble();
              if (lat != null && lng != null) {
                _driverLatLng = LatLng(lat, lng);
              }
              
              _isLoading = false;
            });
          }
        } catch (driverError) {
          dev.log('Error fetching driver: $driverError', name: 'RideDetailsScreen');
          // Don't fail completely if driver fetch fails - socket might provide the data
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        // Driver not yet assigned, but check if we have driver info in ride table
        // This can happen for completed rides where driver_id might be missing
        dev.log('❌ Driver ID is null, checking ride table for driver info', name: 'RideDetailsScreen');
        if (mounted) {
          setState(() {
            if (rideDriverName != null && rideDriverName.isNotEmpty) {
              _driverName = rideDriverName;
              _driverPhone = rideDriverPhone;
              dev.log('✅ Using driver data from ride table: $_driverName', name: 'RideDetailsScreen');
            } else {
              dev.log('⚠️ NO DRIVER INFO FOUND ANYWHERE!', name: 'RideDetailsScreen');
            }
            _isLoading = false;
          });
        }
      }
      
      // AGGRESSIVE FALLBACK: If we still don't have a driver name after all attempts,
      // try one more time to fetch from rides table
      if (mounted && (_driverName == null || _driverName == 'Driver pending…')) {
        dev.log('🚨 DRIVER NAME STILL NULL, trying emergency fetch', name: 'RideDetailsScreen');
        await _emergencyFetchDriverName(rideId);
      }
    } catch (e, stackTrace) {
      dev.log('Error fetching ride/driver data: $e', name: 'RideDetailsScreen');
      dev.log('Stack trace: $stackTrace', name: 'RideDetailsScreen');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load ride details. Retrying...');
        
        // Retry after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _fetchRideAndDriverData(rideId);
          }
        });
      }
    }
  }
  
  void _loadDriverFromSocketState() {
    try {
      final socketRide = ref.read(socketRideProvider).currentRide;
      
      if (socketRide != null) {
        dev.log('🎯 Loading driver info from socket state', name: 'RideDetailsScreen');
        dev.log('Socket ride: ${socketRide.driverName}, ${socketRide.driverPhone}', name: 'RideDetailsScreen');
        
        if (socketRide.driverName != null && socketRide.driverName!.isNotEmpty) {
          setState(() {
            _driverName = socketRide.driverName;
            _driverPhone = socketRide.driverPhone;
            _driverRating = socketRide.driverRating?.toDouble();
            _driverImage = socketRide.driverImage;
            _driverCar = socketRide.driverVehicle;
            _vehicleNumber = socketRide.driverVehicleNumber;
            
            if (socketRide.driverLatitude != null && socketRide.driverLongitude != null) {
              _driverLatLng = LatLng(socketRide.driverLatitude!, socketRide.driverLongitude!);
            }
            
            _isLoading = false;
            
            dev.log('✅ Loaded driver from socket: $_driverName', name: 'RideDetailsScreen');
          });
        }
      } else {
        dev.log('⚠️ No socket ride data available', name: 'RideDetailsScreen');
      }
    } catch (e) {
      dev.log('❌ Error loading driver from socket: $e', name: 'RideDetailsScreen');
    }
  }
  
  Future<void> _emergencyFetchDriverName(String rideId) async {
    if (!mounted) return;
    
    try {
      dev.log('🆘 Emergency fetch: Getting ride with driver join', name: 'RideDetailsScreen');
      
      // Try to get the ride with driver_id
      final rideResponse = await Supabase.instance.client
          .from('rides')
          .select('driver_id')
          .eq('id', rideId)
          .maybeSingle();
      
      if (rideResponse == null || !mounted) {
        dev.log('❌ Emergency fetch: No ride found', name: 'RideDetailsScreen');
        return;
      }
      
      final driverId = rideResponse['driver_id'] as String?;
      dev.log('🆘 Emergency fetch: driver_id = $driverId', name: 'RideDetailsScreen');
      
      if (driverId != null && driverId.isNotEmpty) {
        // Fetch driver directly
        try {
          final driverResponse = await Supabase.instance.client
              .from('drivers')
              .select('name, phone, rating, profile_image, vehicle_make, vehicle_model, vehicle_type, vehicle_number')
              .eq('id', driverId)
              .single();
          
          dev.log('✅ Emergency fetch SUCCESS: $driverResponse', name: 'RideDetailsScreen');
          
          if (mounted) {
            setState(() {
              _driverName = driverResponse['name'] as String? ?? 'Driver';
              _driverPhone = driverResponse['phone'] as String?;
              _driverRating = (driverResponse['rating'] as num?)?.toDouble() ?? 4.5;
              _driverImage = driverResponse['profile_image'] as String?;
              
              final make = driverResponse['vehicle_make']?.toString().trim() ?? '';
              final model = driverResponse['vehicle_model']?.toString().trim() ?? '';
              final combined = '$make $model'.trim();
              if (combined.isNotEmpty) {
                _driverCar = combined;
              } else {
                _driverCar = driverResponse['vehicle_type'] as String? ?? 'Vehicle';
              }
              
              _vehicleNumber = driverResponse['vehicle_number'] as String?;
              
              dev.log('✅ Emergency fetch: Set driver name to: $_driverName', name: 'RideDetailsScreen');
            });
          }
        } catch (e) {
          dev.log('❌ Emergency fetch: Error fetching driver: $e', name: 'RideDetailsScreen');
        }
      } else {
        dev.log('❌ Emergency fetch: No driver_id in ride', name: 'RideDetailsScreen');
      }
    } catch (e) {
      dev.log('❌ Emergency fetch failed: $e', name: 'RideDetailsScreen');
    }
  }
  
  Future<void> _fetchDriverFromRidesTable(String rideId) async {
    if (!mounted) return;
    
    try {
      dev.log('Fetching driver info from rides table for ride: $rideId', name: 'RideDetailsScreen');
      
      final rideResponse = await Supabase.instance.client
          .from('rides')
          .select('driver_id, driver_name, driver_phone')
          .eq('id', rideId)
          .maybeSingle();
      
      if (rideResponse == null || !mounted) return;
      
      final driverId = rideResponse['driver_id'] as String?;
      final rideDriverName = rideResponse['driver_name'] as String?;
      final rideDriverPhone = rideResponse['driver_phone'] as String?;
      
      dev.log('Fetched driver info: id=$driverId, name=$rideDriverName, phone=$rideDriverPhone', name: 'RideDetailsScreen');
      
      // If we have a driver ID, fetch full driver details
      if (driverId != null && driverId.isNotEmpty) {
        try {
          final driver = await Supabase.instance.client
              .from('drivers')
              .select('*')
              .eq('id', driverId)
              .single();
          
          if (mounted) {
            setState(() {
              _driverName = driver['name'] as String? ?? rideDriverName ?? _driverName;
              _driverPhone = driver['phone'] as String? ?? rideDriverPhone ?? _driverPhone;
              _driverRating = (driver['rating'] as num?)?.toDouble() ?? _driverRating;
              _driverImage = driver['profile_image'] as String? ?? _driverImage;
              
              final make = driver['vehicle_make']?.toString().trim() ?? '';
              final model = driver['vehicle_model']?.toString().trim() ?? '';
              final combined = '$make $model'.trim();
              if (combined.isNotEmpty) {
                _driverCar = combined;
              } else {
                _driverCar = driver['vehicle_type'] as String? ?? _driverCar;
              }
              
              _vehicleNumber = driver['vehicle_number'] as String? ?? _vehicleNumber;
              
              dev.log('Updated driver name from fallback fetch: $_driverName', name: 'RideDetailsScreen');
            });
          }
        } catch (driverError) {
          dev.log('Error fetching driver from drivers table: $driverError', name: 'RideDetailsScreen');
          // Fall back to ride table data
          if (mounted && (rideDriverName != null && rideDriverName.isNotEmpty)) {
            setState(() {
              _driverName = rideDriverName;
              _driverPhone = rideDriverPhone;
              dev.log('Using driver data from rides table: $_driverName', name: 'RideDetailsScreen');
            });
          }
        }
      } else if (rideDriverName != null && rideDriverName.isNotEmpty) {
        // No driver ID but we have driver info in rides table
        if (mounted) {
          setState(() {
            _driverName = rideDriverName;
            _driverPhone = rideDriverPhone;
            dev.log('Using driver data from rides table (no driver_id): $_driverName', name: 'RideDetailsScreen');
          });
        }
      }
    } catch (e) {
      dev.log('Error in _fetchDriverFromRidesTable: $e', name: 'RideDetailsScreen');
    }
  }

  void _setupRealtimeListeners(String rideId) {
    // Listen to ride_events for ride status changes
    _realtime = Supabase.instance.client
        .channel('public:ride_events')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final type = (row['event_type'] ?? '') as String;
            if (!mounted) return;
            
            dev.log('Received ride event: $type', name: 'RideDetailsScreen');
            
            if (type == 'ride:accepted') {
              final rideId = row['ride_id'] as String? ?? ref.read(rideFlowProvider).rideId;
              if (rideId != null) {
                _loadOtp(rideId);
                // Refetch complete driver data when ride is accepted
                _fetchRideAndDriverData(rideId);
              }
              final data = row['payload'] as Map<String, dynamic>?;
              if (data != null) {
                setState(() {
                  _isLoading = false; // Ensure loading state is cleared
                  
                  // Extract driver name from multiple possible fields
                  _driverName = data['driver_name'] as String? ?? 
                               data['name'] as String? ?? 
                               _driverName ?? 
                               'Driver';
                  
                  // Extract vehicle info
                  _driverCar = data['driver_car'] as String? ?? 
                              data['vehicle_type'] as String? ?? 
                              _driverCar;
                  
                  _driverPhone = data['driver_phone'] as String? ?? 
                                data['phone'] as String? ?? 
                                _driverPhone;
                  
                  _driverRating = (data['driver_rating'] as num?)?.toDouble() ?? 
                                 (data['rating'] as num?)?.toDouble() ?? 
                                 _driverRating ?? 
                                 4.5;
                  
                  _vehicleNumber = data['vehicle_number'] as String? ?? 
                                  data['vehicle_plate'] as String? ?? 
                                  _vehicleNumber;
                  
                  dev.log('Driver data updated from realtime: name=$_driverName, car=$_driverCar', name: 'RideDetailsScreen');
                });
              }
            } else if (type == 'ride:driver_location') {
              final data = row['payload'] as Map<String, dynamic>?;
              final lat = (data?['lat'] as num?)?.toDouble();
              final lng = (data?['lng'] as num?)?.toDouble();
              if (lat != null && lng != null) {
                final pos = LatLng(lat, lng);
                setState(() {
                  _driverLatLng = pos;
                  
                  // Extract driver metadata if available and not yet set
                  if (data != null && data['driver_name'] != null && (_driverName == null || _driverName == 'Driver pending…')) {
                    _driverName = data['driver_name'] as String?;
                    dev.log('Set driver name from ride:driver_location: $_driverName', name: 'RideDetailsScreen');
                  }
                  if (data != null && data['driver_phone'] != null && _driverPhone == null) {
                    _driverPhone = data['driver_phone'] as String?;
                  }
                });
                _maybeMarkArrived();
                _debouncedRecalculateRoute();
                _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
              }
            } else if (type == 'ride:otp_issued') {
              final data = row['payload'] as Map<String, dynamic>?;
              final otp = data?['otp']?.toString();
              if (mounted && otp != null && otp.isNotEmpty) {
                setState(() => _rideOtp = otp);
              }
            } else if (type == 'ride:started') {
              if (mounted) {
                setState(() => _rideStarted = true);
                // recompute route to destination
                _recalculateRoute();
                dev.log('Ride started!', name: 'RideDetailsScreen');
              }
            } else if (type == 'ride:completed' || type == 'ride:end') {
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/payments');
              }
            }
          },
        )
        .subscribe();
    
  // Listen to drivers table for real-time location updates
    _driverLocationChannel = Supabase.instance.client
        .channel('driver_location_$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          callback: (payload) {
            final row = payload.newRecord;
            if (!mounted) return;
            
            final lat = (row['current_latitude'] as num?)?.toDouble();
            final lng = (row['current_longitude'] as num?)?.toDouble();
            
            if (lat != null && lng != null) {
              final pos = LatLng(lat, lng);
              dev.log('Driver location updated: $lat, $lng', name: 'RideDetailsScreen');
              setState(() {
                _driverLatLng = pos;
                
                // If we have location but don't have driver name yet, populate it from this update
                if (_driverName == null || _driverName == 'Driver pending…') {
                  _driverName = row['name'] as String? ?? _driverName;
                  _driverPhone = row['phone'] as String? ?? _driverPhone;
                  _driverRating = (row['rating'] as num?)?.toDouble() ?? _driverRating;
                  _driverImage = row['profile_image'] as String? ?? _driverImage;
                  
                  final make = row['vehicle_make']?.toString().trim() ?? '';
                  final model = row['vehicle_model']?.toString().trim() ?? '';
                  final combined = '$make $model'.trim();
                  if (combined.isNotEmpty) {
                    _driverCar = combined;
                  } else {
                    _driverCar = row['vehicle_type'] as String? ?? _driverCar;
                  }
                  
                  _vehicleNumber = row['vehicle_number'] as String? ?? _vehicleNumber;
                  
                  dev.log('Populated driver info from location update: name=$_driverName', name: 'RideDetailsScreen');
                  
                  // If still no name after this update, fetch from rides table as fallback
                  if (_driverName == null || _driverName == 'Driver pending…') {
                    dev.log('Still no driver name, fetching from rides table', name: 'RideDetailsScreen');
                    _fetchDriverFromRidesTable(rideId);
                  }
                }
              });
              _maybeMarkArrived();
              _debouncedRecalculateRoute();
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(pos),
              );
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _routeDebounce?.cancel();
    _markerAnimationTimer?.cancel();
    if (_realtime != null) {
      Supabase.instance.client.removeChannel(_realtime!);
    }
    if (_driverLocationChannel != null) {
      Supabase.instance.client.removeChannel(_driverLocationChannel!);
    }
    _socketDriverLocSub?.cancel();
    _socketAcceptedSub?.cancel();
    _socketOtpSub?.cancel();
    _socketStartedSub?.cancel();
    _socketCompletedSub?.cancel();
    _socketCancelledSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupSocketListeners() {
    // Update driver details immediately on acceptance via socket
    _socketAcceptedSub = SocketService.instance.rideAcceptedStream.listen((data) {
      if (!mounted) return;
      dev.log('✅ Received ride_accepted via socket: $data', name: 'RideDetailsScreen');
      dev.log('Socket data keys: ${data.keys.toList()}', name: 'RideDetailsScreen');
      setState(() {
        _isLoading = false; // Clear loading state immediately
        
        // Set driver data from socket event (don't fall back to existing null values)
        if (data['driver_name'] != null) {
          _driverName = data['driver_name']?.toString();
          dev.log('Set driver name from socket: $_driverName', name: 'RideDetailsScreen');
        } else {
          dev.log('⚠️ No driver_name in socket data', name: 'RideDetailsScreen');
        }
        if (data['driver_phone'] != null) {
          _driverPhone = data['driver_phone']?.toString();
        }

        // Prefer make/model if present, otherwise fall back to driver_vehicle or vehicle_type
        final make = (data['driver_vehicle_make'] ?? data['vehicle_make'])?.toString().trim();
        final model = (data['driver_vehicle_model'] ?? data['vehicle_model'])?.toString().trim();
        final vehicleType = (data['driver_vehicle'] ?? data['vehicle_type'])?.toString().trim();
        final combined = [make, model].where((e) => e != null && e.isNotEmpty).join(' ').trim();
        if (combined.isNotEmpty) {
          _driverCar = combined;
        } else if (vehicleType?.isNotEmpty == true) {
          _driverCar = vehicleType;
        }

        if (data['driver_vehicle_number'] != null || data['vehicle_number'] != null) {
          _vehicleNumber = data['driver_vehicle_number'] ?? data['vehicle_number'];
        }
        if (data['driver_rating'] != null) {
          _driverRating = (data['driver_rating'] as num?)?.toDouble() ?? 4.5;
        }
        if (data['driver_image'] != null) {
          _driverImage = data['driver_image']?.toString();
        }
        
        // Also update driver location if available
        final lat = (data['driver_latitude'] as num?)?.toDouble();
        final lng = (data['driver_longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _driverLatLng = LatLng(lat, lng);
          _mapController?.animateCamera(CameraUpdate.newLatLng(_driverLatLng!));
        }
      });
      
      // Also load OTP when ride is accepted
      if (mounted) {
        final rideId = ref.read(rideFlowProvider).rideId;
        if (rideId != null) _loadOtp(rideId);
      }
    });

    // Real-time driver location from socket
    _socketDriverLocSub = SocketService.instance.driverLocationStream.listen((data) async {
      dev.log('📍 Received driver location update via socket: $data', name: 'RideDetailsScreen');
      dev.log('📍 Data keys: ${data.keys.toList()}', name: 'RideDetailsScreen');
      
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      final heading = (data['heading'] as num?)?.toDouble();
      
      dev.log('📍 Parsed location: lat=$lat, lng=$lng, heading=$heading', name: 'RideDetailsScreen');
      
      if (lat != null && lng != null && mounted) {
        final newPos = LatLng(lat, lng);
        final oldPos = _driverLatLng;
        
        dev.log('🚗 Driver location update: $lat, $lng (heading: $heading°)', name: 'RideDetailsScreen');
        dev.log('📍 Distance from old position: ${oldPos != null ? _calculateDistance(oldPos, newPos) : "N/A"} meters', name: 'RideDetailsScreen');
        
        // Update heading if provided
        if (heading != null && heading != _driverHeading) {
          _driverHeading = heading;
          // Regenerate marker icon with new heading
          _driverMarkerIcon = await _createVehicleIcon(_vehicleType, _driverHeading);
          dev.log('🔄 Updated vehicle icon with heading: $heading°', name: 'RideDetailsScreen');
        }
        
        // Animate marker movement smoothly
        if (oldPos != null) {
          _animateMarkerToPosition(oldPos, newPos);
        } else {
          // First location update - create initial icon and set position
          _driverMarkerIcon ??= await _createVehicleIcon(_vehicleType, _driverHeading);
          setState(() {
            _driverLatLng = newPos;
          });
          // Center camera on driver location for first update
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: newPos, zoom: 15),
            ),
          );
          dev.log('🎯 Initial driver location set: $lat, $lng', name: 'RideDetailsScreen');
        }
        
        // Extract driver metadata
        if (data['driver_name'] != null && (_driverName == null || _driverName == 'Driver pending…')) {
          setState(() {
            _driverName = data['driver_name']?.toString();
          });
          dev.log('Set driver name from socket location: $_driverName', name: 'RideDetailsScreen');
        }
        if (data['driver_phone'] != null && _driverPhone == null) {
          setState(() {
            _driverPhone = data['driver_phone']?.toString();
          });
        }
        if (data['driver_rating'] != null && _driverRating == null) {
          setState(() {
            _driverRating = (data['driver_rating'] as num?)?.toDouble();
          });
        }
        
        _maybeMarkArrived();
        _debouncedRecalculateRoute();
        
        // Keep camera following driver if they're moving
        if (oldPos != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(newPos),
          );
        }
        
        dev.log('✅ Driver marker and camera updated successfully', name: 'RideDetailsScreen');
      } else {
        dev.log('⚠️ Invalid location data received: lat=$lat, lng=$lng', name: 'RideDetailsScreen');
      }
    });
    
    // Listen for OTP via socket
    _socketOtpSub = SocketService.instance.rideOtpStream.listen((data) {
      if (!mounted) return;
      dev.log('🔐 Received OTP via socket: $data', name: 'RideDetailsScreen');
      final otp = data['otp']?.toString();
      if (otp != null && otp.isNotEmpty) {
        setState(() => _rideOtp = otp);
      }
    });
    
    // Listen for ride started via socket
    _socketStartedSub = SocketService.instance.rideStartedStream.listen((data) {
      if (!mounted) return;
      dev.log('🏁 Received ride_started via socket: $data', name: 'RideDetailsScreen');
      setState(() {
        _rideStarted = true;
      });
      _recalculateRoute();
    });
    
    // Listen for ride completed via socket
    _socketCompletedSub = SocketService.instance.rideCompletedStream.listen((data) {
      if (!mounted) return;
      dev.log('🏁 Received ride_completed via socket: $data', name: 'RideDetailsScreen');
      Navigator.of(context).pushReplacementNamed('/payments');
    });
    
    // Listen for ride cancelled via socket
    _socketCancelledSub = SocketService.instance.rideCancelledStream.listen((data) {
      if (!mounted) return;
      dev.log('❌ Received ride_cancelled via socket: $data', name: 'RideDetailsScreen');
      final reason = data['reason'] as String? ?? 'Ride was cancelled';
      _showErrorAndGoBack(reason);
    });
  }
  
  void _showErrorAndGoBack(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
  
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final flow = ref.watch(rideFlowProvider);
    
    // Validate coordinates before using them
    LatLng? pickup;
    if (flow.pickupLatLng != null) {
      final lat = flow.pickupLatLng!['lat']!;
      final lng = flow.pickupLatLng!['lng']!;
      if (_isValidCoordinate(lat, lng)) {
        pickup = LatLng(lat, lng);
      } else {
        dev.log('⚠️ Invalid pickup coordinates: $lat, $lng', name: 'RideDetailsScreen');
      }
    }
    
    LatLng? dest;
    if (flow.destinationLatLng != null) {
      final lat = flow.destinationLatLng!['lat']!;
      final lng = flow.destinationLatLng!['lng']!;
      if (_isValidCoordinate(lat, lng)) {
        dest = LatLng(lat, lng);
      } else {
        dev.log('⚠️ Invalid destination coordinates: $lat, $lng', name: 'RideDetailsScreen');
      }
    }
    
    // Log all coordinates for debugging
    dev.log('📍 Current coordinates - Pickup: $pickup, Dest: $dest, Driver: $_driverLatLng', name: 'RideDetailsScreen');
    
    final polyPoints = flow.polyline ?? [];
    final routePolyline = polyPoints.map((p) => LatLng(p[0], p[1])).toList(growable: false);
    final effectivePolyline = _dynamicRoute.isNotEmpty ? _dynamicRoute : routePolyline;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Ride Details'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      child: _driverImage != null 
                        ? ClipOval(child: Image.network(_driverImage!, fit: BoxFit.cover))
                        : const Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _driverName ?? 'Driver pending…', 
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_driverRating != null) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  _driverRating!.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                          Text(_driverCar ?? '—', style: TextStyle(color: subtle)),
                          if (_vehicleNumber != null)
                            Text(_vehicleNumber!, style: TextStyle(color: subtle, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _rideStarted
                            ? 'On Trip'
                            : _driverArrived
                                ? 'Driver Arrived'
                                : 'En route',
                        style: TextStyle(color: subtle, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Half screen map for tracking
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _driverLatLng ?? pickup ?? const LatLng(0,0), 
                      zoom: 14,
                    ),
                    myLocationEnabled: _locationPermissionGranted,
                    myLocationButtonEnabled: _locationPermissionGranted,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    onMapCreated: (c) async {
                      _mapController = c;
                      
                      // Create initial vehicle icon with proper vehicle type
                      if (_driverMarkerIcon == null && _vehicleType != null) {
                        dev.log('🚗 Creating initial vehicle icon for type: $_vehicleType', name: 'RideDetailsScreen');
                        _driverMarkerIcon = await _createVehicleIcon(_vehicleType, _driverHeading);
                        if (mounted) {
                          setState(() {});
                        }
                      }
                      await Future.delayed(const Duration(milliseconds: 300));
                      
                      // Log all coordinates for debugging
                      dev.log('📍 Map coordinates - Pickup: $pickup, Dest: $dest, Driver: $_driverLatLng', name: 'RideDetailsScreen');
                      
                      // Priority: Focus on driver if available, otherwise pickup
                      LatLng? focusPoint = _driverLatLng ?? pickup;
                      
                      if (focusPoint != null) {
                        // Build list of points to fit in view
                        final pointsToFit = <LatLng>[
                          focusPoint,
                          if (_rideStarted) ...[  // After ride starts, show route to destination
                            if (dest != null) dest,
                          ] else ...[  // Before ride starts, show driver to pickup route
                            if (pickup != null) pickup,
                          ],
                          // Include some polyline points for better framing (max 10 for performance)
                          ...effectivePolyline.take(10),
                        ];
                        
                        final bounds = _computeBounds(pointsToFit);
                        if (bounds != null && pointsToFit.length > 1) {
                          // Fit all relevant points in view with padding
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngBounds(bounds, 80),
                          );
                        } else {
                          // Single point - just center and zoom
                          _mapController?.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(target: focusPoint, zoom: 15),
                            ),
                          );
                        }
                      }
                      
                      _recalculateRoute();
                    },
                    markers: {
                      // Always show driver marker if available
                      if (_driverLatLng != null)
                        Marker(
                          markerId: const MarkerId('driver'),
                          position: _driverLatLng!,
                          icon: _driverMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                          rotation: _driverHeading,
                          anchor: const Offset(0.5, 0.5),
                          flat: true,
                          infoWindow: InfoWindow(
                            title: _driverName ?? 'Driver',
                            snippet: '${_vehicleType ?? "Vehicle"} • Heading: ${_driverHeading.toStringAsFixed(0)}°',
                          ),
                        ),
                      // Before ride starts: show pickup location
                      if (!_rideStarted && pickup != null)
                        Marker(
                          markerId: const MarkerId('pickup'),
                          position: pickup,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                          infoWindow: const InfoWindow(title: 'Pickup Location'),
                        ),
                      // After ride starts: show destination
                      if (_rideStarted && dest != null)
                        Marker(
                          markerId: const MarkerId('dest'),
                          position: dest,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          infoWindow: const InfoWindow(title: 'Destination'),
                        ),
                    },
                    polylines: effectivePolyline.isNotEmpty ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: effectivePolyline,
                        color: Colors.black,
                        width: 5,
                        startCap: Cap.roundCap,
                        endCap: Cap.roundCap,
                      ),
                    } : {},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Trip OTP', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(_rideOtp ?? '----', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        if (_driverArrived && !_rideStarted)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Your driver has arrived. Please be ready.', style: TextStyle(color: subtle)),
                          ),
                      ],
                    ),
                    if (_rideStarted)
                      ElevatedButton(
                        onPressed: _endTrip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stop_circle_outlined, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'End Trip',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            flow.destination ?? 'Destination',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (flow.distanceMeters != null && flow.durationSeconds != null)
                            Text(
                              '${(flow.distanceMeters! / 1000).toStringAsFixed(1)} km · ${(flow.durationSeconds! / 60).round()} min ETA',
                              style: TextStyle(color: subtle),
                            ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _driverPhone == null ? null : _callDriver, icon: const Icon(Icons.phone)),
                    IconButton(onPressed: _driverPhone == null ? null : _textDriver, icon: const Icon(Icons.message_outlined)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Animates the driver marker smoothly from old position to new position
  void _animateMarkerToPosition(LatLng from, LatLng to) {
    _markerAnimationTimer?.cancel();
    
    const int steps = 30; // Number of animation frames
    const duration = Duration(milliseconds: 1000); // Total animation duration
    final stepDuration = duration ~/ steps;
    
    int currentStep = 0;
    
    _markerAnimationTimer = Timer.periodic(stepDuration, (timer) {
      if (currentStep >= steps || !mounted) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _driverLatLng = to;
          });
        }
        return;
      }
      
      currentStep++;
      final t = currentStep / steps; // Progress from 0 to 1
      
      // Use ease-out interpolation for smoother animation
      final easeT = 1 - (1 - t) * (1 - t);
      
      final lat = from.latitude + (to.latitude - from.latitude) * easeT;
      final lng = from.longitude + (to.longitude - from.longitude) * easeT;
      
      if (mounted) {
        setState(() {
          _driverLatLng = LatLng(lat, lng);
        });
      }
    });
  }
  
  /// Validate if coordinates are reasonable (not default/placeholder values)
  bool _isValidCoordinate(double lat, double lng) {
    // Check if coordinates are within valid ranges
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    
    // Check if coordinates are not at origin (0,0) - common placeholder
    if (lat == 0 && lng == 0) return false;
    
    // For India-based app, validate coordinates are roughly in India region
    // India bounds: lat 8-37, lng 68-97
    // Allow some buffer for nearby countries
    if (lat < 5 || lat > 40 || lng < 65 || lng > 100) {
      dev.log('⚠️ Coordinates outside expected region: $lat, $lng', name: 'RideDetailsScreen');
      return false;
    }
    
    return true;
  }
  
  /// Calculate distance between two LatLng points using Haversine formula
  double _calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
  
  LatLngBounds? _computeBounds(List<LatLng> pts) {
    if (pts.isEmpty) return null;
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null) ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null) ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null) ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null) ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
  
  /// Create custom 2D vehicle marker based on vehicle type and heading
  Future<BitmapDescriptor> _createVehicleIcon(String? vehicleType, double heading) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 120.0;
    const center = Offset(size / 2, size / 2);
    
    // Save canvas state
    canvas.save();
    
    // Translate to center and rotate based on heading
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * (3.14159 / 180)); // Convert degrees to radians
    canvas.translate(-center.dx, -center.dy);
    
    final type = vehicleType?.toLowerCase() ?? 'car';
    
    // Draw the vehicle based on type
    if (type.contains('bike') || type.contains('motorcycle') || type.contains('scooter')) {
      _drawBike(canvas, center);
    } else if (type.contains('suv')) {
      _drawSUV(canvas, center);
    } else {
      // Default to car
      _drawCar(canvas, center);
    }
    
    // Restore canvas
    canvas.restore();
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
  
  /// Draw a 2D car from top view
  void _drawCar(Canvas canvas, Offset center) {
    // Car body - main rectangle
    final carBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 32, height: 50),
      const Radius.circular(8),
    );
    
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      carBody.shift(const Offset(2, 2)),
      shadowPaint,
    );
    
    // Car body fill - blue
    final bodyPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(carBody, bodyPaint);
    
    // Car body outline
    final outlinePaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(carBody, outlinePaint);
    
    // Windshield (front)
    final windshield = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 12),
        width: 24,
        height: 14,
      ),
      const Radius.circular(4),
    );
    final windshieldPaint = Paint()
      ..color = const Color(0xFF64B5F6)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(windshield, windshieldPaint);
    
    // Rear windshield
    final rearWindow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 12),
        width: 24,
        height: 12,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(rearWindow, windshieldPaint);
    
    // Headlights (white dots at front)
    final headlightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 8, center.dy - 22), 2.5, headlightPaint);
    canvas.drawCircle(Offset(center.dx + 8, center.dy - 22), 2.5, headlightPaint);
    
    // Tail lights (red dots at rear)
    final taillightPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 8, center.dy + 22), 2.5, taillightPaint);
    canvas.drawCircle(Offset(center.dx + 8, center.dy + 22), 2.5, taillightPaint);
  }
  
  /// Draw a 2D bike/motorcycle from top view
  void _drawBike(Canvas canvas, Offset center) {
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(2, 2), width: 18, height: 45),
        const Radius.circular(6),
      ),
      shadowPaint,
    );
    
    // Bike body - thin orange rectangle
    final bodyPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.fill;
    final bikeBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 16, height: 42),
      const Radius.circular(6),
    );
    canvas.drawRRect(bikeBody, bodyPaint);
    
    // Outline
    final outlinePaint = Paint()
      ..color = const Color(0xFFF57C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(bikeBody, outlinePaint);
    
    // Front wheel
    final wheelPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - 16), 5, wheelPaint);
    canvas.drawCircle(Offset(center.dx, center.dy - 16), 3, Paint()..color = Colors.grey[700]!);
    
    // Rear wheel
    canvas.drawCircle(Offset(center.dx, center.dy + 16), 5, wheelPaint);
    canvas.drawCircle(Offset(center.dx, center.dy + 16), 3, Paint()..color = Colors.grey[700]!);
    
    // Headlight (white dot at front)
    final headlightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - 20), 2, headlightPaint);
  }
  
  /// Draw a 2D SUV from top view
  void _drawSUV(Canvas canvas, Offset center) {
    // SUV body - larger and more rectangular
    final suvBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 38, height: 56),
      const Radius.circular(6),
    );
    
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      suvBody.shift(const Offset(2, 2)),
      shadowPaint,
    );
    
    // SUV body fill - green
    final bodyPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(suvBody, bodyPaint);
    
    // SUV body outline
    final outlinePaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(suvBody, outlinePaint);
    
    // Front windshield
    final windshield = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 14),
        width: 28,
        height: 16,
      ),
      const Radius.circular(4),
    );
    final windshieldPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(windshield, windshieldPaint);
    
    // Rear windshield
    final rearWindow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 14),
        width: 28,
        height: 14,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(rearWindow, windshieldPaint);
    
    // Headlights (white dots at front)
    final headlightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 12, center.dy - 25), 3, headlightPaint);
    canvas.drawCircle(Offset(center.dx + 12, center.dy - 25), 3, headlightPaint);
    
    // Tail lights (red dots at rear)
    final taillightPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 12, center.dy + 25), 3, taillightPaint);
    canvas.drawCircle(Offset(center.dx + 12, center.dy + 25), 3, taillightPaint);
    
    // Side mirrors
    final mirrorPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 20, center.dy - 8), 3, mirrorPaint);
    canvas.drawCircle(Offset(center.dx + 20, center.dy - 8), 3, mirrorPaint);
  }

  Future<void> _callDriver() async {
    final phone = _driverPhone;
    if (phone == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver phone number not available')),
        );
      }
      return;
    }
    
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Cannot launch phone app';
      }
    } catch (e) {
      dev.log('Call driver failed: $e', name: 'RideDetailsScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open phone app: $e')),
        );
      }
    }
  }

  Future<void> _textDriver() async {
    final phone = _driverPhone;
    if (phone == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver phone number not available')),
        );
      }
      return;
    }
    
    // Clean phone number (remove spaces, dashes, etc.)
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Try WhatsApp first
    final whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
    
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      dev.log('WhatsApp launch failed: $e', name: 'RideDetailsScreen');
    }
    
    // Fallback to SMS if WhatsApp is not available
    final smsUri = Uri(scheme: 'sms', path: phone);
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        throw 'Cannot launch messaging app';
      }
    } catch (e) {
      dev.log('SMS launch failed: $e', name: 'RideDetailsScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open messaging app')),
        );
      }
    }
  }

  void _debouncedRecalculateRoute() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(seconds: 1), _recalculateRoute);
  }

  Future<void> _recalculateRoute() async {
    if (!mounted) return; // Early exit if widget is disposed
    try {
      final flow = ref.read(rideFlowProvider);
      final pickup = flow.pickupLatLng;
      final dest = flow.destinationLatLng;
      if (Env.googleApiKey.isEmpty) return; // skip if no key
      if (pickup == null || dest == null) return;

      final LatLng start = _driverLatLng ?? LatLng(pickup['lat']!, pickup['lng']!);
      final LatLng end = _rideStarted
          ? LatLng(dest['lat']!, dest['lng']!)
          : LatLng(pickup['lat']!, pickup['lng']!);

      final svc = DirectionsService(Env.googleApiKey);
      final res = await svc.routeLatLng(start.latitude, start.longitude, end.latitude, end.longitude);
      if (res != null && mounted) {
        setState(() {
          _dynamicRoute = res.polyline.map((p) => LatLng(p[0], p[1])).toList(growable: false);
        });
      }
    } catch (e) {
      dev.log('Route calc error: $e', name: 'RideDetailsScreen');
    }
  }

  void _maybeMarkArrived() {
    if (!mounted) return; // Early exit if widget is disposed
    final flow = ref.read(rideFlowProvider);
    final pickup = flow.pickupLatLng;
    if (_driverLatLng == null || pickup == null || _rideStarted) return;
    final d = Geolocator.distanceBetween(
      _driverLatLng!.latitude,
      _driverLatLng!.longitude,
      pickup['lat']!,
      pickup['lng']!,
    );
    if (d <= 100 && !_driverArrived) {
      setState(() => _driverArrived = true);
      // Optionally write event for history
      final rideId = flow.rideId;
      if (rideId != null) {
        Supabase.instance.client.from('ride_events').insert({
          'ride_id': rideId,
          'actor': 'system',
          'event_type': 'ride:arrived',
          'payload': {'distance_m': d},
        });
      }
    }
  }

  Future<void> _loadOtp(String rideId) async {
    try {
      // Prefer rides.trip_otp if available
      try {
        final ride = await Supabase.instance.client
            .from('rides')
            .select('trip_otp')
            .eq('id', rideId)
            .maybeSingle();
        final otp = (ride?['trip_otp'])?.toString();
        if (otp != null && otp.isNotEmpty && mounted) {
          setState(() => _rideOtp = otp);
          return;
        }
      } catch (_) {}
      // Fallback: latest ride:otp_issued event
      final ev = await Supabase.instance.client
          .from('ride_events')
          .select('payload')
          .eq('ride_id', rideId)
          .eq('event_type', 'ride:otp_issued')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final otp = (ev?['payload']?['otp'])?.toString();
      if (otp != null && otp.isNotEmpty && mounted) {
        setState(() => _rideOtp = otp);
      }
    } catch (e) {
      dev.log('Failed to load OTP: $e', name: 'RideDetailsScreen');
    }
  }

  Future<void> _endTrip() async {
    if (!mounted) return; // Early exit if widget is disposed
    final rideId = ref.read(rideFlowProvider).rideId;
    if (rideId == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/payments');
      }
      return;
    }
    try {
      await Supabase.instance.client.from('rides').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', rideId);
      await Supabase.instance.client.from('ride_events').insert({
        'ride_id': rideId,
        'actor': 'passenger',
        'event_type': 'ride:completed',
        'payload': {'source': 'passenger_app'},
      });
    } catch (e) {
      dev.log('End trip error: $e', name: 'RideDetailsScreen');
    } finally {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/payments');
      }
    }
  }
}


