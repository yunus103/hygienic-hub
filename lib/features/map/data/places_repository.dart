import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText; // Örn: "Starbucks"
  final String secondaryText; // Örn: "Kadıköy, İstanbul"

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    // Google yanıtında 'structured_formatting' içinde daha temiz metinler var
    final struct = json['structured_formatting'] ?? {};

    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      // Eğer structured_formatting boşsa description'ı kullan (Hata almamak için)
      mainText: struct['main_text'] ?? json['description'] ?? '',
      secondaryText: struct['secondary_text'] ?? '',
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final double lat;
  final double lng;
  final String? address;
  final String? photoReference;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    this.address,
    this.photoReference,
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
        // Optional: Restrict to Turkey or current region if needed
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
    // Requesting place_id, name, geometry, formatted_address, and photos
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
          'place_id': placeId,
          'fields': 'place_id,name,geometry,formatted_address,photos',
          'key': apiKey,
        });

    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (body['status'] != 'OK') {
      throw Exception(
        'Places details failed: ${body['status']} ${body['error_message'] ?? ''}',
      );
    }

    final result = body['result'] as Map<String, dynamic>;
    final loc = result['geometry']['location'];

    // Extract photo reference if available
    String? photoRef;
    if (result['photos'] != null) {
      final photos = result['photos'] as List;
      if (photos.isNotEmpty) {
        photoRef = photos.first['photo_reference'] as String;
      }
    }

    return PlaceDetails(
      placeId: result['place_id'] as String,
      name: result['name'] as String,
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
      address: result['formatted_address'] as String?,
      photoReference: photoRef,
    );
  }

  /// Helper to construct the photo URL
  String photoUrl(String reference, {int maxWidth = 600}) {
    return Uri.https('maps.googleapis.com', '/maps/api/place/photo', {
      'maxwidth': maxWidth.toString(),
      'photo_reference': reference,
      'key': apiKey,
    }).toString();
  }
}
