import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: authState.when(
          data: (_) => ElevatedButton(
            onPressed: () async {
              await ref
                  .read(authControllerProvider.notifier)
                  .signInAnonymously();
              if (context.mounted) context.go('/map');
            },
            child: const Text('Continue'),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Auth error: $e'),
        ),
      ),
    );
  }
}
