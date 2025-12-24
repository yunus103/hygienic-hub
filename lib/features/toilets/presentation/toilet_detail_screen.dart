import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../map/data/places_repository.dart';
import '../../../../core/theme/app_theme.dart'; // AppTheme sınıfını kullandığımızdan emin olalım

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
    // Tasarım renklerini AppTheme'den veya sabit olarak alabiliriz
    final primaryColor = AppTheme.primary;
    final bgLight = AppTheme.bgLight;

    return Scaffold(
      backgroundColor: bgLight,
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
            return Scaffold(appBar: AppBar(title: const Text('Bulunamadı')));
          }

          final fsData = toiletDoc.data()!;
          final verified = fsData['verified'] == true;
          // Admin onaylı özellikler (Varsa)
          final verifiedFeatures =
              fsData['verifiedFeatures'] as Map<String, dynamic>?;

          // Temel Bilgiler
          final type = fsData['type'] as String? ?? 'Genel';
          final openTime = fsData['openingTime'] as String?;
          final closeTime = fsData['closingTime'] as String?;
          final hoursStr = (openTime != null && closeTime != null)
              ? "$openTime - $closeTime"
              : "7/24 Açık";

          return FutureBuilder<PlaceDetails?>(
            future: _placeFuture,
            builder: (context, placeSnap) {
              final place = placeSnap.data;
              final name = place?.name ?? fsData['name'] ?? 'Tuvalet';
              final address = place?.address ?? 'Adres bilgisi yok';
              final photoRef = place?.photoReference;

              // Puanlar
              final ratingSum = (fsData['ratingSum'] ?? 0.0) as num;
              final ratingCount = (fsData['ratingCount'] ?? 0) as num;
              final avg = ratingCount == 0
                  ? 0.0
                  : (ratingSum / ratingCount).toDouble();

              final lat = (fsData['lat'] as num).toDouble();
              final lng = (fsData['lng'] as num).toDouble();

              // --- YORUMLARI VE DETAYLI PUANLARI ÇEK ---
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('toilets')
                    .doc(widget.toiletId)
                    .collection('reviews')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, reviewSnap) {
                  final reviews = reviewSnap.data?.docs ?? [];

                  // 1. Detaylı Puan Hesaplama (Temizlik & Koku)
                  double cleanSum = 0;
                  double smellSum = 0;

                  // 2. Topluluk Oylaması (Consensus) Hesaplama
                  int freeVotes = 0;
                  int paidVotes = 0;
                  int accessibleVotes = 0;
                  int babyVotes = 0;
                  int soapVotes = 0;

                  for (var r in reviews) {
                    final d = r.data();
                    // Puanlar
                    cleanSum += (d['cleanliness'] ?? 0) as num;
                    smellSum += (d['smell'] ?? 0) as num;

                    // Özellik Oyları
                    if (d['isFree'] == true)
                      freeVotes++;
                    else
                      paidVotes++;
                    if (d['isAccessible'] == true) accessibleVotes++;
                    if (d['hasBabyChange'] == true) babyVotes++;
                    if (d['hasSoap'] == true) soapVotes++;
                  }

                  final cleanAvg = reviews.isEmpty
                      ? 0.0
                      : cleanSum / reviews.length;
                  final smellAvg = reviews.isEmpty
                      ? 0.0
                      : smellSum / reviews.length;

                  // Topluluk Kararları (Eşik değerler)
                  bool isLikelyFree = freeVotes >= paidVotes;
                  bool showFreeStatus = reviews.isNotEmpty;
                  bool hasLikelyAccessible = accessibleVotes > 0;
                  bool hasLikelyBaby = babyVotes > 0;
                  bool hasLikelySoap = soapVotes > 0;

                  return CustomScrollView(
                    slivers: [
                      // --- 1. Üst Bar (Fotoğraf & Başlık) ---
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: photoRef != null ? 250 : 120,
                        backgroundColor: bgLight,
                        surfaceTintColor: Colors.transparent,
                        leading: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
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
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          background: photoRef != null
                              ? Image.network(
                                  _placesRepo.photoUrl(photoRef),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.wc,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                        actions: [
                          Container(
                            margin: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.share,
                                color: Colors.black87,
                              ),
                              onPressed: () {}, // Paylaş butonu (Opsiyonel)
                            ),
                          ),
                        ],
                      ),

                      // --- 2. Başlık & Adres ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 24,
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
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- 3. Özet Bilgi Kartları (Rating, Uzaklık, Saat) ---
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Puan
                              _SummaryChip(
                                icon: Icons.star,
                                color: Colors.amber,
                                bgColor: Colors.amber.shade50,
                                label: avg.toStringAsFixed(1),
                              ),
                              const SizedBox(width: 12),
                              // Mesafe
                              _SummaryChip(
                                icon: Icons.pin_drop,
                                color: Colors.blue,
                                bgColor: Colors.blue.shade50,
                                label: _formatDistance(lat, lng),
                              ),
                              const SizedBox(width: 12),
                              // Saatler
                              _SummaryChip(
                                icon: Icons.access_time,
                                color: Colors.green,
                                bgColor: Colors.green.shade50,
                                label: hoursStr,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- 4. Özellikler Kartı (Akıllı Mantık) ---
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
                              borderRadius: BorderRadius.circular(16),
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Özellikler",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (verifiedFeatures != null)
                                      _StatusBadge(
                                        label: "Doğrulanmış",
                                        color: Colors.blue,
                                      )
                                    else if (reviews.isNotEmpty)
                                      _StatusBadge(
                                        label: "Topluluk Raporu",
                                        color: Colors.orange,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                if (reviews.isEmpty && verifiedFeatures == null)
                                  const Text(
                                    "Henüz özellik bilgisi girilmedi.",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // TÜR
                                    _FeatureChipDisplay(
                                      icon: Icons.category,
                                      label: type,
                                      color: Colors.grey,
                                      isVerified:
                                          true, // Türü ekleyen girdiği için verified sayalım
                                    ),

                                    // ÜCRET DURUMU
                                    if (verifiedFeatures != null) ...[
                                      _FeatureChipDisplay(
                                        icon: verifiedFeatures['isFree'] == true
                                            ? Icons.money_off
                                            : Icons.attach_money,
                                        label:
                                            verifiedFeatures['isFree'] == true
                                            ? "Ücretsiz"
                                            : "Ücretli",
                                        color: Colors.blue,
                                        isVerified: true,
                                      ),
                                    ] else if (showFreeStatus) ...[
                                      _FeatureChipDisplay(
                                        icon: isLikelyFree
                                            ? Icons.money_off
                                            : Icons.attach_money,
                                        label: isLikelyFree
                                            ? "Ücretsiz ($freeVotes teyit)"
                                            : "Ücretli ($paidVotes teyit)",
                                        color: Colors.orange,
                                        isVerified: false,
                                      ),
                                    ],

                                    // ENGELLİ ERİŞİMİ
                                    if (verifiedFeatures != null &&
                                        verifiedFeatures['isAccessible'] ==
                                            true)
                                      const _FeatureChipDisplay(
                                        icon: Icons.accessible,
                                        label: "Engelli Dostu",
                                        color: Colors.blue,
                                        isVerified: true,
                                      )
                                    else if (hasLikelyAccessible)
                                      _FeatureChipDisplay(
                                        icon: Icons.accessible,
                                        label:
                                            "Engelli Dostu ($accessibleVotes teyit)",
                                        color: Colors.orange,
                                        isVerified: false,
                                      ),

                                    // BEBEK BAKIM
                                    if (verifiedFeatures != null &&
                                        verifiedFeatures['hasBabyChange'] ==
                                            true)
                                      const _FeatureChipDisplay(
                                        icon: Icons.baby_changing_station,
                                        label: "Bebek Bakım",
                                        color: Colors.blue,
                                        isVerified: true,
                                      )
                                    else if (hasLikelyBaby)
                                      _FeatureChipDisplay(
                                        icon: Icons.baby_changing_station,
                                        label: "Bebek Bakım ($babyVotes teyit)",
                                        color: Colors.orange,
                                        isVerified: false,
                                      ),

                                    // SABUN/MALZEME
                                    if (hasLikelySoap)
                                      _FeatureChipDisplay(
                                        icon: Icons.soap,
                                        label: "Sabun Var ($soapVotes teyit)",
                                        color: Colors.orange,
                                        isVerified: false,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- 5. Detaylı Puanlama Kartı ---
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
                              borderRadius: BorderRadius.circular(16),
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
                                  "Detaylı Puanlama",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _DetailedRatingRow(
                                  label: "Temizlik",
                                  value: cleanAvg,
                                  color: primaryColor,
                                ),
                                const SizedBox(height: 12),
                                _DetailedRatingRow(
                                  label: "Koku Durumu",
                                  value: smellAvg,
                                  color: primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- 6. Yorumlar Başlığı ve Butonu ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Yorumlar ($ratingCount)",
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
                                label: const Text("Yorum Yaz"),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- 7. Yorum Listesi ---
                      if (reviews.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "Henüz yorum yapılmamış. İlk yorumu sen yap!",
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

// --- YARDIMCI WIDGET'LAR ---

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FeatureChipDisplay extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isVerified;

  const _FeatureChipDisplay({
    required this.icon,
    required this.label,
    required this.color,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isVerified) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle, size: 14, color: color),
          ],
        ],
      ),
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
        const SizedBox(height: 8),
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
    // Tarih Formatlama (Basit)
    String dateStr = "";
    if (data['createdAt'] != null) {
      final ts = data['createdAt'] as Timestamp;
      final dt = ts.toDate();
      dateStr = "${dt.day}.${dt.month}.${dt.year}";
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
                    "Kullanıcı Yorumu",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
          if (data['comment'] != null && data['comment'].isNotEmpty) ...[
            Text(
              data['comment'],
              style: TextStyle(color: Colors.grey[800], height: 1.4),
            ),
            const SizedBox(height: 12),
          ],
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.cleaning_services, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                "Temizlik: $clean",
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(width: 16),
              Icon(Icons.air, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                "Koku: $smell",
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
