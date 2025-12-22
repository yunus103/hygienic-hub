import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String placeId;
  final String description;

  PlacePrediction({required this.placeId, required this.description});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final double lat;
  final double lng;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
  });
}

class PlacesRepository {
  final String apiKey;
  PlacesRepository(this.apiKey);

  Future<List<PlacePrediction>> autocomplete(String input) async {
    final q = input.trim();
    if (q.isEmpty) return [];
    if (q.length < 3) return [];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'key': apiKey,
        // Türkiye odaklı istersen:
        'components': 'country:tr',
        'language': 'tr',
      },
    );

    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (body['status'] != 'OK' && body['status'] != 'ZERO_RESULTS') {
      throw Exception(
        'Places autocomplete failed: ${body['status']} ${body['error_message'] ?? ''}',
      );
    }

    final preds = (body['predictions'] as List).cast<Map<String, dynamic>>();
    return preds.map(PlacePrediction.fromJson).toList();
  }

  Future<PlaceDetails> fetchDetails(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {'place_id': placeId, 'fields': 'place_id,name,geometry', 'key': apiKey},
    );

    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (body['status'] != 'OK') {
      throw Exception(
        'Places details failed: ${body['status']} ${body['error_message'] ?? ''}',
      );
    }

    final result = body['result'] as Map<String, dynamic>;
    final loc = (((result['geometry'] as Map)['location'] as Map));
    return PlaceDetails(
      placeId: result['place_id'] as String,
      name: result['name'] as String,
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
    );
  }
}
