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

    // 1. ADIM: Yorumu ve Puanları Transaction ile Güvenli Kaydet
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
        'updatedAt': now,
      };

      if (reviewDoc.exists) {
        // --- SENARYO 1: YORUM GÜNCELLEME ---
        final oldData = reviewDoc.data()!;
        final oldOverall = (oldData['overall'] ?? 0).toDouble();
        final ratingDiff = overall - oldOverall;

        transaction.update(reviewRef, newReviewData);

        // Sadece toplam puanı güncelle (Sayısı değişmez)
        transaction.update(toiletRef, {
          'ratingSum': FieldValue.increment(ratingDiff),
        });
      } else {
        // --- SENARYO 2: YENİ YORUM ---
        newReviewData['createdAt'] = now;
        transaction.set(reviewRef, newReviewData);

        // Hem puanı hem sayıyı artır
        transaction.update(toiletRef, {
          'ratingSum': FieldValue.increment(overall),
          'ratingCount': FieldValue.increment(1),
        });
      }
    });

    // 2. ADIM: Transaction bitti, şimdi özellikleri (Map Filtrelerini) güncelle
    // Bu işlem asenkron çalışabilir, kullanıcının beklemesine gerek yok ama
    // veri tutarlılığı için burada await kullanıyoruz.
    await _updateConsensus(toiletId);
  }

  // --- EKSİK OLAN PARÇA: MUTABAKAT MOTORU ---
  // Tüm yorumları tarar ve özellikleri ana karta yazar.
  Future<void> _updateConsensus(String toiletId) async {
    final toiletRef = _firestore.collection('toilets').doc(toiletId);

    // O tuvalete ait tüm yorumları çek
    final reviewsSnapshot = await toiletRef.collection('reviews').get();
    final docs = reviewsSnapshot.docs;

    if (docs.isEmpty) return;

    // Sayaçlar
    int freeVotes = 0; // "Ücretsiz" diyenler
    int paidVotes = 0; // "Ücretli" diyenler
    int accessibleVotes = 0;
    int babyChangeVotes = 0;
    int soapVotes = 0;

    for (var doc in docs) {
      final data = doc.data();

      // Ücret Oylaması
      if (data['isFree'] == true) {
        freeVotes++;
      } else {
        paidVotes++;
      }

      // Diğer Özellikler (Sadece "Var" diyenleri sayıyoruz)
      if (data['isAccessible'] == true) accessibleVotes++;
      if (data['hasBabyChange'] == true) babyChangeVotes++;
      if (data['hasSoap'] == true) soapVotes++;
    }

    // --- KARAR MEKANİZMASI ---
    // Buradaki mantık: Çoğunluk ne derse o (veya en az 1 kişi onayladıysa).

    final Map<String, dynamic> newReportedFeatures = {
      // Ücretsiz mi? -> Ücretsiz diyenler >= Ücretli diyenler
      'isFree': freeVotes >= paidVotes,

      // Diğer özellikler -> En az 1 kişi "Var" dediyse haritada gösterelim
      // (Daha katı olması için > 1 veya > 2 yapabilirsin)
      'isAccessible': accessibleVotes > 0,
      'hasBabyChange': babyChangeVotes > 0,
      'hasSoap': soapVotes > 0,
    };

    // Ana Tuvalet Dökümanını Güncelle
    // Bu sayede MapScreen filtreleri çalışacak!
    await toiletRef.update({'reportedFeatures': newReportedFeatures});
  }
}
