import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewsRepository {
  final FirebaseFirestore _firestore;

  ReviewsRepository(this._firestore);

  Future<void> addReview({
    required String toiletId,
    required String userId,
    required double overall,
    required String comment,
    required double cleanliness,
    required double smell,
    required bool isFree,
    required bool isAccessible,
    required bool hasSoap,
    required bool hasBabyChange,
  }) async {
    final toiletRef = _firestore.collection('toilets').doc(toiletId);
    final reviewRef = toiletRef.collection('reviews').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final toiletDoc = await transaction.get(toiletRef);
      if (!toiletDoc.exists) {
        throw Exception("Toilet does not exist!");
      }

      final reviewDoc = await transaction.get(reviewRef);
      final now = FieldValue.serverTimestamp();

      final newReviewData = {
        'userId': userId,
        'overall': overall,
        'comment': comment,
        'cleanliness': cleanliness,
        'smell': smell,
        'isFree': isFree,
        'isAccessible': isAccessible,
        'hasSoap': hasSoap,
        'hasBabyChange': hasBabyChange,
        'updatedAt': now, // Keep track of when it was last changed
      };

      if (reviewDoc.exists) {
        // --- CASE 1: UPDATE EXISTING REVIEW ---
        // Logic: Don't change ratingCount. Just adjust ratingSum.

        final oldData = reviewDoc.data()!;
        final oldOverall = (oldData['overall'] ?? 0).toDouble();
        final ratingDiff =
            overall - oldOverall; // e.g. Changed 3 to 5 -> Diff is +2

        transaction.update(reviewRef, newReviewData);

        transaction.update(toiletRef, {
          'ratingSum': FieldValue.increment(ratingDiff),
          // ratingCount does NOT change
          // We can also update reported features here if we want the latest info to win
        });
      } else {
        // --- CASE 2: NEW REVIEW ---
        // Logic: Increment everything normal.

        // Add 'createdAt' only for new docs
        newReviewData['createdAt'] = now;

        transaction.set(reviewRef, newReviewData);

        transaction.update(toiletRef, {
          'ratingSum': FieldValue.increment(overall),
          'ratingCount': FieldValue.increment(1),
        });
      }
    });
  }
}
