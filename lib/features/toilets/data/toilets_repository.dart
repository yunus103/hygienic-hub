import 'package:cloud_firestore/cloud_firestore.dart';

class ToiletsRepository {
  final FirebaseFirestore _firestore;

  ToiletsRepository(this._firestore);

  Future<void> createIfNotExists({
    required String id,
    required String name,
    required double lat,
    required double lng,
    required String createdBy,
    required String source,

    // --- New Fields ---
    String? type, // Mall, Restaurant, Park, etc.
    String? openingTime, // e.g. "08:00"
    String? closingTime, // e.g. "22:00"

    // ------------------
    bool? isFree,
    bool? isAccessible,
    bool? hasBabyChange, // Added based on design
  }) async {
    final docRef = _firestore.collection('toilets').doc(id);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      final now = FieldValue.serverTimestamp();

      final data = {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'source': source,
        'createdBy': createdBy,
        'createdAt': now,
        'ratingSum': 0,
        'ratingCount': 0,
        'verified': false,
        'verifiedFeatures': null,

        // Metadata
        'type': type,
        'openingTime': openingTime,
        'closingTime': closingTime,

        'reportedFeatures': {
          if (isFree != null) 'isFree': isFree,
          if (isAccessible != null) 'isAccessible': isAccessible,
          if (hasBabyChange != null) 'hasBabyChange': hasBabyChange,
        },
      };

      await docRef.set(data);
    }
  }
}
