import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/toilets_repository.dart';

class AddManualToiletScreen extends StatefulWidget {
  const AddManualToiletScreen({super.key});

  @override
  State<AddManualToiletScreen> createState() => _AddManualToiletScreenState();
}

class _AddManualToiletScreenState extends State<AddManualToiletScreen> {
  final _nameCtrl = TextEditingController();

  // Default to Istanbul coordinates for MVP until Map Picker is added
  final _latCtrl = TextEditingController(text: '41.0082');
  final _lngCtrl = TextEditingController(text: '28.9784');

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      final repo = ToiletsRepository(FirebaseFirestore.instance);

      // Generate a unique ID for manual entry
      final manualId = 'manual_${DateTime.now().millisecondsSinceEpoch}';

      final lat = double.tryParse(_latCtrl.text) ?? 41.0082;
      final lng = double.tryParse(_lngCtrl.text) ?? 28.9784;

      await repo.createIfNotExists(
        id: manualId,
        name: name,
        lat: lat,
        lng: lng,
        createdBy: uid,
        source: 'manual',
      );

      if (mounted) {
        // Navigate to the detail page of the newly created toilet
        context.push('/toilet/$manualId');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Toilet Manually')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Toilet Name (e.g. Central Park Public Restroom)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Location (Defaults to Istanbul for MVP)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _lngCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create Toilet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
