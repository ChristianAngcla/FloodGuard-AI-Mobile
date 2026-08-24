import 'package:flutter/material.dart';
import '../services/flood_api_service.dart';

/// Bottom sheet showing FloodGuard DailyForecast for the selected barangay.
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

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 550,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Material(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          ? 'Pagsusuri ng Panganib'
                          : 'Flood Risk Assessment',
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
                    const SizedBox(height: 24),
                    Text(
                      '${widget.isTaglish ? 'Sensor' : 'Station'}: $_sensorDisplayName',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: subColor),
                    ),
                    const SizedBox(height: 12),
                    _buildTelemetryAndDailyCard(textColor, subColor),
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
      ),
    );
  }

  Widget _buildTelemetryAndDailyCard(Color textColor, Color subColor) {
    final daily =
        FloodApiService.getDailyForecastForBarangay(_selectedBarangay);
    final cardColor =
        widget.isDarkMode ? const Color(0xFF253B50) : const Color(0xFFF8FAFC);

    // DEFECT G: only claim "next calendar day" when the dates actually say so.
    final nextDayVerified = daily?.nextCalendarDayVerified ?? false;
    final forecastHeading = nextDayVerified
        ? (widget.isTaglish
            ? 'PAGTATAYA SA SUSUNOD NA ARAW'
            : 'NEXT-CALENDAR-DAY FORECAST')
        : (widget.isTaglish ? 'PANG-ARAW NA PAGTATAYA' : 'DAILY FORECAST');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(forecastHeading, subColor),
        const SizedBox(height: 6),
        _dataPanel(
          widget.isDarkMode ? cardColor : const Color(0xFFF0F9FF),
          _buildDailyForecastContent(daily, textColor, subColor),
        ),
      ],
    );
  }

  Widget _buildDailyForecastContent(
      DailyForecastItem? daily, Color textColor, Color subColor) {
    if (daily == null ||
        daily.isUnavailable ||
        daily.predictedWaterLevel == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isTaglish
                ? 'Hindi available ang pagtataya'
                : 'Forecast unavailable',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          if (daily?.fallbackReason != null &&
              daily!.fallbackReason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              daily.fallbackReason!,
              style: TextStyle(
                fontSize: 12,
                color: subColor,
                height: 1.3,
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${daily.predictedWaterLevel!.toStringAsFixed(2)} m',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0369A1),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${daily.statusBand} · ${daily.modeDisplayLabel}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0369A1),
          ),
        ),
        if (daily.forecastTargetDate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.isTaglish
                  ? 'Para sa: ${daily.forecastTargetDate}'
                  : 'For: ${daily.forecastTargetDate}',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
          ),
        if (daily.sourceDataDate != null && daily.sourceDataDate!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.isTaglish
                  ? 'Batay sa datos ng: ${daily.sourceDataDate}'
                  : 'Based on observations from: ${daily.sourceDataDate}',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
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
