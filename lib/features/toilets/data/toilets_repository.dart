import 'package:cloud_firestore/cloud_firestore.dart';

class ToiletsRepository {
  final FirebaseFirestore _firestore;
  ToiletsRepository(this._firestore);

  Future<void> createIfNotExists({
    required String id, // placeId veya manual_<uuid>
    required String name,
    required double lat,
    required double lng,
    required String createdBy,
    required String source, // 'places' | 'manual'
  }) async {
    final ref = _firestore.collection('toilets').doc(id);

    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'id': id,
      'source': source,
      'name': name, // minimal cache (source of truth Places olacak)
      'lat': lat,
      'lng': lng,
      'verified': false,
      'verifiedFeatures': null,
      'avgRating': 0.0,
      'ratingCount': 0,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
