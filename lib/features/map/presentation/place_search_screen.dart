import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/places_repository.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<PlacePrediction> _results = [];
  late final PlacesRepository _places;

  @override
  void initState() {
    super.initState();
    const apiKey = String.fromEnvironment('PLACES_API_KEY');
    _places = PlacesRepository(apiKey);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (v.isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final list = await _places.autocomplete(v);
        if (mounted) setState(() => _results = list);
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _select(PlacePrediction p) async {
    try {
      // Yükleniyor göstergesi
      setState(() {
        _loading = true;
        _error = null;
      });

      // Koordinat detaylarını çekiyoruz
      final details = await _places.fetchDetails(p.placeId);

      if (mounted) {
        // Seçilen veriyi geri gönderiyoruz
        // Not: Map<String, dynamic> olarak gönderiyoruz ki hem sayı hem yazı gidebilsin.
        context.pop({
          'placeId': details.placeId,
          'name': details.name,
          'lat': details.lat,
          'lng': details.lng,
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Konum detayı alınamadı: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Ara'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Mekan ara (Cafe, AVM, Park...)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 12),

            // --- GERİ GELEN BUTON ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/add-manual-toilet'),
                icon: const Icon(Icons.add_location_alt),
                label: const Text("Listede yok mu? Manuel Ekle"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // ------------------------
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.place, color: Colors.grey),
                    title: Text(
                      r.mainText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(r.secondaryText),
                    onTap: () => _select(r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
