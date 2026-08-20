import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'home_map_screen.dart';
import '../widgets/weather_card.dart';
import '../services/flood_api_service.dart';

/// Bottom sheet combining live station telemetry with the separate daily forecast.
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

  String get _sensorKey =>
      FloodApiService.barangayToSensor[_selectedBarangay] ?? 'sto_nino';

  String get _sensorDisplayName =>
      FloodApiService.sensorDisplayNames[_sensorKey] ?? 'Unknown River';

  Map<String, dynamic>? get _riverData {
    final full = FloodApiService.getFullPredictionData();
    final rivers = full?['prediction']?['rivers'];
    if (rivers is! Map) return null;
    final river = rivers[_sensorKey];
    return river is Map ? Map<String, dynamic>.from(river) : null;
  }

  double? get _currentWaterLevel {
    final full = FloodApiService.getFullPredictionData();
    final sensors = full?['live_sensors'];
    if (sensors is! Map) return null;
    final value = sensors[_sensorKey];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  @override
  void initState() {
    super.initState();
    _selectedBarangay = widget.barangayName;
    FloodApiService.fetchDailyForecasts().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF1A2B3C) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subColor = widget.isDarkMode ? Colors.white70 : Colors.black54;
    final barangays = FloodApiService.barangayToSensor.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? Colors.grey[600]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    widget.isTaglish
                        ? 'Live na Pagsusuri ng Panganib'
                        : 'Live Risk Assessment',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textColor),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF253B50)
                          : Colors.white,
                      border: Border.all(
                          color: widget.isDarkMode
                              ? Colors.white12
                              : Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedBarangay,
                        dropdownColor: widget.isDarkMode
                            ? const Color(0xFF253B50)
                            : Colors.white,
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: subColor),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor),
                        items: barangays
                            .map((name) => DropdownMenuItem(
                                value: name, child: Text(name)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedBarangay = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      final center =
                          HomeMapScreen.barangayCenters[_selectedBarangay] ??
                              const LatLng(14.6503, 121.1020);
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
                  Text(
                    '${widget.isTaglish ? 'Sensor' : 'Station'}: $_sensorDisplayName',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: subColor),
                  ),
                  const SizedBox(height: 12),
                  _buildLiveAndDailyCard(textColor, subColor),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close_rounded),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isDarkMode
                            ? const Color(0xFF3784DF)
                            : const Color(0xFFF4F9FF),
                        foregroundColor: widget.isDarkMode
                            ? Colors.white
                            : const Color(0xFF1769AA),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      label: Text(widget.isTaglish ? 'Isara' : 'Close',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildLiveAndDailyCard(Color textColor, Color subColor) {
    final liveLevel = _currentWaterLevel;
    final daily =
        FloodApiService.getDailyForecastForBarangay(_selectedBarangay);
    final liveStatus = _riverData?['status']?.toString().toUpperCase();
    final hasDaily = daily != null && !daily.isUnavailable;
    final cardColor =
        widget.isDarkMode ? const Color(0xFF253B50) : const Color(0xFFF8FAFC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
            widget.isTaglish ? 'KASALUKUYANG DATOS' : 'CURRENT OBSERVATION',
            subColor),
        const SizedBox(height: 6),
        _dataPanel(
          cardColor,
          liveLevel == null
              ? Text(
                  widget.isTaglish
                      ? 'Hindi available ang live water level.'
                      : 'Live water level unavailable.',
                  style: TextStyle(color: textColor))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${liveLevel.toStringAsFixed(2)} m',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: textColor)),
                    if (liveStatus != null)
                      Text(liveStatus,
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: subColor)),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _sectionLabel(
            widget.isTaglish
                ? 'PAGTATAYA SA SUSUNOD NA ARAW'
                : 'NEXT-CALENDAR-DAY FORECAST',
            subColor),
        const SizedBox(height: 6),
        _dataPanel(
          widget.isDarkMode ? cardColor : const Color(0xFFF0F9FF),
          hasDaily
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${daily?.predictedWaterLevel?.toStringAsFixed(2) ?? '--'} m',
                        style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0369A1))),
                    const SizedBox(height: 6),
                    Text('${daily?.statusBand} · ${daily?.modeDisplayLabel}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0369A1))),
                    if (daily.forecastTargetDate.isNotEmpty)
                      Text(daily.forecastTargetDate,
                          style: TextStyle(color: subColor)),
                  ],
                )
              : Text(
                  widget.isTaglish
                      ? 'Hindi available ang daily forecast.'
                      : 'Daily forecast unavailable.',
                  style: TextStyle(color: textColor)),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, Color color) => Text(text,
      style:
          TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color));

  Widget _dataPanel(Color color, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: widget.isDarkMode ? Colors.white12 : Colors.grey.shade200),
        ),
        child: child,
      );
}
