import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'home_map_screen.dart';
import '../widgets/weather_card.dart';
import '../services/flood_api_service.dart';
import '../utils/station_thresholds.dart';

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
  }

  StationThresholds get _thr =>
      StationThresholds.fromApiOrDefault(_sensorKey, _riverData);

  Color _alarmColor(double level) {
    final s = _thr.statusFor(level);
    switch (s) {
      case ColorStatus.critical:
        return const Color(0xFFD32F2F);
      case ColorStatus.warning:
        return const Color(0xFFFF9800);
      case ColorStatus.alert:
        return const Color(0xFFFBC02D);
      case ColorStatus.safe:
        return const Color(0xFF4CAF50);
    }
  }

  String _alarmLabel(double level) {
    switch (_thr.statusFor(level)) {
      case ColorStatus.critical:
        return 'CRITICAL';
      case ColorStatus.warning:
        return 'WARNING';
      case ColorStatus.alert:
        return 'ALERT';
      case ColorStatus.safe:
        return 'NORMAL — SAFE';
    }
  }

  String _alarmShortLabel(double level) {
    switch (_thr.statusFor(level)) {
      case ColorStatus.critical:
        return 'CRITICAL';
      case ColorStatus.warning:
        return 'WARNING';
      case ColorStatus.alert:
        return 'ALERT';
      case ColorStatus.safe:
        return 'SAFE';
    }
  }

  // ── Data helpers ───────────────────────────────────────────────

  String get _sensorKey =>
      FloodApiService.barangayToSensor[_selectedBarangay] ?? 'sto_nino';

  String get _sensorDisplayName =>
      FloodApiService.sensorDisplayNames[_sensorKey] ?? 'Unknown River';

  Map<String, dynamic>? get _riverData {
    final full = FloodApiService.getFullPredictionData();
    if (full == null) return null;
    final rivers = full['prediction']?['rivers'] as Map<String, dynamic>?;
    return rivers?[_sensorKey] as Map<String, dynamic>?;
  }

  List<dynamic>? get _timeline {
    final full = FloodApiService.getFullPredictionData();
    if (full == null) return null;
    return full['prediction']?['timeline'] as List<dynamic>?;
  }

  double get _currentWaterLevel {
    final full = FloodApiService.getFullPredictionData();
    if (full == null) return 0.0;
    final sensors = full['live_sensors'] as Map<String, dynamic>?;
    return (sensors?[_sensorKey] ?? 0.0).toDouble();
  }

  double get _peakLevel {
    final insights = _riverData?['time_series_insights'];
    if (insights == null) return _currentWaterLevel;
    return (insights['peak_predicted_level'] ?? _currentWaterLevel).toDouble();
  }

  String get _peakTime {
    final insights = _riverData?['time_series_insights'];
    if (insights == null) return '--';
    return insights['peak_expected_time']?.toString() ?? '--';
  }

  String get _peakTimeShort {
    // Extracts time portion: "May 06, 12 PM" → "12 PM"
    final full = _peakTime;
    final parts = full.split(', ');
    if (parts.length >= 2) return parts.last;
    return full;
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF1A2B3C) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subColor = widget.isDarkMode ? Colors.white : Colors.black;

    final allBarangays = FloodApiService.barangayToSensor.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
          // The sheet is intentionally below the phone status area.
          child: SafeArea(
            top: false,
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

                  // ── 24-Hour Timeline ──
                  Text(
                    widget.isTaglish
                        ? '24-Oras na Landas ng Antas ng Ilog'
                        : '24-Hour River Level Path',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isTaglish
                        ? 'Interpolation mula sa kasalukuyang antas patungo sa isang hakbang na OLS prediksyon (hindi 24 na hiwalay na forecast).'
                        : 'Interpolation from current level to the one-step OLS prediction (not 24 separate forecasts).',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTimeline(textColor, subColor),
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
                        foregroundColor:
                            widget.isDarkMode ? Colors.white : const Color(0xFF3784DF),
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
    final peak = _peakLevel;
    final color = _alarmColor(peak);
    final label = _alarmLabel(peak);

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
          // ── Peak + Status badge row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: projected peak
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROJECTED PEAK (@ ${_peakTimeShort.toUpperCase()})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: subColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: peak.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: 'm',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: color.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Right: status badge + river name
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sensorDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Alarm Gauge Bar ──
          _buildAlarmGauge(peak),
          const SizedBox(height: 16),

          // ── Legend ──
          _buildGaugeLegend(),
        ],
      ),
    );
  }

  // ── Alarm Gauge (station-specific PAGASA thresholds) ───────────

  Widget _buildAlarmGauge(double currentLevel) {
    final thr = _thr;
    const gaugeMin = 0.0;
    final gaugeMax = thr.gaugeMax;
    final clamped = currentLevel.clamp(gaugeMin, gaugeMax);
    final ratio = (clamped - gaugeMin) / (gaugeMax - gaugeMin);

    final alertPos = (thr.alert - gaugeMin) / (gaugeMax - gaugeMin);
    final alarmPos = (thr.alarm - gaugeMin) / (gaugeMax - gaugeMin);
    final critPos = (thr.critical - gaugeMin) / (gaugeMax - gaugeMin);

    String fmt(double m) =>
        '${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 2)}m';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_sensorDisplayName thresholds (EL.m)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _thrChip('Current', currentLevel.toStringAsFixed(2),
                      _alarmColor(currentLevel)),
                  const SizedBox(width: 8),
                  _thrChip('Alert', thr.alert.toStringAsFixed(2),
                      const Color(0xFFFBC02D)),
                  const SizedBox(width: 8),
                  _thrChip('Warning', thr.alarm.toStringAsFixed(2),
                      const Color(0xFFFF9800)),
                  const SizedBox(width: 8),
                  _thrChip('Critical', thr.critical.toStringAsFixed(2),
                      const Color(0xFFD32F2F)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 28,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 14,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.grey[800]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    left: 0,
                    child: Container(
                      height: 14,
                      width: (w * ratio).clamp(0.0, w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        color: _alarmColor(currentLevel),
                      ),
                    ),
                  ),
                  _buildThresholdMarker(
                      w, alertPos, const Color(0xFFFBC02D), fmt(thr.alert)),
                  _buildThresholdMarker(
                      w, alarmPos, const Color(0xFFFF9800), fmt(thr.alarm)),
                  _buildThresholdMarker(
                      w, critPos, const Color(0xFFD32F2F), fmt(thr.critical)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(fmt(gaugeMin),
                style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white : Colors.black)),
            Text(fmt(gaugeMax),
                style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white : Colors.black)),
          ],
        ),
      ],
    );
  }

  Widget _thrChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdMarker(
      double totalWidth, double fraction, Color color, String label) {
    return Positioned(
      left: (totalWidth * fraction - 1.5).clamp(0.0, totalWidth - 3),
      top: 4,
      child: Container(
        width: 3,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }

  Widget _buildGaugeLegend() {
    final thr = _thr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isTaglish
              ? 'Tandaan: Ang prediksyon ay HINDI 100% tumpak. Sundin ang opisyal na babala ng PAGASA/MDRRMO.'
              : 'Note: Predictions are NOT 100% accurate. Always follow official PAGASA/MDRRMO advisories.',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: widget.isDarkMode ? Colors.white : Colors.black,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _legendItem(const Color(0xFFD32F2F),
                'CRITICAL: ≥ ${thr.critical.toStringAsFixed(2)}m'),
            _legendItem(const Color(0xFFFF9800),
                'WARNING: ≥ ${thr.alarm.toStringAsFixed(2)}m'),
            _legendItem(const Color(0xFFFBC02D),
                'ALERT: ≥ ${thr.alert.toStringAsFixed(2)}m'),
            _legendItem(const Color(0xFF4CAF50),
                'SAFE: < ${thr.alert.toStringAsFixed(2)}m'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  // ── 24-Hour Timeline ───────────────────────────────────────────

  Widget _buildTimeline(Color textColor, Color? subColor) {
    final timeline = _timeline;
    if (timeline == null || timeline.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF253B50) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            widget.isTaglish
                ? 'Walang datos ng timeline'
                : 'No timeline data available',
            style: TextStyle(color: subColor, fontSize: 14),
          ),
        ),
      );
    }

    return SizedBox(
      height: 135,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: timeline.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = timeline[index] as Map<String, dynamic>;
          final time = entry['time']?.toString() ?? '';
          final level = (entry[_sensorKey] ?? 0.0).toDouble();
          final color = _alarmColor(level);
          final statusText = _alarmShortLabel(level);

          String shortTime = time;
          final parts = time.split(', ');
          if (parts.length >= 2) shortTime = parts.last;
          if (shortTime.contains(':')) {
            final tParts = shortTime.split(':');
            final cleanHour = tParts[0].trim().replaceFirst(RegExp(r'^0'), '');
            shortTime = '$cleanHour ${shortTime.split(' ').last}';
          }

          return Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  shortTime.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: level.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      TextSpan(
                        text: 'm',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
