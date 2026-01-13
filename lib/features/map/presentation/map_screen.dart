import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../map/data/places_repository.dart';
import 'filter_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Başlangıç Konumu
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 13,
  );

  // Controller & State
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _filteredToilets = [];

  bool _permissionGranted = false;
  bool _isListView = false;

  // Filtre State
  ToiletFilter _currentFilter = ToiletFilter();

  // Seçili Tuvalet (Preview Card İçin)
  Map<String, dynamic>? _selectedToilet;
  String? _selectedToiletId;

  // Repository & Veriler
  late final PlacesRepository _placesRepo;
  PlaceDetails? _selectedPlaceDetails;
  Position? _userPosition;

  LatLng _centerPosition = const LatLng(41.0082, 28.9784);

  @override
  void initState() {
    super.initState();
    const apiKey = String.fromEnvironment('PLACES_API_KEY');
    _placesRepo = PlacesRepository(apiKey);

    _checkLocationPermission();
    _fetchToilets();
  }

  Future<void> _checkLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      if (mounted) setState(() => _permissionGranted = true);

      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _userPosition = pos);
        _sortToiletsByDistance();
      }

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  // --- YENİLENMİŞ VERİ ÇEKME VE FİLTRELEME ---
  void _fetchToilets() {
    FirebaseFirestore.instance.collection('toilets').snapshots().listen((
      snapshot,
    ) {
      final List<Map<String, dynamic>> rawList = [];
      final newMarkers = <Marker>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['docId'] = doc.id;

        // Ortalama Puan Hesabı
        final ratingSum = (data['ratingSum'] ?? 0) as num;
        final ratingCount = (data['ratingCount'] ?? 0) as num;
        final avg = ratingCount == 0
            ? 0.0
            : (ratingSum / ratingCount).toDouble();
        data['avgRating'] = avg;

        // --- YENİ FİLTRE MANTIĞI BURADA ÇAĞRILIYOR ---
        if (!_shouldShowToilet(data, _currentFilter)) continue;

        // Listeye Ekle
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        rawList.add(data);

        // Marker Oluştur
        double hue;
        if (avg >= 4.0)
          hue = BitmapDescriptor.hueGreen;
        else if (avg >= 2.5)
          hue = BitmapDescriptor.hueOrange;
        else
          hue = BitmapDescriptor.hueRed;

        final id = data['id'] as String? ?? doc.id;
        if (id.startsWith('manual_')) hue = BitmapDescriptor.hueAzure;

        final marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () => _onMarkerTapped(id, data),
        );
        newMarkers.add(marker);
      }

      if (mounted) {
        setState(() {
          _filteredToilets = rawList;
          _markers = newMarkers;
        });
        _sortToiletsByDistance();
      }
    });
  }

  // --- YENİ AKILLI FİLTRELEME FONKSİYONU ---
  // Senin istediğin "Admin varsa admin, yoksa topluluk" mantığı burada
  bool _shouldShowToilet(Map<String, dynamic> data, ToiletFilter filter) {
    // 1. Puan Kontrolü (Her zaman geçerli)
    final avg = data['avgRating'] as double;
    if (avg < filter.minRating) return false;

    // 2. Özellik Filtreleri (Helper fonksiyon kullanıyoruz)

    // Engelli Erişimi
    if (filter.onlyAccessible) {
      // "isAccessible" özelliği var mı diye bak
      if (!_hasFeature(data, 'isAccessible')) return false;
    }

    // Bebek Bakım
    if (filter.hasBabyChange) {
      if (!_hasFeature(data, 'hasBabyChange')) return false;
    }

    // Ücret Kontrolü
    if (!filter.showAllPrices) {
      final isFree = _hasFeature(
        data,
        'isFree',
      ); // true ise ücretsiz, false ise ücretli/bilinmiyor

      if (filter.onlyFree) {
        // Sadece ücretsiz istiyor
        if (!isFree) return false;
      } else {
        // Sadece ücretli istiyor (onlyFree = false)
        // Eğer ücretsizse gösterme
        if (isFree) return false;
      }
    }

    return true;
  }

  // --- KRİTİK HELPER: ÖZELLİK VAR MI YOK MU? ---
  bool _hasFeature(Map<String, dynamic> data, String featureKey) {
    final verified = data['verifiedFeatures'] as Map<String, dynamic>?;
    final reported = data['reportedFeatures'] as Map<String, dynamic>?;

    // 1. Önce Verified'a bak (Admin Onayı)
    if (verified != null && verified.containsKey(featureKey)) {
      // Admin ne dediyse odur. True ise var, False ise yok.
      return verified[featureKey] == true;
    }

    // 2. Yoksa Reported'a bak (Topluluk Kararı)
    // Not: Detay sayfasındaki hesaplama (5 evet, 7 hayır) sonucu
    // veritabanına 'reportedFeatures' olarak kaydedilmiş olmalı.
    if (reported != null && reported.containsKey(featureKey)) {
      return reported[featureKey] == true;
    }

    // 3. Hiçbiri yoksa bu özellik yok sayılır
    return false;
  }

  void _sortToiletsByDistance() {
    if (_userPosition == null || _filteredToilets.isEmpty) return;

    _filteredToilets.sort((a, b) {
      final latA = (a['lat'] as num).toDouble();
      final lngA = (a['lng'] as num).toDouble();
      final latB = (b['lat'] as num).toDouble();
      final lngB = (b['lng'] as num).toDouble();

      final distA = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        latA,
        lngA,
      );
      final distB = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        latB,
        lngB,
      );

      return distA.compareTo(distB);
    });

    if (mounted) setState(() {});
  }

  // ... Diğer metodlar aynı kalıyor (_onMarkerTapped, _calculateDistance, build vs.) ...
  // Dosya bütünlüğünü korumak için aşağıyı önceki kodunla aynı tutabilirsin
  // veya önceki verdiğim tam kodun içine sadece yukarıdaki _fetchToilets, _shouldShowToilet ve _hasFeature metodlarını ekleyebilirsin.
  // Kolaylık olsun diye Build metodunu ve devamını da ekliyorum:

  void _onMarkerTapped(String id, Map<String, dynamic> data) async {
    setState(() {
      _selectedToiletId = id;
      _selectedToilet = data;
      _selectedPlaceDetails = null;
    });

    if (!id.startsWith('manual_')) {
      try {
        final details = await _placesRepo.fetchDetails(id);
        if (mounted && _selectedToiletId == id) {
          setState(() => _selectedPlaceDetails = details);
        }
      } catch (_) {}
    }
  }

  String _calculateDistance(double lat, double lng) {
    if (_userPosition == null) return '';
    final dist = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      lat,
      lng,
    );
    if (dist > 1000) return '• ${(dist / 1000).toStringAsFixed(1)} km';
    return '• ${dist.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: !_isListView
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: FloatingActionButton(
                onPressed: () {
                  context.push('/add-manual-toilet', extra: _centerPosition);
                },
                backgroundColor: AppTheme.primary,
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      body: Stack(
        children: [
          // 1. İÇERİK
          _isListView
              ? _buildListView()
              : GoogleMap(
                  initialCameraPosition: _initialCameraPosition,
                  markers: _markers,
                  myLocationEnabled: _permissionGranted,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  onTap: (_) => setState(() => _selectedToilet = null),
                  onCameraMove: (position) {
                    _centerPosition = position.target;
                  },
                ),

          // 2. ÜST BAR
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () async {
                        final result = await context.push<Map<String, dynamic>>(
                          '/search',
                        );
                        if (result != null && _mapController != null) {
                          final lat = result['lat']!;
                          final lng = result['lng']!;
                          _mapController!.animateCamera(
                            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(Icons.search, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Text(
                            'Bir adres veya yer arayın...',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filtre Butonu
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        const Icon(Icons.tune, color: AppTheme.textDark),
                        if (_currentFilter.minRating > 0 ||
                            _currentFilter.onlyFree)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    onPressed: () async {
                      final result = await Navigator.push<ToiletFilter>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FilterScreen(currentFilter: _currentFilter),
                        ),
                      );
                      if (result != null) {
                        setState(() => _currentFilter = result);
                        _fetchToilets();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. ALT KISIM
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_isListView && _selectedToilet != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 70),
                    child: _buildPreviewCard(_selectedToilet!),
                  ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ViewToggleButton(
                            label: 'Harita',
                            isActive: !_isListView,
                            onTap: () => setState(() => _isListView = false),
                          ),
                          _ViewToggleButton(
                            label: 'Liste',
                            isActive: _isListView,
                            onTap: () {
                              setState(() => _isListView = true);
                              _selectedToilet = null;
                            },
                          ),
                        ],
                      ),
                    ),

                    if (!_isListView)
                      FloatingActionButton(
                        onPressed: _checkLocationPermission,
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: const Icon(Icons.my_location, size: 28),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LİSTE VE KART TASARIMLARI (Önceki kodun aynısı) ---
  Widget _buildListView() {
    if (_filteredToilets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "Bu kriterlere uygun tuvalet bulunamadı.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return Container(
      color: AppTheme.bgLight,
      padding: const EdgeInsets.only(
        top: 110,
        bottom: 100,
        left: 16,
        right: 16,
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _filteredToilets.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final toilet = _filteredToilets[index];
          return _buildToiletListItem(toilet);
        },
      ),
    );
  }

  Widget _buildToiletListItem(Map<String, dynamic> t) {
    final name = t['name'] ?? 'Tuvalet';
    final avg = (t['avgRating'] as double).toStringAsFixed(1);
    final type = t['type'] ?? 'Genel';
    final lat = (t['lat'] as num).toDouble();
    final lng = (t['lng'] as num).toDouble();
    final distStr = _calculateDistance(lat, lng);
    final id = t['id'] as String? ?? t['docId'];

    return GestureDetector(
      onTap: () => context.push('/toilet/$id'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.wc, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$type $distStr",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    avg,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[900],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(Map<String, dynamic> t) {
    final name = t['name'] ?? 'Tuvalet';
    final avg = (t['avgRating'] as double).toStringAsFixed(1);
    final lat = (t['lat'] as num).toDouble();
    final lng = (t['lng'] as num).toDouble();
    final distStr = _calculateDistance(lat, lng);
    final photoRef = _selectedPlaceDetails?.photoReference;
    final id = t['id'] as String? ?? t['docId'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      avg,
                      style: const TextStyle(
                        color: AppTheme.ratingMedium,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      distStr,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.push('/toilet/$id'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Detaylar',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
              image: photoRef != null
                  ? DecorationImage(
                      image: NetworkImage(
                        _placesRepo.photoUrl(photoRef, maxWidth: 200),
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoRef == null
                ? const Icon(Icons.wc, color: Colors.grey)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
