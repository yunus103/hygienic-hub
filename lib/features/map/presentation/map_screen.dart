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
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 13,
  );

  ToiletFilter _currentFilter = ToiletFilter();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _permissionGranted = false;

  // Seçili Tuvalet (Preview Card İçin)
  Map<String, dynamic>? _selectedToilet;
  String? _selectedToiletId;

  // Google Places Fotoğrafı için repository
  late final PlacesRepository _placesRepo;
  PlaceDetails? _selectedPlaceDetails;

  // Kullanıcı Konumu (Mesafe hesaplamak için)
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    const apiKey = String.fromEnvironment('PLACES_API_KEY');
    _placesRepo = PlacesRepository(apiKey);

    _checkLocationPermission();
    _fetchToiletsAndCreateMarkers();
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
      if (mounted) setState(() => _userPosition = pos);

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  // --- MARKER LOGIC ---
  void _fetchToiletsAndCreateMarkers() {
    // Eski listener varsa kapatmak iyi olur ama MVP'de üstüne yazıyoruz, sorun değil.
    FirebaseFirestore.instance.collection('toilets').snapshots().listen((
      snapshot,
    ) {
      final newMarkers = <Marker>{};

      // Debug için
      // print("Filtre: minRating=${_currentFilter.minRating}, free=${_currentFilter.onlyFree}");

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // --- FİLTRELEME MANTIĞI ---

        // 1. Puan Filtresi
        final ratingSum = (data['ratingSum'] ?? 0) as num;
        final ratingCount = (data['ratingCount'] ?? 0) as num;
        final avg = ratingCount == 0
            ? 0.0
            : (ratingSum / ratingCount).toDouble();

        if (avg < _currentFilter.minRating) continue;

        // 2. Olanaklar (Özellikler reportedFeatures veya verifiedFeatures içinde olabilir)
        // Şimdilik basitleştirilmiş olarak 'reportedFeatures' kullanıyoruz (kullanıcı beyanı)
        final features =
            data['reportedFeatures'] as Map<String, dynamic>? ?? {};

        if (_currentFilter.onlyAccessible) {
          if (features['isAccessible'] != true) continue;
        }

        if (_currentFilter.hasBabyChange) {
          if (features['hasBabyChange'] != true) continue;
        }

        // 3. Ücret Durumu
        if (!_currentFilter.showAllPrices) {
          final isFree = features['isFree'] == true;
          if (_currentFilter.onlyFree && !isFree)
            continue; // Sadece ücretsiz istiyor ama bu ücretli
          if (!_currentFilter.onlyFree && isFree)
            continue; // Sadece ücretli istiyor ama bu ücretsiz
        }

        // --- FİLTREDEN GEÇTİ, MARKER EKLE ---

        final id = data['id'] as String? ?? doc.id;
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();

        if (lat == null || lng == null) continue;

        // Renk Ayarı
        double hue;
        if (avg >= 4.0)
          hue = BitmapDescriptor.hueGreen;
        else if (avg >= 2.5)
          hue = BitmapDescriptor.hueOrange;
        else
          hue = BitmapDescriptor.hueRed;

        if (id.startsWith('manual_')) hue = BitmapDescriptor.hueAzure;

        final marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () => _onMarkerTapped(id, data),
        );
        newMarkers.add(marker);
      }

      if (mounted) setState(() => _markers = newMarkers);
    });
  }

  void _onMarkerTapped(String id, Map<String, dynamic> data) async {
    setState(() {
      _selectedToiletId = id;
      _selectedToilet = data;
      _selectedPlaceDetails = null; // Önce sıfırla
    });

    // Eğer Google Place ise fotoğrafını çek
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
      // Klavye açılınca UI bozulmasın
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. HARİTA KATMANI
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            myLocationEnabled: _permissionGranted,
            myLocationButtonEnabled: false, // Kendi butonumuzu yapacağız
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (ctrl) => _mapController = ctrl,
            onTap: (_) => setState(
              () => _selectedToilet = null,
            ), // Boşluğa basınca seçimi kaldır
          ),

          // 2. ÜST ARAMA ÇUBUĞU (Floating Search Bar)
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
                      onTap: () => context.push('/search'),
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
                    icon: const Icon(Icons.tune, color: AppTheme.textDark),
                    onPressed: () async {
                      // 1. Filtre ekranını aç ve sonucu bekle
                      final result = await Navigator.push<ToiletFilter>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FilterScreen(currentFilter: _currentFilter),
                        ),
                      );

                      // 2. Sonuç varsa filtreyi güncelle ve haritayı yenile
                      if (result != null) {
                        setState(() {
                          _currentFilter = result;
                        });

                        _fetchToiletsAndCreateMarkers(); // Listener'ı yeniden başlatır ve yeni filtreyle okur.
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. ALT KONTROLLER VE PREVIEW CARD
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // --- PREVIEW CARD (Seçim Varsa Göster) ---
                if (_selectedToilet != null) _buildPreviewCard(),

                const SizedBox(height: 16),

                // --- ALT BUTONLAR (Toggle & MyLocation) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Harita / Liste Geçişi
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
                            isActive: true,
                            onTap: () {},
                          ),
                          _ViewToggleButton(
                            label: 'Liste',
                            isActive: false,
                            onTap: () => context.push(
                              '/search',
                            ), // Şimdilik aramaya gitsin
                          ),
                        ],
                      ),
                    ),

                    // Konum Butonu (FAB)
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
      // Manuel Ekle Butonu (Gizli bir şekilde ekleyebiliriz veya arama ekranına taşımıştık zaten)
      // Şimdilik tasarımda olmadığı için kaldırdım, kullanıcı 'Liste' veya 'Arama'dan ekleyebilir.
    );
  }

  Widget _buildPreviewCard() {
    final t = _selectedToilet!;
    final name = t['name'] ?? 'Toilet';
    final ratingSum = (t['ratingSum'] ?? 0) as num;
    final ratingCount = (t['ratingCount'] ?? 0) as num;
    final avg = ratingCount == 0 ? 0.0 : (ratingSum / ratingCount).toDouble();

    final lat = (t['lat'] as num).toDouble();
    final lng = (t['lng'] as num).toDouble();
    final distStr = _calculateDistance(lat, lng);

    final photoRef = _selectedPlaceDetails?.photoReference;

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
          // Sol Taraf: Bilgiler
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
                      avg.toStringAsFixed(1),
                      style: TextStyle(
                        color: avg >= 4
                            ? AppTheme.ratingHigh
                            : (avg >= 2.5
                                  ? AppTheme.ratingMedium
                                  : AppTheme.ratingLow),
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
                  onTap: () => context.push('/toilet/$_selectedToiletId'),
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
          // Sağ Taraf: Resim
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
