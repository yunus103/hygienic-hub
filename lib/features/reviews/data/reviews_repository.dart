import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewsRepository {
  final FirebaseFirestore _firestore;
  ReviewsRepository(this._firestore);

  Future<void> createReview({
    required String toiletId,
    required String userId,
    required double overall,
    required String comment,
    required bool isFree,
    required bool isAccessible,
    required bool hasSupplies,
  }) async {
    final toiletRef = _firestore.collection('toilets').doc(toiletId);
    final reviewRef = toiletRef.collection('reviews').doc(userId);

    // Edit yok: varsa direkt hata
    final existing = await reviewRef.get();
    if (existing.exists) {
      throw Exception('You already reviewed this toilet (edit disabled).');
    }

    // 1) Review yaz
    await reviewRef.set({
      'userId': userId,
      'overall': overall,
      'comment': comment,
      'isFree': isFree,
      'isAccessible': isAccessible,
      'hasSupplies': hasSupplies,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2) Rating sum/count atomik artır
    await toiletRef.set({
      'ratingCount': FieldValue.increment(1),
      'ratingSum': FieldValue.increment(overall),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> fetchLatestReviews({
    required String toiletId,
    int limit = 20,
  }) async {
    final q = await _firestore
        .collection('toilets')
        .doc(toiletId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return q.docs.map((d) => d.data()).toList();
  }
}
