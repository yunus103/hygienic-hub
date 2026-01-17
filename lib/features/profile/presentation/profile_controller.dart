import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/profile_repository.dart';

// Profil Bilgisi (Canlı)
final currentUserProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});

// Kullanıcı Yorumları (Canlı - Stream)
final userReviewsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  final repository = ref.watch(profileRepositoryProvider);
  return repository.getUserReviewsStream(user.uid);
});

// İstatistik (Sadece Yorum Sayısı)
final userStatsProvider = StreamProvider<int>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(0);

  final repository = ref.watch(profileRepositoryProvider);
  return repository.getUserReviewCount(user.uid);
});
