import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/ride_flow_providers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class RideDetailsScreen extends ConsumerStatefulWidget {
  const RideDetailsScreen({super.key});

  @override
  ConsumerState<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends ConsumerState<RideDetailsScreen> {
  RealtimeChannel? _realtime;
  GoogleMapController? _mapController;
  LatLng? _driverLatLng;
  String? _driverName;
  String? _driverCar;
  String? _driverPhone;

  @override
  void initState() {
    super.initState();
    final rideId = ref.read(rideFlowProvider).rideId;
    if (rideId != null) {
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
              if (type == 'ride:accepted') {
                final data = row['payload'] as Map<String, dynamic>?;
                setState(() {
                  _driverName = data?['driver_name'] as String? ?? _driverName;
                  _driverCar = data?['driver_car'] as String? ?? _driverCar;
                  _driverPhone = data?['driver_phone'] as String? ?? _driverPhone;
                });
              } else if (type == 'ride:update') {
                final data = row['payload'] as Map<String, dynamic>?;
                final lat = (data?['lat'] as num?)?.toDouble();
                final lng = (data?['lng'] as num?)?.toDouble();
                if (lat != null && lng != null) {
                  final pos = LatLng(lat, lng);
                  setState(() => _driverLatLng = pos);
                  _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
                }
              } else if (type == 'ride:completed' || type == 'ride:end') {
                Navigator.of(context).pushReplacementNamed('/payments');
              }
            },
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    if (_realtime != null) {
      Supabase.instance.client.removeChannel(_realtime!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final flow = ref.watch(rideFlowProvider);
    final pickup = flow.pickupLatLng != null ? LatLng(flow.pickupLatLng!['lat']!, flow.pickupLatLng!['lng']!) : null;
    final dest = flow.destinationLatLng != null ? LatLng(flow.destinationLatLng!['lat']!, flow.destinationLatLng!['lng']!) : null;
    final polyPoints = flow.polyline ?? [];
    final routePolyline = polyPoints.map((p) => LatLng(p[0], p[1])).toList(growable: false);

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
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      child: const Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_driverName ?? 'Driver pending…', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(_driverCar ?? '—', style: TextStyle(color: subtle)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('En route', style: TextStyle(color: subtle, fontWeight: FontWeight.w600)),
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
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 200,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: pickup ?? const LatLng(0,0), zoom: pickup != null ? 12 : 2),
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (c) async {
                      _mapController = c;
                      await Future.delayed(const Duration(milliseconds: 50));
                      final bounds = _computeBounds([
                        if (pickup != null) pickup,
                        if (dest != null) dest,
                        if (_driverLatLng != null) _driverLatLng!,
                        ...routePolyline,
                      ]);
                      if (bounds != null) {
                        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 36));
                      }
                    },
                    markers: {
                      if (_driverLatLng != null)
                        Marker(markerId: const MarkerId('driver'), position: _driverLatLng!),
                      if (pickup != null)
                        const Marker(markerId: MarkerId('pickup'), position: LatLng(0,0)),
                      if (pickup != null)
                        Marker(markerId: const MarkerId('pickup_real'), position: pickup),
                      if (dest != null)
                        Marker(markerId: const MarkerId('dest'), position: dest),
                    },
                    polylines: routePolyline.isNotEmpty ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: routePolyline,
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
                        Text('8245', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    ElevatedButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/payments'), child: const Text('End Trip')),
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

  Future<void> _callDriver() async {
    final phone = _driverPhone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _textDriver() async {
    final phone = _driverPhone;
    if (phone == null) return;
    final uri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}


