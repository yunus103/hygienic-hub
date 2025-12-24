import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/reviews_repository.dart';

class AddReviewScreen extends StatefulWidget {
  final String toiletId;
  const AddReviewScreen({super.key, required this.toiletId});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  // Değerlendirme Değişkenleri
  double _overallRating = 3.0; // Genel
  double _cleanlinessRating = 3.0; // Hijyen
  double _smellRating = 3.0; // Koku

  // Özellikler (Evet/Hayır Soruları)
  bool _isFree = true; // Varsayılan: Ücretsiz
  bool _isAccessible = false;
  bool _hasSoap = false;
  bool _hasBabyChange = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final repo = ReviewsRepository(FirebaseFirestore.instance);

      await repo.addReview(
        toiletId: widget.toiletId,
        userId: uid,
        overall: _overallRating,
        comment: _commentCtrl.text.trim(),
        cleanliness: _cleanlinessRating,
        smell: _smellRating,
        isFree: _isFree,
        isAccessible: _isAccessible,
        hasSoap: _hasSoap,
        hasBabyChange: _hasBabyChange,
      );

      if (mounted) {
        context.pop(); // Detay ekranına geri dön
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Değerlendirme kaydedildi! Teşekkürler.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Değerlendir')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. GENEL PUANLAMA
            const Center(
              child: Text(
                "Genel Puan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return IconButton(
                    iconSize: 40,
                    icon: Icon(
                      index < _overallRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () =>
                        setState(() => _overallRating = index + 1.0),
                  );
                }),
              ),
            ),
            const Divider(height: 40),

            // 2. DETAYLI PUANLAMA (SLIDERS)
            _buildSliderRow(
              "Temizlik",
              _cleanlinessRating,
              (val) => setState(() => _cleanlinessRating = val),
              Icons.cleaning_services,
            ),
            _buildSliderRow(
              "Koku Durumu",
              _smellRating,
              (val) => setState(() => _smellRating = val),
              Icons.air,
            ),

            const Divider(height: 40),

            // 3. ÖZELLİKLER (CHIPS/SWITCHES)
            const Text(
              "Özellikler",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text("Ücretsiz"),
              subtitle: const Text("Giriş ücreti yok"),
              value: _isFree,
              secondary: const Icon(Icons.money_off, color: Colors.green),
              onChanged: (v) => setState(() => _isFree = v),
            ),
            SwitchListTile(
              title: const Text("Erişilebilir"),
              subtitle: const Text("Engelli kullanımına uygun"),
              value: _isAccessible,
              secondary: const Icon(Icons.accessible, color: Colors.blue),
              onChanged: (v) => setState(() => _isAccessible = v),
            ),
            SwitchListTile(
              title: const Text("Hijyen Malzemeleri"),
              subtitle: const Text("Sabun, kağıt havlu var"),
              value: _hasSoap,
              secondary: const Icon(Icons.soap, color: Colors.teal),
              onChanged: (v) => setState(() => _hasSoap = v),
            ),
            SwitchListTile(
              title: const Text("Bebek Bakım"),
              subtitle: const Text("Alt değiştirme ünitesi var"),
              value: _hasBabyChange,
              secondary: const Icon(Icons.child_care, color: Colors.pink),
              onChanged: (v) => setState(() => _hasBabyChange = v),
            ),

            const Divider(height: 40),

            // 4. YORUM VE KAYDET
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Yorumunuz (Opsiyonel)',
                border: OutlineInputBorder(),
                hintText: 'Deneyiminizi paylaşın...',
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Değerlendirmeyi Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    ValueChanged<double> onChanged,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              "$label: ${value.toInt()}/5",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 4,
          label: value.toInt().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
