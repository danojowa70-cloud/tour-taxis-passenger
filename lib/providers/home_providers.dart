import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/places_service.dart';
import '../services/directions_service.dart';

final placesServiceProvider = Provider<PlacesService>((ref) => PlacesService('AIzaSyBRYPKaXlRhpzoAmM5-KrS2JaNDxAX_phw'));
final directionsServiceProvider = Provider<DirectionsService>((ref) => DirectionsService('AIzaSyBRYPKaXlRhpzoAmM5-KrS2JaNDxAX_phw'));

final currentPositionProvider = FutureProvider<Position>((ref) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
});

final destinationQueryProvider = StateProvider<String>((ref) => '');

final destinationSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  final query = ref.watch(destinationQueryProvider);
  final svc = ref.watch(placesServiceProvider);
  if (query.isEmpty) return [];
  return svc.autocomplete(query);
});


