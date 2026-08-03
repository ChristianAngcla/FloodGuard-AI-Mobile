/// Per-station PAGASA water-level thresholds (meters, EL.m).
/// Used by map risk coloring, alarm gauges, and legends.
class StationThresholds {
  final double alert;
  final double alarm;
  final double critical;
  final double gaugeMax;

  const StationThresholds({
    required this.alert,
    required this.alarm,
    required this.critical,
    required this.gaugeMax,
  });

  static const Map<String, StationThresholds> bySensor = {
    'nangka': StationThresholds(
      alert: 16.50,
      alarm: 17.10,
      critical: 17.70,
      gaugeMax: 24.0,
    ),
    'sto_nino': StationThresholds(
      alert: 15.00,
      alarm: 16.00,
      critical: 17.00,
      gaugeMax: 20.0,
    ),
    'tumana': StationThresholds(
      alert: 17.26,
      alarm: 18.26,
      critical: 19.26,
      gaugeMax: 22.0,
    ),
    'montalban': StationThresholds(
      alert: 22.40,
      alarm: 23.00,
      critical: 23.60,
      gaugeMax: 28.0,
    ),
    'rosario': StationThresholds(
      alert: 13.00,
      alarm: 14.00,
      critical: 15.00,
      gaugeMax: 18.0,
    ),
  };

  static StationThresholds forSensor(String sensorKey) =>
      bySensor[sensorKey] ?? bySensor['sto_nino']!;

  /// Prefer live API thresholds when present.
  static StationThresholds fromApiOrDefault(
    String sensorKey,
    Map<String, dynamic>? riverData,
  ) {
    final thr = riverData?['thresholds'];
    if (thr is Map) {
      final alert = (thr['alert'] as num?)?.toDouble();
      final alarm = (thr['alarm'] as num?)?.toDouble();
      final critical = (thr['critical'] as num?)?.toDouble();
      if (alert != null && alarm != null && critical != null) {
        final fallback = forSensor(sensorKey);
        return StationThresholds(
          alert: alert,
          alarm: alarm,
          critical: critical,
          gaugeMax: (critical * 1.25).clamp(fallback.gaugeMax, 40.0),
        );
      }
    }
    return forSensor(sensorKey);
  }

  ColorStatus statusFor(double level) {
    if (level >= critical) return ColorStatus.critical;
    if (level >= alarm) return ColorStatus.warning;
    if (level >= alert) return ColorStatus.alert;
    return ColorStatus.safe;
  }
}

enum ColorStatus { safe, alert, warning, critical }

extension ColorStatusX on ColorStatus {
  String get label {
    switch (this) {
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
}
