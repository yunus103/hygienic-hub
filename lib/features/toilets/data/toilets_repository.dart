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

    String? type,
    String? openingTime,
    String? closingTime,

    // --- ÖZELLİK PARAMETRELERİNİ KALDIRDIK ---
    // Artık özellikler sadece yorumlardan veya admin panelinden gelecek.
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

        // Doğrulama Alanları
        'verified': false,
        'verifiedFeatures': null, // Admin onayı bekliyor
        // Metadata
        'type': type,
        'openingTime': openingTime,
        'closingTime': closingTime,

        // Başlangıçta hiç özellik raporu yok
        'reportedFeatures': {},
      };

      await docRef.set(data);
    }
  }
}
