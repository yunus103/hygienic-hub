import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/toilets_repository.dart';

class AddManualToiletScreen extends StatefulWidget {
  const AddManualToiletScreen({super.key});

  @override
  State<AddManualToiletScreen> createState() => _AddManualToiletScreenState();
}

class _AddManualToiletScreenState extends State<AddManualToiletScreen> {
  final _nameCtrl = TextEditingController();

  // Başlangıç: İstanbul (Kullanıcı konumu alınana kadar)
  LatLng _pickedLocation = const LatLng(41.0082, 28.9784);
  GoogleMapController? _mapController;

  bool _loading = false;

  // Özellikler (Varsayılan: False)
  bool _isFree = false;
  bool _isAccessible = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  /// Kullanıcının konumunu bulup haritayı oraya odaklar
  Future<void> _locateUser() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        final latLng = LatLng(pos.latitude, pos.longitude);

        if (mounted) {
          setState(() => _pickedLocation = latLng);
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }
      }
    } catch (e) {
      // Hata olursa varsayılan konumda kalır
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Lütfen tuvalet için bir isim girin.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Giriş yapmalısınız.');

      final repo = ToiletsRepository(FirebaseFirestore.instance);

      // Manuel eklenenler için benzersiz ID
      final manualId = 'manual_${DateTime.now().millisecondsSinceEpoch}';

      // Repository'ye özellikleri gönderiyoruz (reportedFeatures olarak kaydedilecek)
      await repo.createIfNotExists(
        id: manualId,
        name: name,
        lat: _pickedLocation.latitude,
        lng: _pickedLocation.longitude,
        createdBy: uid,
        source: 'manual',
        isFree: _isFree,
        isAccessible: _isAccessible,
      );

      if (mounted) {
        // İşlem başarılı, detay sayfasına yönlendir (veya haritaya dön)
        // pushReplacement kullanarak bu ekranı geçmişten siliyoruz
        context.pushReplacement('/toilet/$manualId');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Tuvalet Ekle')),
      // Klavye açılınca haritanın sıkışmasını önler
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // --- HARİTA SEÇİCİ (Ekranın %45'i) ---
          Expanded(
            flex: 45,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedLocation,
                    zoom: 15,
                  ),
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  // Harita her kaydığında merkezi güncelliyoruz
                  onCameraMove: (position) {
                    _pickedLocation = position.target;
                  },
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                // Ortadaki Sabit İğne (Pin)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: 30,
                    ), // İğne ucunu merkeze getirmek için kaydırma
                    child: Icon(Icons.location_on, size: 40, color: Colors.red),
                  ),
                ),
                // Bilgi etiketi
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Text(
                        'Konumu ayarlamak için haritayı kaydırın',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- FORM ALANI (Ekranın %55'i) ---
          Expanded(
            flex: 55,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tuvalet Detayları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // İsim Alanı
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tuvalet İsmi (Örn: Park Tuvaleti)',
                        hintText: 'Herkesin bulabileceği bir isim verin',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wc),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Özellik Seçimleri (Switch)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Ücretsiz mi?'),
                            subtitle: const Text('Giriş için ücret ödenmiyor'),
                            secondary: const Icon(
                              Icons.money_off,
                              color: Colors.green,
                            ),
                            value: _isFree,
                            onChanged: (v) => setState(() => _isFree = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Engelliye Uygun mu?'),
                            subtitle: const Text(
                              'Tekerlekli sandalye girişi var',
                            ),
                            secondary: const Icon(
                              Icons.accessible,
                              color: Colors.blue,
                            ),
                            value: _isAccessible,
                            onChanged: (v) => setState(() => _isAccessible = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Hata Mesajı
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    // Kaydet Butonu
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _loading ? 'Kaydediliyor...' : 'Tuvaleti Kaydet',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
