import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/profile_repository.dart';

// Provider for current user profile data
final currentUserProfileProvider = StreamProvider<Map<String, dynamic>?>((
  ref,
) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield null;
    return;
  }

  final repository = ref.watch(profileRepositoryProvider);
  final profile = await repository.getUserProfile(user.uid);
  yield profile;
});

// Provider for user toilets
final userToiletsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(profileRepositoryProvider);
  return repository.getUserToilets(user.uid);
});

// Provider for user reviews
final userReviewsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return [];
  }

  final repository = ref.watch(profileRepositoryProvider);
  return await repository.getUserReviews(user.uid);
});

// Provider for user statistics
final userStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return {'toiletsCount': 0, 'reviewsCount': 0};
  }

  final repository = ref.watch(profileRepositoryProvider);
  return await repository.getUserStats(user.uid);
});
