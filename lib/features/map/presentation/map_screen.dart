import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Başlangıç: İstanbul
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 12,
  );

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _fetchToiletsAndCreateMarkers();
  }

  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      if (mounted) setState(() => _permissionGranted = true);

      final position = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  void _fetchToiletsAndCreateMarkers() {
    FirebaseFirestore.instance.collection('toilets').snapshots().listen((
      snapshot,
    ) {
      final newMarkers = <Marker>{};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final id = (data['id'] as String?) ?? doc.id;
          final name = (data['name'] as String?) ?? 'Toilet';

          double? lat = _parseCoordinate(data['lat']);
          double? lng = _parseCoordinate(data['lng']);

          if (lat == null || lng == null) continue;

          final isManual = id.startsWith('manual_');
          final hue = isManual
              ? BitmapDescriptor.hueBlue
              : BitmapDescriptor.hueRed;

          final marker = Marker(
            markerId: MarkerId(id),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(
              title: name,
              snippet: 'Tap for details',
              onTap: () => context.push('/toilet/$id'),
            ),
          );

          newMarkers.add(marker);
        } catch (e) {
          // Hatalı kayıtları sessizce atla
        }
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    });
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _zoomToAllMarkers() {
    if (_markers.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    for (final m in _markers) {
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    if (_markers.length == 1) {
      final pos = _markers.first.position;
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
    } else {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            myLocationEnabled: _permissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_permissionGranted) _checkLocationPermission();
            },
          ),

          // Arama Çubuğu
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: InkWell(
                onTap: () => context.push('/search'),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 12),
                      Text(
                        'Search for toilets...',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Butonlar
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoomBtn',
            onPressed: _zoomToAllMarkers,
            backgroundColor: Colors.white,
            child: const Icon(Icons.map, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'addBtn',
            onPressed: () => context.push('/add-manual-toilet'),
            child: const Icon(Icons.add_location_alt),
          ),
        ],
      ),
    );
  }
}
