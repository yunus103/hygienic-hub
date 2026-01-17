import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/reviews/presentation/add_review_screen.dart';
import '../../features/map/presentation/place_search_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/toilets/presentation/toilet_detail_screen.dart';
import '../../features/toilets/presentation/add_manual_toilet_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import 'dart:async';

// 1. Auth Durumunu Dinleyen Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final appRouterProvider = Provider<GoRouter>((ref) {
  // Auth durumunu izle (refreshListenable için gerekli değil ama logic için iyi)
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    // 2. Yönlendirme (Refresh) Mantığı
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),

    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;

      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';

      // Giriş yapmamışsa ve auth sayfalarında değilse -> Login'e at
      if (!isLoggedIn && !isLoggingIn && !isSigningUp) {
        return '/login';
      }

      // Giriş yapmışsa ve hala auth sayfalarındaysa -> Haritaya at
      if (isLoggedIn && (isLoggingIn || isSigningUp)) {
        return '/map';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/toilet/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ToiletDetailScreen(toiletId: id);
        },
      ),
      GoRoute(
        path: '/toilet/:id/add-review',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddReviewScreen(toiletId: id);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const PlaceSearchScreen(),
      ),
      GoRoute(
        path: '/add-manual-toilet',
        builder: (context, state) {
          final latLng = state.extra as LatLng?;
          return AddManualToiletScreen(initialLocation: latLng);
        },
      ),
    ],
  );
});

// GoRouter için Stream Dinleyicisi (Helper Class)

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
