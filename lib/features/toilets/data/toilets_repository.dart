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
    bool? isFree,
    bool? isAccessible,
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

        // --- DOĞRULAMA MANTIĞI ---
        // Kullanıcının eklediği tuvalet varsayılan olarak onaysızdır
        'verified': false,

        // Admin'in onayladığı özellikler (Başlangıçta boş/null)
        'verifiedFeatures': null,

        // Kullanıcının ilk eklerken beyan ettiği özellikler (Referans için)
        'reportedFeatures': {
          if (isFree != null) 'isFree': isFree,
          if (isAccessible != null) 'isAccessible': isAccessible,
        },
      };

      await docRef.set(data);
    }
  }
}
