/// Authoritative PAGASA station Alert / Alarm / Critical bands (EL.m).
/// Defaults match backend CACHE thresholds in predictionEngine.js.
/// Prefer API `rivers[sensor].thresholds` when present (fromApiOrDefault).
library;

enum ColorStatus {
  safe,
  alert,
  warning,
  critical;

  String get label {
    switch (this) {
      case ColorStatus.safe:
        return 'SAFE';
      case ColorStatus.alert:
        return 'ALERT';
      case ColorStatus.warning:
        return 'WARNING';
      case ColorStatus.critical:
        return 'CRITICAL';
    }
  }
}

class StationThresholds {
  final double alert;
  final double alarm;
  final double critical;

  const StationThresholds({
    required this.alert,
    required this.alarm,
    required this.critical,
  });

  /// Upper bound for gauge UI (not a prediction).
  double get gaugeMax => critical + 1.5;

  ColorStatus statusFor(double level) {
    if (level >= critical) return ColorStatus.critical;
    if (level >= alarm) return ColorStatus.warning;
    if (level >= alert) return ColorStatus.alert;
    return ColorStatus.safe;
  }

  /// Defaults aligned with FloodGuard backend CACHE.thresholds.
  static StationThresholds forSensor(String sensorKey) {
    switch (sensorKey) {
      case 'nangka':
        return const StationThresholds(
            alert: 16.50, alarm: 17.10, critical: 17.70);
      case 'tumana':
        return const StationThresholds(
            alert: 17.26, alarm: 18.26, critical: 19.26);
      case 'montalban':
        return const StationThresholds(
            alert: 22.40, alarm: 23.00, critical: 23.60);
      case 'rosario':
        return const StationThresholds(
            alert: 13.00, alarm: 14.00, critical: 15.00);
      case 'sto_nino':
      default:
        return const StationThresholds(
            alert: 15.00, alarm: 16.00, critical: 17.00);
    }
  }

  /// Prefer API-provided thresholds from the `/api/status` river object when complete.
  static StationThresholds fromApiOrDefault(
    String sensorKey,
    Map<String, dynamic>? riverData,
  ) {
    final raw = riverData?['thresholds'];
    if (raw is Map) {
      final a = raw['alert'];
      final m = raw['alarm'];
      final c = raw['critical'];
      if (a is num && m is num && c is num) {
        return StationThresholds(
          alert: a.toDouble(),
          alarm: m.toDouble(),
          critical: c.toDouble(),
        );
      }
    }
    return forSensor(sensorKey);
  }
}
