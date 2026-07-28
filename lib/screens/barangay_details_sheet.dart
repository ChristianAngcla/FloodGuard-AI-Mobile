import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'home_map_screen.dart';
import '../widgets/weather_card.dart';
import '../services/flood_api_service.dart';

/// Live Risk Assessment bottom sheet matching the new design.
/// Shows: barangay dropdown, projected peak with alarm gauge,
/// and a 24-hour horizontally-scrollable timeline.
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

  // Alarm thresholds (user spec)
  static const double _greenMax = 15.0;
  static const double _yellowMax = 16.0;
  static const double _orangeMax = 18.0;

  // Gauge range
  static const double _gaugeMin = 0.0;
  static const double _gaugeMax = 20.0;

  @override
  void initState() {
    super.initState();
    _selectedBarangay = widget.barangayName;
  }

  // ── Alarm helpers ──────────────────────────────────────────────

  static Color alarmColor(double level) {
    if (level >= _orangeMax) return const Color(0xFFD32F2F); // Red
    if (level >= _yellowMax) return const Color(0xFFFF9800); // Orange
    if (level >= _greenMax) return const Color(0xFFFBC02D); // Yellow
    return const Color(0xFF4CAF50); // Green
  }

  static String alarmLabel(double level) {
    if (level >= _orangeMax) return 'FORCE EVACUATION';
    if (level >= _yellowMax) return 'PREPARE TO EVACUATE';
    if (level >= _greenMax) return 'ALERT';
    return 'NORMAL — SAFE';
  }

  static String alarmShortLabel(double level) {
    if (level >= _orangeMax) return 'EVACUATE';
    if (level >= _yellowMax) return 'PREPARE';
    if (level >= _greenMax) return 'ALERT';
    return 'NORMAL';
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
    final subColor = widget.isDarkMode ? Colors.white54 : Colors.grey[600];

    final allBarangays = FloodApiService.barangayToSensor.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                Text(
                  widget.isTaglish
                      ? 'Pagtataya para sa $_selectedBarangay'
                      : 'Forecast for $_selectedBarangay',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
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
                  ? '24-Oras na Inaasahang Timeline'
                  : '24-Hour Projected Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimeline(textColor, subColor),
            const SizedBox(height: 28),

            // ── Close button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDarkMode
                      ? const Color(0xFF3784DF).withValues(alpha: 0.2)
                      : const Color(0xFFF4F9FF),
                  foregroundColor: const Color(0xFF3784DF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
    );
  }

  // ── Forecast Card ──────────────────────────────────────────────

  Widget _buildForecastCard(Color textColor, Color? subColor) {
    final peak = _peakLevel;
    final color = alarmColor(peak);
    final label = alarmLabel(peak);

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

  // ── Alarm Gauge ────────────────────────────────────────────────

  Widget _buildAlarmGauge(double currentLevel) {
    // Clamp to gauge range
    final clamped = currentLevel.clamp(_gaugeMin, _gaugeMax);
    final ratio = (clamped - _gaugeMin) / (_gaugeMax - _gaugeMin);

    // Threshold positions as fractions of gauge
    final yellow = (_greenMax - _gaugeMin) / (_gaugeMax - _gaugeMin); // 15m
    final orange = (_yellowMax - _gaugeMin) / (_gaugeMax - _gaugeMin); // 16m
    final red = (_orangeMax - _gaugeMin) / (_gaugeMax - _gaugeMin); // 18m

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background track (grey)
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
                  // Filled portion (colored)
                  Positioned(
                    top: 7,
                    left: 0,
                    child: Container(
                      height: 14,
                      width: w * ratio,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50),
                            ratio > yellow
                                ? const Color(0xFFFBC02D)
                                : const Color(0xFF4CAF50),
                            if (ratio > orange) const Color(0xFFFF9800),
                            if (ratio > red) const Color(0xFFD32F2F),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Threshold markers
                  _buildThresholdMarker(
                      w, yellow, const Color(0xFFFBC02D), '15m'),
                  _buildThresholdMarker(
                      w, orange, const Color(0xFFFF9800), '16m'),
                  _buildThresholdMarker(w, red, const Color(0xFFD32F2F), '18m'),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // Scale labels
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                      left: 0,
                      child: Text('0m',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.isDarkMode
                                  ? Colors.white38
                                  : Colors.grey[500]))),
                  Positioned(
                      left: w * yellow - 10,
                      child: Text('15m',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFBC02D)))),
                  Positioned(
                      left: w * orange - 10,
                      child: Text('16m',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFF9800)))),
                  Positioned(
                      left: w * red - 10,
                      child: Text('18m',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD32F2F)))),
                  Positioned(
                      right: 0,
                      child: Text('20m',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.isDarkMode
                                  ? Colors.white38
                                  : Colors.grey[500]))),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThresholdMarker(
      double totalWidth, double fraction, Color color, String label) {
    return Positioned(
      left: totalWidth * fraction - 1.5,
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

  // ── Legend ──────────────────────────────────────────────────────

  Widget _buildGaugeLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _legendItem(
            const Color(0xFFD32F2F), '3rd ALARM (FORCE EVACUATION): ≥ 18m'),
        _legendItem(
            const Color(0xFFFF9800), '2nd ALARM (PREPARE TO EVACUATE): ≥ 16m'),
        _legendItem(const Color(0xFFFBC02D), '1st ALARM (ALERT): ≥ 15m'),
        _legendItem(const Color(0xFF4CAF50), 'NORMAL (SAFE): < 15m'),
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
            color: widget.isDarkMode ? Colors.white60 : Colors.grey[700],
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
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: timeline.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = timeline[index] as Map<String, dynamic>;
          final time = entry['time']?.toString() ?? '';
          final level = (entry[_sensorKey] ?? 0.0).toDouble();
          final color = alarmColor(level);
          final statusText = alarmShortLabel(level);

          // Parse time: "May 05, 02:06 PM" → "02 PM" or "May 06, 12 AM" → "12 AM"
          String shortTime = time;
          final parts = time.split(', ');
          if (parts.length >= 2) shortTime = parts.last;
          // Simplify "02:06 PM" → "02 PM"
          if (shortTime.contains(':')) {
            final tParts = shortTime.split(':');
            shortTime = '${tParts[0]} ${shortTime.split(' ').last}';
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
