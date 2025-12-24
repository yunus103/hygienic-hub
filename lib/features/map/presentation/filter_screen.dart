import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class ToiletFilter {
  final double minRating;
  final bool onlyFree;
  final bool onlyAccessible;
  final bool hasBabyChange;
  final bool showAllPrices; // "Tümü" seçeneği için

  ToiletFilter({
    this.minRating = 0.0,
    this.onlyFree = false,
    this.onlyAccessible = false,
    this.hasBabyChange = false,
    this.showAllPrices = true,
  });

  // Filtreleri kopyalamak için yardımcı metod
  ToiletFilter copyWith({
    double? minRating,
    bool? onlyFree,
    bool? onlyAccessible,
    bool? hasBabyChange,
    bool? showAllPrices,
  }) {
    return ToiletFilter(
      minRating: minRating ?? this.minRating,
      onlyFree: onlyFree ?? this.onlyFree,
      onlyAccessible: onlyAccessible ?? this.onlyAccessible,
      hasBabyChange: hasBabyChange ?? this.hasBabyChange,
      showAllPrices: showAllPrices ?? this.showAllPrices,
    );
  }
}

class FilterScreen extends StatefulWidget {
  final ToiletFilter currentFilter;

  const FilterScreen({super.key, required this.currentFilter});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late double _minRating;
  late bool _onlyAccessible;
  late bool _hasBabyChange;

  // Ücret Durumu (0: Tümü, 1: Ücretli, 2: Ücretsiz)
  late int _priceOption;

  @override
  void initState() {
    super.initState();
    _minRating = widget.currentFilter.minRating;
    _onlyAccessible = widget.currentFilter.onlyAccessible;
    _hasBabyChange = widget.currentFilter.hasBabyChange;

    if (widget.currentFilter.showAllPrices) {
      _priceOption = 0;
    } else {
      _priceOption = widget.currentFilter.onlyFree ? 2 : 1;
    }
  }

  void _resetFilters() {
    setState(() {
      _minRating = 0.0;
      _onlyAccessible = false;
      _hasBabyChange = false;
      _priceOption = 0;
    });
  }

  void _applyFilters() {
    final filter = ToiletFilter(
      minRating: _minRating,
      onlyAccessible: _onlyAccessible,
      hasBabyChange: _hasBabyChange,
      showAllPrices: _priceOption == 0,
      onlyFree: _priceOption == 2,
    );
    context.pop(filter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      // --- HEADER ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Filtrele",
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: const Text(
              "Sıfırla",
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              child: Column(
                children: [
                  // --- MINIMUM PUAN ---
                  _buildSectionTitle("Minimum Puan"),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < _minRating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 28,
                                );
                              }),
                            ),
                            Text(
                              _minRating == 0
                                  ? "Tümü"
                                  : "${_minRating.toStringAsFixed(1)} ve üzeri",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primary,
                            inactiveTrackColor: Colors.grey[200],
                            thumbColor: AppTheme.primary,
                            overlayColor: AppTheme.primary.withOpacity(0.1),
                          ),
                          child: Slider(
                            value: _minRating,
                            min: 0,
                            max: 5,
                            divisions: 5,
                            onChanged: (val) =>
                                setState(() => _minRating = val),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- OLANAKLAR ---
                  const SizedBox(height: 16),
                  _buildSectionTitle("Olanaklar"),
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          icon: Icons.accessible,
                          label: "Engelli Erişimi",
                          value: _onlyAccessible,
                          onChanged: (v) => setState(() => _onlyAccessible = v),
                        ),
                        _buildDivider(),
                        _buildSwitchRow(
                          icon: Icons.baby_changing_station,
                          label: "Bebek Bakım Odası",
                          value: _hasBabyChange,
                          onChanged: (v) => setState(() => _hasBabyChange = v),
                        ),
                      ],
                    ),
                  ),

                  // --- DURUM (Ücret) ---
                  const SizedBox(height: 16),
                  _buildSectionTitle("Durum"),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Ücret Durumu",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildPriceOption(0, "Tümü")),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPriceOption(1, "Ücretli")),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPriceOption(2, "Ücretsiz")),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- FOOTER BUTONU ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: AppTheme.primary.withOpacity(0.4),
                ),
                child: const Text(
                  "Sonuçları Göster",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.bgLight,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceOption(int value, String label) {
    final isSelected = _priceOption == value;
    return GestureDetector(
      onTap: () => setState(() => _priceOption = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[200], indent: 68);
  }
}
