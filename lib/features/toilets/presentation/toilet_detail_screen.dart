import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ToiletDetailScreen extends StatelessWidget {
  final String placeId;
  const ToiletDetailScreen({super.key, required this.placeId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('toilets').doc(placeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toilet Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review),
            onPressed: () => context.push('/toilet/$placeId/add-review'),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: ref.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            return Center(child: Text('Toilet not found: $placeId'));
          }

          final data = doc.data()!;
          final name = (data['name'] ?? 'Unnamed') as String;
          final lat = data['lat'];
          final lng = data['lng'];

          final ratingSum = (data['ratingSum'] ?? 0.0) as num;
          final ratingCount = (data['ratingCount'] ?? 0) as num;
          final avg = ratingCount == 0 ? 0.0 : (ratingSum / ratingCount);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ÜST BİLGİLER ---
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Average: ${avg.toStringAsFixed(1)} ($ratingCount reviews)',
                ),
                const SizedBox(height: 8),
                Text('lat: $lat, lng: $lng'),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),

                // --- ALT: REVIEW LİSTESİ ---
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('toilets')
                        .doc(placeId)
                        .collection('reviews')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snap.hasError) {
                        return Center(
                          child: Text('Reviews error: ${snap.error}'),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('No reviews yet.'));
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final r = docs[i].data();
                          final overall = (r['overall'] ?? 0) as num;
                          final comment = (r['comment'] ?? '') as String;

                          final isFree = r['isFree'] == true;
                          final isAccessible = r['isAccessible'] == true;
                          final hasSupplies = r['hasSupplies'] == true;

                          return ListTile(
                            title: Text('⭐ ${overall.toStringAsFixed(0)}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (comment.isNotEmpty) Text(comment),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Chip(label: Text(isFree ? 'Free' : 'Paid')),
                                    Chip(
                                      label: Text(
                                        isAccessible
                                            ? 'Accessible'
                                            : 'Not accessible',
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        hasSupplies
                                            ? 'Supplies'
                                            : 'No supplies',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
