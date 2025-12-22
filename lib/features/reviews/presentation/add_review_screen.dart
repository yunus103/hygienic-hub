import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/reviews_repository.dart';

class AddReviewScreen extends StatefulWidget {
  final String toiletId;
  const AddReviewScreen({super.key, required this.toiletId});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _commentCtrl = TextEditingController();
  double _overall = 4;
  bool _isFree = true;
  bool _isAccessible = false;
  bool _hasSupplies = true;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      final repo = ReviewsRepository(FirebaseFirestore.instance);

      await repo.createReview(
        toiletId: widget.toiletId,
        userId: uid,
        overall: _overall,
        comment: _commentCtrl.text.trim(),
        isFree: _isFree,
        isAccessible: _isAccessible,
        hasSupplies: _hasSupplies,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Review')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Toilet: ${widget.toiletId}'),
            const SizedBox(height: 16),

            Row(
              children: [
                const Text('Overall: '),
                Expanded(
                  child: Slider(
                    value: _overall,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _overall.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _overall = v),
                  ),
                ),
              ],
            ),

            TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(labelText: 'Comment'),
            ),

            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Free'),
              value: _isFree,
              onChanged: (v) => setState(() => _isFree = v),
            ),
            SwitchListTile(
              title: const Text('Accessible'),
              value: _isAccessible,
              onChanged: (v) => setState(() => _isAccessible = v),
            ),
            SwitchListTile(
              title: const Text('Supplies available'),
              value: _hasSupplies,
              onChanged: (v) => setState(() => _hasSupplies = v),
            ),

            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const Text('Saving...')
                  : const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }
}
