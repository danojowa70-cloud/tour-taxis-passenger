import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  final String apiKey;
  PlacesService(this.apiKey);

  Future<List<String>> autocomplete(String query) async {
    if (query.isEmpty) return [];
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': query,
      'key': apiKey,
      'components': 'country:be',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = json.decode(res.body) as Map<String, dynamic>;
    final preds = (data['predictions'] as List<dynamic>? ?? []);
    return preds.map((e) => e['description'] as String).toList();
  }

  Future<List<Map<String, String>>> autocompleteWithIds(String query) async {
    if (query.isEmpty) return [];
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': query,
      'key': apiKey,
      'components': 'country:be',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = json.decode(res.body) as Map<String, dynamic>;
    final preds = (data['predictions'] as List<dynamic>? ?? []);
    return preds.map((e) => {
      'description': (e['description'] ?? '') as String,
      'place_id': (e['place_id'] ?? '') as String,
    }).toList();
  }

  Future<Map<String, double>?> placeDetailsLatLng(String placeId) async {
    if (placeId.isEmpty) return null;
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': apiKey,
      'fields': 'geometry',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = json.decode(res.body) as Map<String, dynamic>;
    final loc = data['result']?['geometry']?['location'];
    if (loc == null) return null;
    return {
      'lat': (loc['lat'] as num).toDouble(),
      'lng': (loc['lng'] as num).toDouble(),
    };
  }
}


