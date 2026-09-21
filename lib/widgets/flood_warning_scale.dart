import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/station_thresholds.dart';

/// Interactive & accessible Flood Warning Level Scale.
/// Visualizes the 4 warning zones (SAFE, ALERT, ALARM, CRITICAL),
/// exact station cutoff boundaries, and the predicted water level marker.
class FloodWarningScale extends StatelessWidget {
  final double predictedLevel;
  final StationThresholds thresholds;
  final String status;
  final String stationName;
  final bool isDarkMode;
  final bool isTaglish;

  const FloodWarningScale({
    super.key,
    required this.predictedLevel,
    required this.thresholds,
    required this.status,
    required this.stationName,
    required this.isDarkMode,
    required this.isTaglish,
  });

  static const Color colorSafe = Color(0xFF16A34A);
  static const Color colorAlert = Color(0xFFD97706);
  static const Color colorAlarm = Color(0xFFEA580C);
  static const Color colorCritical = Color(0xFFDC2626);

  /// Computes horizontal progress fraction [0.0, 1.0] across the 4 contiguous zones.
  /// Zone 0 (SAFE): 0.00 .. 0.25
  /// Zone 1 (ALERT): 0.25 .. 0.50
  /// Zone 2 (ALARM): 0.50 .. 0.75
  /// Zone 3 (CRITICAL): 0.75 .. 1.00
  double get _fraction {
    final alert = thresholds.alert;
    final alarm = thresholds.alarm;
    final critical = thresholds.critical;

    if (predictedLevel < alert) {
      // Safe zone: scale from (alert - 2.0m) up to alert
      final base = math.max(0.0, alert - 2.0);
      final span = math.max(0.5, alert - base);
      final ratio = ((predictedLevel - base) / span).clamp(0.0, 1.0);
      // Place marker between 6% and 22% of bar
      return 0.06 + (ratio * 0.16);
    } else if (predictedLevel < alarm) {
      final span = math.max(0.1, alarm - alert);
      final ratio = ((predictedLevel - alert) / span).clamp(0.0, 1.0);
      return 0.25 + (ratio * 0.25);
    } else if (predictedLevel < critical) {
      final span = math.max(0.1, critical - alarm);
      final ratio = ((predictedLevel - alarm) / span).clamp(0.0, 1.0);
      return 0.50 + (ratio * 0.25);
    } else {
      // Critical zone: extends visually beyond critical cutoff up to 92%
      final excess = predictedLevel - critical;
      final maxExcess = math.max(1.5, critical * 0.15);
      final ratio = (excess / maxExcess).clamp(0.0, 1.0);
      return 0.75 + (ratio * 0.17); // 0.75 .. 0.92
    }
  }

