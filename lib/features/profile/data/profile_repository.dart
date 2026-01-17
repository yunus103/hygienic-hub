import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(FirebaseFirestore.instance);
});

class ProfileRepository {
  final FirebaseFirestore _firestore;

  ProfileRepository(this._firestore);

  /// Kullanıcı Profil Bilgisi (Canlı Dinleme için controller'da direkt stream kullanıyoruz)
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data();
  }

  /// Yorumları Getir (CANLI AKIŞ - STREAM)
  /// Collection Group kullanarak kullanıcının tüm yorumlarını dinler.
  Stream<List<Map<String, dynamic>>> getUserReviewsStream(String userId) {
    return _firestore
        .collectionGroup('reviews')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          // asyncMap: Gelen her veri paketini işleyip yeni bir listeye çevirir
          final List<Map<String, dynamic>> userReviews = [];

          for (final doc in snapshot.docs) {
            // Yorumun ait olduğu tuvaleti bulmak için parent'a çıkıyoruz
            final toiletRef = doc.reference.parent.parent;
            String toiletName = 'Bilinmeyen Tuvalet';
            String toiletId = '';

            if (toiletRef != null) {
              toiletId = toiletRef.id;
              // Performans için: İleride tuvalet adını yorumun içine kaydetmek daha iyi olur.
              // Şimdilik her yorum için tuvalet adını çekiyoruz.
              final toiletDoc = await toiletRef.get();
              if (toiletDoc.exists) {
                toiletName = toiletDoc.data()?['name'] ?? 'İsimsiz';
              }
            }

            userReviews.add({
              'id': doc.id,
              'toiletId': toiletId,
              'toiletName': toiletName,
              ...doc.data(),
            });
          }
          return userReviews;
        });
  }

  /// İstatistikler (Sadece Yorum Sayısı)
  Stream<int> getUserReviewCount(String userId) {
    return _firestore
        .collectionGroup('reviews')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
