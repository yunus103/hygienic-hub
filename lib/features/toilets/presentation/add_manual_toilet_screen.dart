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
  // Kontrolcüler
  final _nameCtrl = TextEditingController();

  // Konum (Varsayılan: İstanbul)
  LatLng _pickedLocation = const LatLng(41.0082, 28.9784);
  GoogleMapController? _mapController;

  // Yeni Alanlar
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

  // Özellikler
  bool _isFree = true;
  bool _isAccessible = false;
  bool _hasBabyChange = false;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  Future<void> _locateUser() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          final latLng = LatLng(pos.latitude, pos.longitude);
          setState(() => _pickedLocation = latLng);
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }
      }
    } catch (_) {}
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

  // TimeOfDay'i "08:00" formatına çevirir
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
      final manualId = 'manual_${DateTime.now().millisecondsSinceEpoch}';

      await repo.createIfNotExists(
        id: manualId,
        name: _nameCtrl.text.trim(),
        lat: _pickedLocation.latitude,
        lng: _pickedLocation.longitude,
        createdBy: uid,
        source: 'manual',

        // Yeni alanlar
        type: _selectedType,
        openingTime: _formatTime(_openTime),
        closingTime: _formatTime(_closeTime),
        isFree: _isFree,
        isAccessible: _isAccessible,
        hasBabyChange: _hasBabyChange,
      );

      if (mounted) {
        context.pushReplacement('/toilet/$manualId');
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
    // Tasarım Renkleri
    const Color primaryColor = Color(0xFF34C759); // Yeşil buton
    const Color secondaryColor = Color(0xFF5AC8FA); // Mavi vurgular
    const Color bgColor = Color(0xFFF2F2F7);
    const Color cardColor = Colors.white;
    const Color borderColor = Color(0xFFE5E5EA);

    return Scaffold(
      backgroundColor: bgColor,
      // Klavye açıldığında haritanın ezilmesini önlemek için
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
          // --- BÖLÜM 1: İNTERAKTİF HARİTA (Üst Kısım) ---
          // Kullanıcı haritayı kaydırarak konumu belirler (Eski mantık)
          Expanded(
            flex: 4, // Ekranın %40'ı harita
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedLocation,
                    zoom: 16,
                  ),
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  onCameraMove: (pos) => _pickedLocation = pos.target,
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),
                // Ortadaki Sabit İğne
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
                // "Konumumu Bul" butonu
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    backgroundColor: cardColor,
                    child: const Icon(Icons.my_location, color: secondaryColor),
                    onPressed: _locateUser,
                  ),
                ),
                // Bilgi Etiketi
                Positioned(
                  top: 16,
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
                          const BoxShadow(color: Colors.black12, blurRadius: 4),
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

          // --- BÖLÜM 2: DETAY FORMU (Alt Kısım) ---
          Expanded(
            flex: 6, // Ekranın %60'ı form
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
                    // İsim
                    _buildInputLabel("Tuvalet Adı"),
                    TextField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration("Örn. Taksim Meydan WC"),
                    ),

                    const SizedBox(height: 16),

                    // Tür Seçimi
                    _buildInputLabel("Türü"),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isExpanded: true,
                          items: _types.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedType = val!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Özellikler
                    _buildInputLabel("Özellikler"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: "Ücretsiz",
                          isSelected: _isFree,
                          onTap: () => setState(() => _isFree = !_isFree),
                        ),
                        _FilterChip(
                          label: "Engelli Dostu",
                          isSelected: _isAccessible,
                          onTap: () =>
                              setState(() => _isAccessible = !_isAccessible),
                        ),
                        _FilterChip(
                          label: "Bebek Bakım",
                          isSelected: _hasBabyChange,
                          onTap: () =>
                              setState(() => _hasBabyChange = !_hasBabyChange),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Çalışma Saatleri
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

                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
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
                    const SizedBox(height: 40), // Alt boşluk
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---

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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF5AC8FA) : Colors.grey[700];
    final bgColor = isSelected
        ? const Color(0xFF5AC8FA).withOpacity(0.15)
        : Colors.white;
    final borderColor = isSelected
        ? const Color(0xFF5AC8FA)
        : const Color(0xFFE5E5EA);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 18, color: Color(0xFF5AC8FA)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF007AFF) : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
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
    // Türkçe saat formatı (HH:mm)
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final timeStr = "$hour:$minute";

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
        ],
      ),
    );
  }
}
