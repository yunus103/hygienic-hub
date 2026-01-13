import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(FirebaseFirestore.instance);
});

class ProfileRepository {
  final FirebaseFirestore _firestore;

  ProfileRepository(this._firestore);

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data();
  }

  /// Get toilets created by user
  Stream<List<Map<String, dynamic>>> getUserToilets(String userId) {
    return _firestore
        .collection('toilets')
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
        });
  }

  /// Get reviews created by user
  /// This queries all toilets and filters reviews by userId
  /// For better performance in production, consider creating a separate reviews collection
  Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    final toilets = await _firestore.collection('toilets').get();
    final List<Map<String, dynamic>> userReviews = [];

    for (final toilet in toilets.docs) {
      final reviewsSnapshot = await toilet.reference
          .collection('reviews')
          .where('userId', isEqualTo: userId)
          .get();

      for (final review in reviewsSnapshot.docs) {
        userReviews.add({
          'id': review.id,
          'toiletId': toilet.id,
          'toiletName': toilet.data()['name'] ?? 'Unknown',
          ...review.data(),
        });
      }
    }

    // Sort by creation date descending
    userReviews.sort((a, b) {
      final aDate = a['createdAt'] as Timestamp?;
      final bDate = b['createdAt'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    return userReviews;
  }

  /// Update user profile
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore.collection('users').doc(userId).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get user statistics
  Future<Map<String, int>> getUserStats(String userId) async {
    // Count toilets
    final toiletsSnapshot = await _firestore
        .collection('toilets')
        .where('createdBy', isEqualTo: userId)
        .count()
        .get();

    // Count reviews (this is slower, but works for now)
    final reviews = await getUserReviews(userId);

    return {
      'toiletsCount': toiletsSnapshot.count ?? 0,
      'reviewsCount': reviews.length,
    };
  }
}
