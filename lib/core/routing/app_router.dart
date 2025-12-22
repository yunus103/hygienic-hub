import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/reviews/presentation/add_review_screen.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/toilets/presentation/toilet_detail_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loggingIn = state.matchedLocation == '/login';

      if (user == null && !loggingIn) return '/login';
      if (user != null && loggingIn) return '/map';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(
        path: '/toilet/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ToiletDetailScreen(
            placeId: id,
          ); // ismini sonra toiletId yaparsın
        },
      ),

      GoRoute(
        path: '/toilet/:id/add-review',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddReviewScreen(toiletId: id);
        },
      ),
    ],
  );
});
