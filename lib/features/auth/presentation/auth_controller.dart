import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return FirebaseAuth.instance.currentUser;
  }

  Future<void> signInAnonymously() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      return cred.user;
    });
  }
}
