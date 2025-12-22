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
  late Future<PlaceDetails?> _placeFuture;
  late final PlacesRepository _placesRepo;

  @override
  void initState() {
    super.initState();
    const apiKey = String.fromEnvironment('PLACES_API_KEY');
    _placesRepo = PlacesRepository(apiKey);
    _placeFuture = _fetchPlaceDetails();
  }

  Future<PlaceDetails?> _fetchPlaceDetails() async {
    if (widget.toiletId.startsWith('manual_')) return null;
    try {
      return await _placesRepo.fetchDetails(widget.toiletId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. ANA STREAM: Tuvalet bilgilerini dinle
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('toilets')
          .doc(widget.toiletId)
          .snapshots(),
      builder: (context, toiletSnap) {
        if (toiletSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final toiletDoc = toiletSnap.data;
        if (toiletDoc == null || !toiletDoc.exists) {
          return Scaffold(appBar: AppBar(title: const Text('Not Found')));
        }

        final fsData = toiletDoc.data()!;
        final verified = fsData['verified'] == true;
        // Onaylanmış özellikler haritası (Admin girmişse dolu gelir)
        final verifiedFeatures =
            fsData['verifiedFeatures'] as Map<String, dynamic>?;

        return FutureBuilder<PlaceDetails?>(
          future: _placeFuture,
          builder: (context, placeSnap) {
            final place = placeSnap.data;
            final name = place?.name ?? fsData['name'] ?? 'Toilet';
            final address = place?.address;
            final photoRef = place?.photoReference;

            final ratingSum = (fsData['ratingSum'] ?? 0.0) as num;
            final ratingCount = (fsData['ratingCount'] ?? 0) as num;
            final avg = ratingCount == 0 ? 0.0 : (ratingSum / ratingCount);

            return Scaffold(
              body: CustomScrollView(
                slivers: [
                  // --- HEADER ---
                  SliverAppBar(
                    expandedHeight: photoRef != null ? 250 : 120,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // --- MAVİ TİK (Verified Badge) ---
                          if (verified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ],
                        ],
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
                        onPressed: () => context.push(
                          '/toilet/${widget.toiletId}/add-review',
                        ),
                      ),
                    ],
                  ),

                  // --- İÇERİK ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (address != null) ...[
                            Row(
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

                          // --- YILDIZ PUANI ---
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                avg.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '($ratingCount reviews)',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(),

                          // --- ÖZELLİKLER BÖLÜMÜ (AKILLI MANTIK) ---
                          // 2. Yorumları dinleyip özellik analizi yapacağız
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('toilets')
                                .doc(widget.toiletId)
                                .collection('reviews')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, reviewSnap) {
                              // Yorum listesi hazır mı?
                              final reviews = reviewSnap.data?.docs ?? [];

                              // Özellikleri Hesapla ve Göster
                              return _buildFeaturesSection(
                                context,
                                verifiedFeatures,
                                reviews,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- YORUMLAR LİSTESİ ---
                  _buildReviewsList(),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Özelliklerin (Free/Accessible) nasıl gösterileceğine karar veren widget
  Widget _buildFeaturesSection(
    BuildContext context,
    Map<String, dynamic>? verifiedFeatures,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews,
  ) {
    // DURUM 1: Admin tarafından doğrulanmış veri varsa onu göster
    if (verifiedFeatures != null && verifiedFeatures.isNotEmpty) {
      final isFree = verifiedFeatures['isFree'] == true;
      final isAccessible = verifiedFeatures['isAccessible'] == true;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Verified Features",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FeatureChip(
                label: isFree ? 'Free (Verified)' : 'Paid (Verified)',
                icon: isFree ? Icons.money_off : Icons.attach_money,
                color: Colors.blue, // Onaylı renk
              ),
              if (isAccessible)
                const _FeatureChip(
                  label: 'Accessible (Verified)',
                  icon: Icons.accessible,
                  color: Colors.blue,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // DURUM 2: Doğrulanmış veri yoksa, topluluk yorumlarını analiz et
    if (reviews.isEmpty) {
      return const Text(
        "No feature info yet.",
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    // Basit bir sayım yapıyoruz
    int freeVotes = 0;
    int accessibleVotes = 0;
    int total = reviews.length;

    for (var r in reviews) {
      final data = r.data();
      if (data['isFree'] == true) freeVotes++;
      if (data['isAccessible'] == true) accessibleVotes++;
    }

    // %50'den fazla ise "Muhtemelen öyledir" diyoruz
    bool consensusFree = freeVotes > (total / 2);
    bool consensusAccessible =
        accessibleVotes > 0; // Bir kişi bile dediyse gösterelim (MVP için)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people, size: 16, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              "Community Reports ($total votes)",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _FeatureChip(
              label: consensusFree
                  ? 'Likely Free ($freeVotes/$total)'
                  : 'Likely Paid',
              icon: consensusFree ? Icons.money_off : Icons.attach_money,
              color: Colors.orange, // Topluluk rengi
            ),
            if (consensusAccessible)
              _FeatureChip(
                label: 'Accessible? ($accessibleVotes/$total)',
                icon: Icons.accessible,
                color: Colors.orange,
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReviewsList() {
    // Bu kısım zaten StreamBuilder içinde çağırılıyor, duplicate olmaması için
    // sadece listeyi döndüren basit bir yapı kuruyoruz.
    // Yukarıdaki ana build içinde zaten stream var, aslında oradan veriyi alabiliriz
    // ama temizlik açısından şimdilik ayrı bir stream olarak kalsa da olur
    // veya veriyi yukarıdan pass edebiliriz. Basitlik için burada tekrar stream yapıyorum.

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('toilets')
          .doc(widget.toiletId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SliverToBoxAdapter(child: SizedBox());

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No reviews yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final r = docs[index].data();
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: Text((r['overall'] ?? '?').toString()),
              ),
              title: Text(r['comment'] ?? ''),
              subtitle: Text(
                "${r['isFree'] == true ? 'Free' : 'Paid'} • ${r['isAccessible'] == true ? 'Accessible' : 'Not accessible'}",
                style: const TextStyle(fontSize: 12),
              ),
            );
          }, childCount: docs.length),
        );
      },
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _FeatureChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.all(0),
    );
  }
}
