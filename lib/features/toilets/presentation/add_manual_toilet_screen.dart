import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/toilets_repository.dart';

class AddManualToiletScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const AddManualToiletScreen({super.key, this.initialLocation});

  @override
  State<AddManualToiletScreen> createState() => _AddManualToiletScreenState();
}

class _AddManualToiletScreenState extends State<AddManualToiletScreen> {
  final _nameCtrl = TextEditingController();

  // Konum
  late LatLng _pickedLocation;
  GoogleMapController? _mapController;

  // Google Place ID (Eğer aramadan gelirse buraya kaydolacak)
  String? _selectedGooglePlaceId;

  // Form Alanları
  String _selectedType = 'Umumi';
  final List<String> _types = [
    'Umumi',
    'AVM',
    'Restoran',
    'Benzinlik',
    'Park',
    'Cami',
    'Diğer',
  ];

  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _pickedLocation = widget.initialLocation!;
    } else {
      _pickedLocation = const LatLng(41.0082, 28.9784);
      _locateUser(); // Sadece veri gelmediyse kullanıcıyı bulmaya çalış
    }
  }

  Future<void> _locateUser() async {
    // Eğer Google'dan bir yer seçildiyse kullanıcının konumuna gitme (seçimi bozma)
    if (_selectedGooglePlaceId != null) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          _moveCamera(LatLng(pos.latitude, pos.longitude));
        }
      }
    } catch (_) {}
  }

  void _moveCamera(LatLng target) {
    setState(() => _pickedLocation = target);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  // --- İŞTE BU FONKSİYON EKSİKTİ: OTOMATİK DOLDURMA ---
  Future<void> _searchPlace() async {
    // Arama ekranını açıp sonucu (Map olarak) bekliyoruz
    // Not: PlaceSearchScreen'den dönen veri: {placeId, name, lat, lng}
    final result = await context.push<Map<String, dynamic>>('/search');

    if (result != null) {
      final placeId = result['placeId'] as String;
      final name = result['name'] as String;
      final lat = result['lat'] as double;
      final lng = result['lng'] as double;

      setState(() {
        _selectedGooglePlaceId =
            placeId; // ID'yi sakla (Duplicate kontrolü için)
        _nameCtrl.text = name; // İSMİ OTOMATİK DOLDUR!
        _pickedLocation = LatLng(lat, lng); // Konumu güncelle
        _loading = false;

        // İsme göre basit tür tahmini yapıyoruz (Kullanıcıya kolaylık olsun)
        final lowerName = name.toLowerCase();
        if (lowerName.contains('avm') ||
            lowerName.contains('mall') ||
            lowerName.contains('center')) {
          _selectedType = 'AVM';
        } else if (lowerName.contains('cafe') ||
            lowerName.contains('kahve') ||
            lowerName.contains('starbucks') ||
            lowerName.contains('restoran')) {
          _selectedType = 'Restoran';
        } else if (lowerName.contains('cami')) {
          _selectedType = 'Cami';
        } else if (lowerName.contains('park')) {
          _selectedType = 'Park';
        } else if (lowerName.contains('opet') ||
            lowerName.contains('shell') ||
            lowerName.contains('bp')) {
          _selectedType = 'Benzinlik';
        }
      });

      // Haritayı oraya götür
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_pickedLocation, 17),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bilgiler '$name' için otomatik dolduruldu."),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickTime(bool isOpenTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpenTime ? _openTime : _closeTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isOpenTime)
          _openTime = picked;
        else
          _closeTime = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen bir isim girin.')));
      return;
    }

    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final repo = ToiletsRepository(FirebaseFirestore.instance);

      // ID BELİRLEME MANTIĞI:
      // Google'dan seçildiyse onun ID'sini kullan (Böylece aynı yeri 2 kere ekleyemezler)
      // Yoksa manuel ID oluştur.
      final docId =
          _selectedGooglePlaceId ??
          'manual_${DateTime.now().millisecondsSinceEpoch}';
      final source = _selectedGooglePlaceId != null
          ? 'google_places'
          : 'manual';

      await repo.createIfNotExists(
        id: docId,
        name: _nameCtrl.text.trim(),
        lat: _pickedLocation.latitude,
        lng: _pickedLocation.longitude,
        createdBy: uid,
        source: source,
        type: _selectedType,
        openingTime: _formatTime(_openTime),
        closingTime: _formatTime(_closeTime),
      );

      if (mounted) {
        context.pushReplacement('/toilet/$docId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tuvalet başarıyla eklendi!')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF34C759);
    const Color secondaryColor = Color(0xFF5AC8FA);
    const Color bgColor = Color(0xFFF2F2F7);
    const Color borderColor = Color(0xFFE5E5EA);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Yeni Tuvalet Ekle',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: Column(
        children: [
          // --- HARİTA ---
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedLocation,
                    zoom: 16,
                  ),
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  onCameraMove: (pos) {
                    _pickedLocation = pos.target;
                    // Kullanıcı haritayı elle oynatırsa Google ID'yi sıfırlamıyoruz
                    // Belki konumda ufak düzeltme yapıyordur.
                  },
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 30),
                    child: Icon(
                      Icons.location_on,
                      size: 45,
                      color: secondaryColor,
                    ),
                  ),
                ),

                // Konumumu Bul Butonu
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'locBtn',
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: secondaryColor),
                    onPressed: () {
                      _selectedGooglePlaceId = null; // Manuel moda geçiş
                      _locateUser();
                    },
                  ),
                ),

                // --- MEKAN ARA VE DOLDUR BUTONU ---
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _searchPlace, // BURASI OTOMATİK DOLDURMAYA GİDER
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          const BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: const [
                          Icon(Icons.search, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            "Mekanı Ara (Otomatik Doldur)...",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- FORM ---
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: bgColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("Tuvalet Adı"),
                    TextField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration("Örn. Taksim Meydan WC"),
                    ),

                    const SizedBox(height: 16),

                    _buildInputLabel("Türü"),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isExpanded: true,
                          items: _types
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedType = val!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildInputLabel("Çalışma Saatleri"),
                    Row(
                      children: [
                        Expanded(
                          child: _TimePickerField(
                            label: "Açılış",
                            time: _openTime,
                            onTap: () => _pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _TimePickerField(
                            label: "Kapanış",
                            time: _closeTime,
                            onTap: () => _pickTime(false),
                          ),
                        ),
                      ],
                    ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Tuvaleti Ekle",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5AC8FA)),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimePickerField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              timeStr,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
