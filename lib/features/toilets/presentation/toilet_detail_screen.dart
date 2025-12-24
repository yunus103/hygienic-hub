import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; // Add intl to pubspec.yaml if missing for date formatting
import '../../map/data/places_repository.dart';

class ToiletDetailScreen extends StatefulWidget {
  final String toiletId;
  const ToiletDetailScreen({super.key, required this.toiletId});

  @override
  State<ToiletDetailScreen> createState() => _ToiletDetailScreenState();
}

class _ToiletDetailScreenState extends State<ToiletDetailScreen> {
  late Future<PlaceDetails?> _placeFuture;
  late final PlacesRepository _placesRepo;
  Position? _userPosition;

  // Custom Colors from your design
  final Color _primaryColor = const Color(0xFF4FC3F7);
  final Color _bgLight = const Color(0xFFF6F8F6);

  @override
  void initState() {
    super.initState();
    const apiKey = String.fromEnvironment('PLACES_API_KEY');
    _placesRepo = PlacesRepository(apiKey);
    _placeFuture = _fetchPlaceDetails();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {}
  }

  Future<PlaceDetails?> _fetchPlaceDetails() async {
    if (widget.toiletId.startsWith('manual_')) return null;
    try {
      return await _placesRepo.fetchDetails(widget.toiletId);
    } catch (e) {
      return null;
    }
  }