  Color get _statusColor {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return colorCritical;
      case 'ALARM':
      case 'WARNING':
        return colorAlarm;
      case 'ALERT':
        return colorAlert;
      default:
        return colorSafe;
    }
  }

  String get _simpleExplanation {
    final cleanStatus = status.toUpperCase();
    final lvlStr = '${predictedLevel.toStringAsFixed(2)} m';
    final alertStr = '${thresholds.alert.toStringAsFixed(2)} m';
    final alarmStr = '${thresholds.alarm.toStringAsFixed(2)} m';
    final critStr = '${thresholds.critical.toStringAsFixed(2)} m';

    if (isTaglish) {
      switch (cleanStatus) {
        case 'CRITICAL':
          return 'Ang hula sa lebel ng tubig ay mas mataas sa Critical warning level ng $stationName na $critStr. Ito ang dahilan kung bakit CRITICAL ang panganib sa baha.';
        case 'ALARM':
        case 'WARNING':
          return 'Ang hula sa lebel ng tubig ($lvlStr) ay nasa Alarm warning level ng $stationName ($alarmStr hanggang $critStr). Ito ang dahilan kung bakit ALARM ang panganib sa baha.';
        case 'ALERT':
          return 'Ang hula sa lebel ng tubig ($lvlStr) ay nasa Alert warning level ng $stationName ($alertStr hanggang $alarmStr). Ito ang dahilan kung bakit ALERT ang panganib sa baha.';
        default:
          return 'Ang hula sa lebel ng tubig ($lvlStr) ay mas mababa sa Alert warning level ng $stationName na $alertStr. Ito ang dahilan kung bakit SAFE ang panganib sa baha.';
      }
    } else {
      switch (cleanStatus) {
        case 'CRITICAL':
          return 'The predicted water level is above $stationName\'s Critical warning level of $critStr. This is why the flood risk is CRITICAL.';
        case 'ALARM':
        case 'WARNING':
          return 'The predicted water level ($lvlStr) is within $stationName\'s Alarm warning level ($alarmStr to $critStr). This is why the flood risk is ALARM.';
        case 'ALERT':
          return 'The predicted water level ($lvlStr) is within $stationName\'s Alert warning level ($alertStr to $alarmStr). This is why the flood risk is ALERT.';
        default:
          return 'The predicted water level ($lvlStr) is below $stationName\'s Alert warning level of $alertStr. This is why the flood risk is SAFE.';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final trackBorderColor =
        isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Clamp marker offset so the 130px badge never extends beyond layout bounds
        final markerOffset = (totalWidth * _fraction).clamp(65.0, math.max(65.0, totalWidth - 65.0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Summary Line: Predicted Water Level & Monitoring Station ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          color: subColor,
                        ),
                        children: [
                          TextSpan(
                            text: isTaglish ? 'Tinatayang Lebel: ' : 'Predicted Level: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: subColor,
                            ),
                          ),
                          TextSpan(
                            text: '${predictedLevel.toStringAsFixed(2)} m',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _statusColor,
                              fontSize: 13.5,
                            ),
                          ),
                          TextSpan(
                            text: '  •  ',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white38 : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: isTaglish ? 'Istasyon: ' : 'Station: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: subColor,
                            ),
                          ),
                          TextSpan(
                            text: stationName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 2. Zone Headers (12.5px bold, high contrast) ──
            Row(
              children: [
                _buildZoneLabel('SAFE', colorSafe, 0),
                _buildZoneLabel('ALERT', colorAlert, 1),
                _buildZoneLabel('ALARM', colorAlarm, 2),
                _buildZoneLabel('CRITICAL', colorCritical, 3),
              ],
            ),
            const SizedBox(height: 6),

            // ── 3. Segmented Bar with Crisp 2px Dividers ──
            Container(
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: trackBorderColor, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Expanded(child: Container(color: colorSafe)),
                    Container(width: 2, color: isDarkMode ? const Color(0xFF0F172A) : Colors.white),
                    Expanded(child: Container(color: colorAlert)),
                    Container(width: 2, color: isDarkMode ? const Color(0xFF0F172A) : Colors.white),
                    Expanded(child: Container(color: colorAlarm)),
                    Container(width: 2, color: isDarkMode ? const Color(0xFF0F172A) : Colors.white),
                    Expanded(child: Container(color: colorCritical)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),

            // ── 4. Threshold Boundary Cutoffs under Dividers (12px bold) ──
            SizedBox(
              height: 18,
              child: Stack(
                children: [
                  Positioned(
                    left: (totalWidth * 0.25) - 28,
                    width: 56,
                    child: _buildBoundaryTick('${thresholds.alert.toStringAsFixed(2)} m', colorAlert),
                  ),
                  Positioned(
                    left: (totalWidth * 0.50) - 28,
                    width: 56,
                    child: _buildBoundaryTick('${thresholds.alarm.toStringAsFixed(2)} m', colorAlarm),
                  ),
                  Positioned(
                    left: (totalWidth * 0.75) - 28,
                    width: 56,
                    child: _buildBoundaryTick('${thresholds.critical.toStringAsFixed(2)} m', colorCritical),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── 5. Dynamic Predicted Water Level Marker & Badge ──
            SizedBox(
              height: 68,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: markerOffset - 65.0,
                    child: SizedBox(
                      width: 130,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_drop_up_rounded,
                            size: 26,
                            color: _statusColor,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _statusColor.withValues(alpha: 0.5), width: 1.5),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${predictedLevel.toStringAsFixed(2)} m',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: _statusColor,
                                  ),
                                ),
                                Text(
                                  isTaglish
                                      ? 'Pagtatayang Lebel'
                                      : 'Predicted Water Level',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 6. High-Contrast Direct English Explanation Card ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Text(
                _simpleExplanation,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: textColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildZoneLabel(String label, Color color, int zoneIndex) {
    final cleanStatus = status.toUpperCase();
    final isActive = (zoneIndex == 0 && (cleanStatus == 'SAFE' || cleanStatus == 'NORMAL')) ||
        (zoneIndex == 1 && cleanStatus == 'ALERT') ||
        (zoneIndex == 2 && (cleanStatus == 'ALARM' || cleanStatus == 'WARNING')) ||
        (zoneIndex == 3 && cleanStatus == 'CRITICAL');

    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w800,
          color: isActive ? color : color.withValues(alpha: 0.75),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildBoundaryTick(String value, Color color) {
    return Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }
}
