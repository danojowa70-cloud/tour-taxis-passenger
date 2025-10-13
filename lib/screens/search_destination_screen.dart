import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_providers.dart';
import '../providers/ride_flow_providers.dart';
import '../services/fare_service.dart';

class SearchDestinationScreen extends ConsumerWidget {
  const SearchDestinationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(destinationSuggestionsProvider);
    final places = ref.watch(placesServiceProvider);
    final directions = ref.watch(directionsServiceProvider);
    const fareService = FareService();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Where to?'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => ref.read(destinationQueryProvider.notifier).state = v,
                  decoration: const InputDecoration(
                    hintText: 'Search destination',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: suggestions.when(
                    data: (items) => items.isEmpty
                        ? const Center(child: Text('Type to search'))
                        : ListView.separated(
                            itemBuilder: (_, i) => ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(items[i]),
                              onTap: () async {
                                // Re-fetch with IDs so we can get coordinates
                                final enriched = await places.autocompleteWithIds(items[i]);
                                final match = enriched.firstWhere(
                                  (e) => e['description'] == items[i],
                                  orElse: () => {'place_id': ''},
                                );
                                final placeId = match['place_id'] ?? '';
                                final destLatLng = await places.placeDetailsLatLng(placeId);
                                final pos = await ref.read(currentPositionProvider.future);
                                if (destLatLng != null) {
                                  final route = await directions.routeLatLng(pos.latitude, pos.longitude, destLatLng['lat']!, destLatLng['lng']!);
                                  if (route != null) {
                                    final fare = fareService.estimate(distanceMeters: route.distanceMeters, durationSeconds: route.durationSeconds);
                                    ref.read(rideFlowProvider.notifier).updateFrom(
                                      pickup: 'Current location',
                                      destination: items[i],
                                      pickupLatLng: {'lat': pos.latitude, 'lng': pos.longitude},
                                      destinationLatLng: destLatLng,
                                      distanceMeters: route.distanceMeters,
                                      durationSeconds: route.durationSeconds,
                                      polyline: route.polyline,
                                      estimatedFare: fare,
                                    );
                                  }
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pushNamed('/confirm');
                                }
                              },
                            ),
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemCount: items.length,
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}


