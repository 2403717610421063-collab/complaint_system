import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:complaint_system/services/billing_engine.dart';
import '../services/app_localizations.dart';

class BillingCalculatorPage extends StatefulWidget {
  @override
  _BillingCalculatorPageState createState() => _BillingCalculatorPageState();
}

class _BillingCalculatorPageState extends State<BillingCalculatorPage>
    with TickerProviderStateMixin {
  final TextEditingController _unitController = TextEditingController();

  double _totalBill = 0.0;
  List<String> _breakdown = [];
  String _connectionType = "Domestic";
  bool _hasResult = false;

  late AnimationController _resultCtrl;
  late Animation<double> _resultFade;
  late Animation<Offset> _resultSlide;

  @override
  void initState() {
    super.initState();
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _unitController.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  void _onCalculate() {
    final double units = double.tryParse(_unitController.text) ?? 0;
    if (units <= 0) {
      setState(() => _hasResult = false);
      _resultCtrl.reverse();
      return;
    }
    final result = BillingEngine.calculateBill(units, _connectionType);
    setState(() {
      _totalBill = result['total'];
      _breakdown = List<String>.from(result['breakdown']);
      _hasResult = true;
    });
    _resultCtrl.forward(from: 0);
  }

  // ─── Type config ─────────────────────────────────────────────────────────────

  Map<String, Map<String, dynamic>> get _typeConfig => {
    'Domestic': {
      'icon': Icons.home_rounded,
      'color': const Color(0xFF7B2FBE),
      'bg': const Color(0xFFF3E8FF),
      'desc': AppLocalizations.of(context)?.translate('residential_use') ?? 'Residential use',
    },
    'Commercial': {
      'icon': Icons.store_rounded,
      'color': const Color(0xFF0EA5E9),
      'bg': const Color(0xFFE0F2FE),
      'desc': AppLocalizations.of(context)?.translate('business_shops') ?? 'Business & shops',
    },
    'Industrial': {
      'icon': Icons.factory_rounded,
      'color': const Color(0xFFF97316),
      'bg': const Color(0xFFFFF7ED),
      'desc': AppLocalizations.of(context)?.translate('heavy_industry') ?? 'Heavy industry',
    },
  };

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FA),
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HEADER ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader()),

          // ── CONNECTION TYPE ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildConnectionTypeSection(),
            ),
          ),

          // ── UNIT INPUT ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildUnitInput(),
            ),
          ),

          // ── RESULT CARD ─────────────────────────────────────────────────────
          if (_hasResult)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: FadeTransition(
                  opacity: _resultFade,
                  child: SlideTransition(
                    position: _resultSlide,
                    child: _buildResultCard(),
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: _buildHintCard(),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final cfg = _typeConfig[_connectionType]!;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B2FBE), Color(0xFF4A1680), Color(0xFF2D0E5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -30,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 10, right: 80,
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB06AFF).withOpacity(0.18),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.translate('electricity_bill') ?? 'Electricity Bill',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)?.translate('estimate_charges') ?? 'Estimate your electricity charges',
                          style: GoogleFonts.nunito(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Animated icon badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25), width: 1.5),
                    ),
                    child: Icon(
                      cfg['icon'] as IconData,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Connection Type ──────────────────────────────────────────────────────────

  Widget _buildConnectionTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.electrical_services_rounded,
                    color: Color(0xFF7B2FBE), size: 15),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context)?.translate('connection_type') ?? 'Connection Type',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E0A3C),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: _typeConfig.entries.map((entry) {
            final isSelected = _connectionType == entry.key;
            final cfg = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: entry.key != 'Industrial' ? 10 : 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _connectionType = entry.key);
                    _onCalculate();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (cfg['color'] as Color)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? (cfg['color'] as Color)
                            : const Color(0xFFE9D8FD),
                        width: isSelected ? 0 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: (cfg['color'] as Color)
                              .withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        )
                      ]
                          : [
                        BoxShadow(
                          color:
                          const Color(0xFF4A1680).withOpacity(0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          cfg['icon'] as IconData,
                          color: isSelected
                              ? Colors.white
                              : (cfg['color'] as Color),
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)?.translate(entry.key.toLowerCase()) ?? entry.key,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1E0A3C),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cfg['desc'] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white.withOpacity(0.75)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Unit Input ───────────────────────────────────────────────────────────────

  Widget _buildUnitInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.09),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Color(0xFF7B2FBE), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context)?.translate('units_consumed') ?? 'Units Consumed',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E0A3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _unitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) => _onCalculate(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E0A3C),
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCBD5E1),
              ),
              suffixText: 'kWh',
              suffixStyle: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7B2FBE),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F5FF),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE9D8FD), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                const BorderSide(color: Color(0xFF7B2FBE), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Quick unit presets
          Row(
            children: [50, 100, 200, 500].map((unit) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    _unitController.text = unit.toString();
                    _onCalculate();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFD8B4FE), width: 1),
                    ),
                    child: Text(
                      '$unit',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7B2FBE),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Result Card ─────────────────────────────────────────────────────────────

  Widget _buildResultCard() {
    final cfg = _typeConfig[_connectionType]!;
    final color = cfg['color'] as Color;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total bill banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7B2FBE),
                  const Color(0xFF4A1680),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)?.translate('total_estimated_bill') ?? 'Total Estimated Bill',
                      style: GoogleFonts.nunito(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '₹${_totalBill.toStringAsFixed(2)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_connectionType · ${_unitController.text} kWh',
                    style: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Breakdown
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.list_alt_rounded,
                          color: Color(0xFF7B2FBE), size: 15),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)?.translate('charge_breakdown') ?? 'Charge Breakdown',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E0A3C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._breakdown.asMap().entries.map((entry) {
                  final isLast = entry.key == _breakdown.length - 1;
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isLast
                              ? const Color(0xFFF3E8FF)
                              : const Color(0xFFFAF8FF),
                          borderRadius: BorderRadius.circular(12),
                          border: isLast
                              ? Border.all(
                              color: const Color(0xFFD8B4FE), width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isLast
                                  ? Icons.summarize_rounded
                                  : Icons.circle,
                              size: isLast ? 14 : 7,
                              color: isLast
                                  ? const Color(0xFF7B2FBE)
                                  : const Color(0xFFB06AFF),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: GoogleFonts.nunito(
                                  fontSize: isLast ? 13 : 12.5,
                                  fontWeight: isLast
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isLast
                                      ? const Color(0xFF4A1680)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) const SizedBox(height: 6),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hint Card ────────────────────────────────────────────────────────────────

  Widget _buildHintCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D8FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3E8FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calculate_outlined,
                color: Color(0xFF7B2FBE), size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context)?.translate('enter_units') ?? 'Enter Units to Calculate',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E0A3C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)?.translate('type_units_hint') ?? 'Type the number of units consumed above\nto see your estimated bill instantly',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}