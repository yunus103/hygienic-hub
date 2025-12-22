import 'package:cloud_firestore/cloud_firestore.dart';

class ToiletsRepository {
  final FirebaseFirestore _firestore;

  ToiletsRepository(this._firestore);

  Future<void> createIfNotExists({
    required String placeId,
    required String name,
    required double lat,
    required double lng,
    required String createdBy,
  }) async {
    final ref = _firestore.collection('toilets').doc(placeId);

    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'placeId': placeId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'verifiedFeatures': null,
    });
  }
}
