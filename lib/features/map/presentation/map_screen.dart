import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../toilets/data/toilets_repository.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  Future<void> _createFakeToilet() async {
    final repo = ToiletsRepository(FirebaseFirestore.instance);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await repo.createIfNotExists(
      placeId: 'fake_place_1',
      name: 'Test Cafe Toilet',
      lat: 41.0082,
      lng: 28.9784,
      createdBy: uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: Center(
        child: ElevatedButton(
          onPressed: _createFakeToilet,
          child: const Text('Create Fake Toilet'),
        ),
      ),
    );
  }
}
