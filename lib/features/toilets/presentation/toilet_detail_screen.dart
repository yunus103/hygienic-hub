import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../map/data/places_repository.dart';

class ToiletDetailScreen extends StatefulWidget {
  final String toiletId;
  const ToiletDetailScreen({super.key, required this.toiletId});

  @override
  State<ToiletDetailScreen> createState() => _ToiletDetailScreenState();
}

class _ToiletDetailScreenState extends State<ToiletDetailScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  late final PlacesRepository _placesRepo;

  @override
  void initState() {
    super.initState();
    // Initialize PlacesRepository with the API Key from environment
    const apiKey = String.fromEnvironment('PLACES_API_KEY');
    _placesRepo = PlacesRepository(apiKey);

    _dataFuture = _fetchCombinedData();
  }

  /// Fetches Firestore data and, if applicable, Google Places details.
  Future<Map<String, dynamic>> _fetchCombinedData() async {
    // 1. Fetch Firestore data (Metadata & Stats)
    final docRef = FirebaseFirestore.instance
        .collection('toilets')
        .doc(widget.toiletId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      // If needed, we could handle "not found in firestore" here,
      // but usually the previous screen ensures it exists.
      throw Exception('Toilet not found in database.');
    }

    final data = snapshot.data()!;
    final source = data['source'] as String?; // 'places' or 'manual'

    PlaceDetails? placeDetails;

    // 2. If source is 'places', fetch live details from Google
    // We do this to get the latest photo and address.
    if (source == 'places') {
      try {
        placeDetails = await _placesRepo.fetchDetails(widget.toiletId);
      } catch (e) {
        debugPrint('Error fetching place details: $e');
        // Fallback: The UI will rely on Firestore name if Place details fail
      }
    }

    return {'firestore': data, 'place': placeDetails};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: Center(child: Text('Error: ${snapshot.error}')),
            );
          }

          final combined = snapshot.data!;
          final fsData = combined['firestore'] as Map<String, dynamic>;
          final PlaceDetails? place = combined['place'];

          // Display Data Priority: Live Place Data > Firestore Data
          final name = place?.name ?? fsData['name'] ?? 'Unknown Toilet';
          final address = place?.address;
          final photoRef = place?.photoReference;

          final ratingSum = (fsData['ratingSum'] ?? 0.0) as num;
          final ratingCount = (fsData['ratingCount'] ?? 0) as num;
          final avg = ratingCount == 0 ? 0.0 : (ratingSum / ratingCount);

          return CustomScrollView(
            slivers: [
              // --- Header with Photo ---
              SliverAppBar(
                expandedHeight: photoRef != null ? 250 : 0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  background: photoRef != null
                      ? Image.network(
                          _placesRepo.photoUrl(photoRef),
                          fit: BoxFit.cover,
                        )
                      : Container(color: Colors.teal),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.rate_review),
                    onPressed: () =>
                        context.push('/toilet/${widget.toiletId}/add-review'),
                  ),
                ],
              ),

              // --- Details Section ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // If no photo, show name as standard text here
                      if (photoRef == null) ...[
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Address
                      if (address != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            avg.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '($ratingCount reviews)',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Reviews',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // --- Reviews List (Live from Firestore) ---
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('toilets')
                    .doc(widget.toiletId)
                    .collection('reviews')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error loading reviews: ${snap.error}'),
                      ),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No reviews yet. Be the first to add one!',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final r = docs[index].data();
                      final overall = (r['overall'] ?? 0) as num;
                      final comment = (r['comment'] ?? '') as String;
                      final isFree = r['isFree'] == true;
                      final isAccessible = r['isAccessible'] == true;
                      final hasSupplies = r['hasSupplies'] == true;

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(overall.toStringAsFixed(0)),
                        ),
                        title: comment.isNotEmpty
                            ? Text(comment)
                            : const Text(
                                'No comment',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _FeatureChip(
                                label: isFree ? 'Free' : 'Paid',
                                isPositive: isFree,
                              ),
                              if (isAccessible)
                                const _FeatureChip(
                                  label: 'Accessible',
                                  isPositive: true,
                                ),
                              if (hasSupplies)
                                const _FeatureChip(
                                  label: 'Supplies',
                                  isPositive: true,
                                ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: docs.length),
                  );
                },
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final bool isPositive;
  const _FeatureChip({required this.label, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPositive
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive ? Colors.green : Colors.grey,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isPositive ? Colors.green[800] : Colors.grey[800],
        ),
      ),
    );
  }
}
