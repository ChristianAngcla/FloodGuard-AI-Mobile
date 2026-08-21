import 'package:flutter/material.dart';
import '../services/flood_api_service.dart';

/// Bottom sheet combining PAGASA-reported station telemetry with the separate daily forecast.
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
    );
  }

  Widget _buildTelemetryAndDailyCard(Color textColor, Color subColor) {
    final telemetry =
        FloodApiService.getPagasaTelemetryForBarangay(_selectedBarangay);
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

    final presentationReading =
        FloodApiService.presentationCurrentReadingForBarangay(_selectedBarangay);
    final currentHeading = presentationReading != null
        ? (widget.isTaglish ? 'KASALUKUYANG ANTAS' : 'CURRENT READING')
        : (widget.isTaglish
            ? 'HULING DATOS MULA SA PAGASA'
            : 'LATEST PAGASA READING');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(currentHeading, subColor),
        const SizedBox(height: 6),
        _dataPanel(
          cardColor,
          _buildCurrentObservationContent(telemetry, textColor, subColor),
        ),
        const SizedBox(height: 20),
        _sectionLabel(forecastHeading, subColor),
        const SizedBox(height: 6),
        _dataPanel(
          widget.isDarkMode ? cardColor : const Color(0xFFF0F9FF),
          _buildDailyForecastContent(daily, textColor, subColor),
        ),
      ],
    );
  }

  Widget _buildCurrentObservationContent(
      PagasaTelemetryItem? telemetry, Color textColor, Color subColor) {
    final demoReading =
        FloodApiService.presentationCurrentReadingForBarangay(_selectedBarangay);
    if (demoReading != null) {
      return Text(
        '${demoReading.toStringAsFixed(2)} m',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      );
    }
    if (telemetry == null ||
        telemetry.isUnavailable ||
        telemetry.currentReading == null) {
      final reason = telemetry?.unavailableReasonDisplay ??
          'Telemetry Temporarily Unavailable';
      final hasLkv = telemetry?.lastKnownValidReading != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isTaglish ? 'Hindi Magagamit' : 'Unavailable',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: widget.isDarkMode
                      ? Colors.orange.shade300
                      : const Color(0xFFD97706),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: widget.isDarkMode
                        ? Colors.orange.shade300
                        : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasLkv) ...[
            Text(
              widget.isTaglish
                  ? 'Huling Wastong Datos: ${telemetry!.lastKnownValidReading!.toStringAsFixed(2)} m'
                  : 'Last Known Valid Reading: ${telemetry!.lastKnownValidReading!.toStringAsFixed(2)} m',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            if (telemetry.lastKnownValidSource != null &&
                telemetry.lastKnownValidSource!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  telemetry.lastKnownValidSource!,
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
              ),
          ] else ...[
            Text(
              widget.isTaglish
                  ? 'Walang nakaraang wastong datos.'
                  : 'No valid previous reading available.',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
          ],
        ],
      );
    }

    // Valid Observation
    final readingStr = '${telemetry.currentReading!.toStringAsFixed(2)} m';
    final status = telemetry.telemetryStatus;
    final timeStr = telemetry.sourceTimePht ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              readingStr,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _statusBgColor(status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _statusTextColor(status),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PAGASA FFWS',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subColor),
            ),
            if (timeStr.isNotEmpty)
              Text(
                'Updated: $timeStr',
                style: TextStyle(fontSize: 11, color: subColor),
              ),
          ],
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

  Color _statusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return Colors.red.withValues(alpha: 0.15);
      case 'ALARM':
      case 'WARNING':
        return Colors.orange.withValues(alpha: 0.15);
      case 'ALERT':
        return Colors.amber.withValues(alpha: 0.2);
      case 'SAFE':
      default:
        return Colors.green.withValues(alpha: 0.15);
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return Colors.red;
      case 'ALARM':
      case 'WARNING':
        return const Color(0xFFD97706);
      case 'ALERT':
        return const Color(0xFFB45309);
      case 'SAFE':
      default:
        return const Color(0xFF15803D);
    }
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
