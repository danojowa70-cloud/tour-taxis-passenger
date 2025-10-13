import 'dart:convert';
import 'package:http/http.dart' as http;

class DirectionsResult {
  final double distanceMeters;
  final double durationSeconds;
  final List<List<double>> polyline; // [lat, lng]
  const DirectionsResult({required this.distanceMeters, required this.durationSeconds, required this.polyline});
}

class DirectionsService {
  final String apiKey;
  DirectionsService(this.apiKey);

  Future<DirectionsResult?> routeLatLng(double startLat, double startLng, double endLat, double endLng) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '$startLat,$startLng',
      'destination': '$endLat,$endLng',
      'key': apiKey,
      'mode': 'driving',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = json.decode(res.body) as Map<String, dynamic>;
    final routes = (data['routes'] as List<dynamic>? ?? []);
    if (routes.isEmpty) return null;
    final leg = routes.first['legs'][0];
    final distanceMeters = (leg['distance']['value'] as num).toDouble();
    final durationSeconds = (leg['duration']['value'] as num).toDouble();
    final poly = routes.first['overview_polyline']['points'] as String;
    return DirectionsResult(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      polyline: _decodePolyline(poly),
    );
  }

  List<List<double>> _decodePolyline(String encoded) {
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    final List<List<double>> points = [];
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add([lat / 1e5, lng / 1e5]);
    }
    return points;
  }
}


