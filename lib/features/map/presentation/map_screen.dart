import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../toilets/data/toilets_repository.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  static int _counter = 1;

  Future<void> _createFakeToiletAndGo(BuildContext context) async {
    final repo = ToiletsRepository(FirebaseFirestore.instance);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final placeId = 'fake_place_${_counter++}';

    await repo.createIfNotExists(
      id: placeId,
      name: 'Test Cafe Toilet',
      lat: 41.0082,
      lng: 28.9784,
      createdBy: uid,
      source: 'places',
    );

    if (context.mounted) {
      // CHANGED: Use push instead of go to keep Back Button
      context.push('/toilet/$placeId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _createFakeToiletAndGo(context),
              child: const Text('Create Fake Toilet → Detail'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              // CHANGED: Use push instead of go
              onPressed: () => context.push('/search'),
              child: const Text('Search Place'),
            ),
          ],
        ),
      ),
    );
  }
}
