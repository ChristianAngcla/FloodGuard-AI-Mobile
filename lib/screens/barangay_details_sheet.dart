import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'home_map_screen.dart';
import '../widgets/weather_card.dart';
import '../services/flood_api_service.dart';

/// Live river-station assessment bottom sheet.
/// Shows: barangay dropdown (associated station), predicted peak with status gauge,
/// and a 24-hour path that interpolates from current WL to the one-step OLS prediction.
class BarangayDetailsSheet extends StatefulWidget {
  final String barangayName;
  final bool isTaglish;
  final bool isDarkMode;

  const BarangayDetailsSheet({
    super.key,
    required this.barangayName,
    required this.isTaglish,
    required this.isDarkMode,
  });

  @override
  State<BarangayDetailsSheet> createState() => _BarangayDetailsSheetState();
}

class _BarangayDetailsSheetState extends State<BarangayDetailsSheet> {
  late String _selectedBarangay;

  @override
  void initState() {
    super.initState();
    _selectedBarangay = widget.barangayName;
    FloodApiService.fetchDailyForecasts().then((_) {
      if (mounted) setState(() {});
    });
  }

  Color _statusBandColor(String? statusBand) {
    switch (statusBand?.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFD32F2F);
      case 'ALARM':
      case 'WARNING':
        return const Color(0xFFFF9800);
      case 'ALERT':
        return const Color(0xFFFBC02D);
      case 'SAFE':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF64748B);
    }
  }

  // ── Data helpers ───────────────────────────────────────────────

  String get _sensorKey =>
      FloodApiService.barangayToSensor[_selectedBarangay] ?? 'sto_nino';

  String get _sensorDisplayName =>
      FloodApiService.sensorDisplayNames[_sensorKey] ?? 'Unknown River';

  double? get _currentWaterLevel {
    final full = FloodApiService.getFullPredictionData();
    if (full == null) return null;
    final sensors = full['live_sensors'] as Map<String, dynamic>?;
    final val = sensors?[_sensorKey];
    return (val is num) ? val.toDouble() : null;
  }

  DailyForecastItem? get _dailyForecast =>
      FloodApiService.getDailyForecastForBarangay(_selectedBarangay);

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF1A2B3C) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subColor = widget.isDarkMode ? Colors.white54 : Colors.grey[600];

    final allBarangays = FloodApiService.barangayToSensor.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.only(top: 12, bottom: 32, left: 20, right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag handle ──
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color:
                            widget.isDarkMode ? Colors.grey[600] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Title ──
                  Text(
                    widget.isTaglish
                        ? 'Live na Pagsusuri ng Panganib'
                        : 'Live Risk Assessment',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Barangay Dropdown ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF253B50)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            widget.isDarkMode ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedBarangay,
                        dropdownColor: widget.isDarkMode
                            ? const Color(0xFF253B50)
                            : Colors.white,
                        icon:
                            Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        items: allBarangays
                            .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBarangay = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Weather Card ──
                  Builder(
                    builder: (context) {
                      final center = HomeMapScreen.barangayCenters[_selectedBarangay] ?? const LatLng(14.6503, 121.1020);
                      return WeatherCard(
                        latitude: center.latitude,
                        longitude: center.longitude,
                        locationName: _selectedBarangay,
                        isDarkMode: widget.isDarkMode,
                        isTaglish: widget.isTaglish,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Forecast header row ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.isTaglish
                              ? 'Pagtataya para sa $_selectedBarangay'
                              : 'Forecast for $_selectedBarangay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sensor: $_sensorDisplayName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Forecast card ──
                  _buildForecastCard(textColor, subColor),
                  const SizedBox(height: 28),

                  // ── Close button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isDarkMode
                            ? const Color(0xFF3784DF).withValues(alpha: 0.2)
                            : const Color(0xFFF4F9FF),
                        foregroundColor: const Color(0xFF3784DF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: const Color(0xFF3784DF).withValues(alpha: 0.3)),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        widget.isTaglish ? 'Isara' : 'Close',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Forecast Card ──────────────────────────────────────────────

  Widget _buildForecastCard(Color textColor, Color? subColor) {
    final daily = _dailyForecast;
    final isTumana = _sensorKey == 'tumana';
    final hasForecast = daily != null && !daily.isUnavailable;
    final forecastLevel = daily?.predictedWaterLevel ?? 0.0;
    final currentLevel = _currentWaterLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF253B50) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── CARD 1: CURRENT LIVE OBSERVED ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isTaglish
                          ? 'KASALUKUYANG ANTAS (LIVE)'
                          : 'CURRENT OBSERVED LEVEL (LIVE)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: subColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (currentLevel != null)
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: currentLevel.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            TextSpan(
                              text: ' m',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        widget.isTaglish ? 'Walang Data' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: subColor,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _sensorDisplayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live FFWS Telemetry',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: widget.isDarkMode ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── CARD 2: DAILY FORECAST HEADER & TARGET ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isTaglish
                        ? 'ARAW-ARAW NA PAGTATAYA'
                        : 'DAILY FORECAST',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    daily?.forecastTargetDate != null && daily!.forecastTargetDate.isNotEmpty
                        ? (widget.isTaglish
                            ? 'Para sa ${daily.forecastTargetDate}'
                            : 'For ${daily.forecastTargetDate}')
                        : (widget.isTaglish ? 'Susunod na Araw' : 'Next Calendar Day'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: subColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: daily?.calculationMode == 'primary_model'
                      ? const Color(0xFFDBEAFE)
                      : (daily?.calculationMode == 'persistence_fallback'
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: daily?.calculationMode == 'primary_model'
                        ? const Color(0xFF93C5FD)
                        : (daily?.calculationMode == 'persistence_fallback'
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Text(
                  daily?.modeDisplayLabel ?? 'FORECAST UNAVAILABLE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: daily?.calculationMode == 'primary_model'
                        ? const Color(0xFF1D4ED8)
                        : (daily?.calculationMode == 'persistence_fallback'
                            ? const Color(0xFFB45309)
                            : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── CARD 3: FORECAST CONTENT ──
          if (hasForecast) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTumana
                            ? (widget.isTaglish ? 'PAGTATAYANG ANTAS SA TUMANA' : 'FORECASTED TUMANA LEVEL')
                            : (widget.isTaglish ? 'PAGTATAYANG MAXIMUM NA ANTAS' : 'FORECASTED DAILY MAXIMUM'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: forecastLevel.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0369A1),
                                height: 1.1,
                              ),
                            ),
                            const TextSpan(
                              text: ' m',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isTumana)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusBandColor(daily.statusBand).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _statusBandColor(daily.statusBand).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          daily.statusBand,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _statusBandColor(daily.statusBand),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Backend Status',
                        style: TextStyle(
                          fontSize: 10,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (isTumana)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  widget.isTaglish
                      ? 'Pang-araw-araw na pagtataya (obserbasyon ng PAGASA sa Tumana). Walang forecast threshold mapping.'
                      : 'Daily decision-support forecast (PAGASA-reported daily Tumana water-level observation). No forecast threshold mapping.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0369A1),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  widget.isTaglish
                      ? 'Pang-araw-araw na pagtataya para sa ${daily.forecastTargetDate.isNotEmpty ? daily.forecastTargetDate : "susunod na araw"}. Ang katayuan ay mula sa opisyal na daily model. Sundin ang opisyal na babala ng PAGASA/MDRRMO.'
                      : 'Decision-support forecast for ${daily.forecastTargetDate.isNotEmpty ? daily.forecastTargetDate : "next calendar day"}. Status is authoritative from backend daily model. Always follow official PAGASA and MDRRMO flood advisories for emergency response.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0369A1),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.isTaglish
                        ? 'HINDI MAGAGAMIT ANG PAGTATAYA'
                        : 'FORECAST UNAVAILABLE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTumana
                        ? (widget.isTaglish
                            ? 'Kailangang kumpletong obserbasyon sa Tumana ay hindi magagamit.'
                            : 'Required completed daily Tumana observation is unavailable.')
                        : (widget.isTaglish
                            ? 'Kulang ang datos para sa daily model at persistence fallback.'
                            : 'Input data incomplete for daily model and persistence fallback.'),
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.isDarkMode ? Colors.white38 : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