  String _formatDistance(double lat, double lng) {
    if (_userPosition == null) return '...';
    final distanceInMeters = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      lat,
      lng,
    );
    if (distanceInMeters > 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceInMeters.toInt()}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('toilets')
            .doc(widget.toiletId)
            .snapshots(),
        builder: (context, toiletSnap) {
          if (toiletSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final toiletDoc = toiletSnap.data;
          if (toiletDoc == null || !toiletDoc.exists) {
            return Scaffold(appBar: AppBar(title: const Text('Not Found')));
          }

          final fsData = toiletDoc.data()!;
          final verified = fsData['verified'] == true;
          final verifiedFeatures =
              fsData['verifiedFeatures'] as Map<String, dynamic>?;

          return FutureBuilder<PlaceDetails?>(
            future: _placeFuture,
            builder: (context, placeSnap) {
              final place = placeSnap.data;
              final name = place?.name ?? fsData['name'] ?? 'Toilet';
              final address = place?.address ?? 'No address provided';
              final photoRef = place?.photoReference;

              // Calculate Ratings
              final ratingSum = (fsData['ratingSum'] ?? 0.0) as num;
              final ratingCount = (fsData['ratingCount'] ?? 0) as num;
              final avg = ratingCount == 0 ? 0.0 : (ratingSum / ratingCount);

              final lat = (fsData['lat'] as num).toDouble();
              final lng = (fsData['lng'] as num).toDouble();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('toilets')
                    .doc(widget.toiletId)
                    .collection('reviews')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, reviewSnap) {
                  final reviews = reviewSnap.data?.docs ?? [];

                  // --- AGGREGATE DETAILED STATS ON THE FLY ---
                  double cleanSum = 0;
                  double smellSum = 0;
                  int soapVotes = 0;
                  int babyVotes = 0;
                  int accessibleVotes = 0;

                  for (var r in reviews) {
                    final d = r.data();
                    cleanSum += (d['cleanliness'] ?? 0) as num;
                    smellSum += (d['smell'] ?? 0) as num;
                    if (d['hasSoap'] == true) soapVotes++;
                    if (d['hasBabyChange'] == true) babyVotes++;
                    if (d['isAccessible'] == true) accessibleVotes++;
                  }

                  final cleanAvg = reviews.isEmpty
                      ? 0.0
                      : cleanSum / reviews.length;
                  final smellAvg = reviews.isEmpty
                      ? 0.0
                      : smellSum / reviews.length;

                  // Feature Consensus (> 1 vote to show)
                  final hasSoap = soapVotes > 0;
                  final hasBaby = babyVotes > 0;
                  final isAccessible = verifiedFeatures != null
                      ? verifiedFeatures['isAccessible'] == true
                      : accessibleVotes > 0;

                  return CustomScrollView(
                    slivers: [
                      // --- 1. Top Bar (Sticky) ---
                      SliverAppBar(
                        pinned: true,
                        backgroundColor: _bgLight,
                        surfaceTintColor: Colors.transparent,
                        leading: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                          ),
                          onPressed: () {
                            if (context.canPop())
                              context.pop();
                            else
                              context.go('/map');
                          },
                        ),
                        title: Text(
                          "Tuvalet Detayları",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        centerTitle: true,
                        actions: [
                          IconButton(
                            icon: const Icon(
                              Icons.share,
                              color: Colors.black87,
                            ),
                            onPressed: () {}, // Implement Share later
                          ),
                        ],
                      ),

                      // --- 2. Title & Address ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (verified)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.verified,
                                        color: Colors.blue,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                address,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- 3. Summary Chips ---
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Rating Chip
                              _SummaryChip(
                                icon: Icons.star,
                                color: Colors.amber,
                                bgColor: Colors.amber.shade50,
                                label: avg.toStringAsFixed(1),
                              ),
                              const SizedBox(width: 12),
                              // Distance Chip
                              _SummaryChip(
                                icon: Icons.pin_drop,
                                color: Colors.blue,
                                bgColor: Colors.blue.shade50,
                                label: _formatDistance(lat, lng),
                              ),
                              const SizedBox(width: 12),
                              // Status Chip (Mock)
                              _SummaryChip(
                                icon: Icons.check_circle,
                                color: Colors.green,
                                bgColor: Colors.green.shade50,
                                label:
                                    "Açık", // We can add open/close logic later
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- 4. Images ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.grey[300],
                                image: photoRef != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          _placesRepo.photoUrl(photoRef),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: photoRef == null
                                  ? const Center(
                                      child: Icon(
                                        Icons.wc,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),

                      // --- 5. Features Card ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Özellikler",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (!hasSoap && !hasBaby && !isAccessible)
                                  const Text(
                                    "Henuz hicbir ozellik belirtilmedi.",
                                    style: TextStyle(color: Colors.grey),
                                  ),

                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  childAspectRatio: 3.5,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  children: [
                                    if (isAccessible)
                                      _FeatureRow(
                                        icon: Icons.accessible,
                                        label: "Accessible",
                                        color: _primaryColor,
                                      ),
                                    if (hasBaby)
                                      _FeatureRow(
                                        icon: Icons.baby_changing_station,
                                        label: "Baby Care",
                                        color: _primaryColor,
                                      ),
                                    if (hasSoap)
                                      _FeatureRow(
                                        icon: Icons.soap,
                                        label: "Soap/Supplies",
                                        color: _primaryColor,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- 6. Detailed Ratings Card ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Detailed Ratings",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _DetailedRatingRow(
                                  label: "Cleanliness",
                                  value: cleanAvg,
                                  color: _primaryColor,
                                ),
                                const SizedBox(height: 12),
                                _DetailedRatingRow(
                                  label: "Smell",
                                  value: smellAvg,
                                  color: _primaryColor,
                                ),
                                const SizedBox(height: 12),
                                // Since we don't calculate Accessibility avg, we assume high if flagged
                                if (isAccessible)
                                  _DetailedRatingRow(
                                    label: "Accessibility",
                                    value:
                                        4.8, // Mock value or calculate derived from reports
                                    color: _primaryColor,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- 7. Reviews Header ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Reviews ($ratingCount)",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => context.push(
                                  '/toilet/${widget.toiletId}/add-review',
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text("Write Review"),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- 8. Reviews List ---
                      if (reviews.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "No reviews yet. Be the first!",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final r = reviews[index].data();
                              return _ReviewCard(data: r);
                            }, childCount: reviews.length),
                          ),
                        ),

                      const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String label;

  const _SummaryChip({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }
}

class _DetailedRatingRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _DetailedRatingRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            Text(
              "${value.toStringAsFixed(1)} / 5",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 5,
            backgroundColor: Colors.grey[200],
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // Format Timestamp
    String dateStr = "";
    if (data['createdAt'] != null) {
      final ts = data['createdAt'] as Timestamp;
      // You can use DateFormat.yMMMd().format(ts.toDate()) if you add intl
      dateStr = "${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}";
    }

    final overall = (data['overall'] ?? 0).toString();
    final clean = (data['cleanliness'] ?? 0).toString();
    final smell = (data['smell'] ?? 0).toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "User Review",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ), // Can replace with Username if available
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      overall,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['comment'] ?? '',
            style: TextStyle(color: Colors.grey[800], height: 1.4),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "Cleanliness: $clean",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Text(
                "Smell: $smell",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
