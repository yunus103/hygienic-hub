import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('placeId: $placeId'),
                const SizedBox(height: 8),
                Text('lat: $lat, lng: $lng'),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Reviews: (next step)'),
                Text(
                  'Average: ${avg.toStringAsFixed(1)} (${ratingCount.toInt()} reviews)',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
