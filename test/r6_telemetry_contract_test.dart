import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/services/flood_api_service.dart';

/// R6 correction coverage for the mobile side of the API contract:
///   DEFECT F — a stored forecast keeps the provenance of the model that generated it, and the
///              app can tell when that model has since been superseded.
///   DEFECT G — the app only treats a forecast as "next calendar day" when the two dates really
///              are one calendar day apart.
/// Plus the terminology migration away from `live_*` API fields.
void main() {
  group('DEFECT G — next-calendar-day verification', () {
    test('accepts a genuine consecutive-day pair', () {
      final item = DailyForecastItem.fromJson({
        'stationId': 'sto_nino',
        'sourceDataDate': '2026-08-20',
        'forecastTargetDate': '2026-08-21',
        'predictedWaterLevel': 14.2,
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
      });
      expect(item.nextCalendarDayVerified, isTrue);
    });

    test('rejects a two-day gap', () {
      final item = DailyForecastItem.fromJson({
        'stationId': 'sto_nino',
        'sourceDataDate': '2026-08-19',
        'forecastTargetDate': '2026-08-21',
        'predictedWaterLevel': 14.2,
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
      });
      expect(item.nextCalendarDayVerified, isFalse);
    });

    test('rejects a same-day pair', () {
      final item = DailyForecastItem.fromJson({
        'sourceDataDate': '2026-08-21',
        'forecastTargetDate': '2026-08-21',
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
      });
      expect(item.nextCalendarDayVerified, isFalse);
    });

    test('crosses a month boundary correctly', () {
      final item = DailyForecastItem.fromJson({
        'sourceDataDate': '2026-08-31',
        'forecastTargetDate': '2026-09-01',
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
      });
      expect(item.nextCalendarDayVerified, isTrue);
    });

    test('crosses a leap-year February boundary correctly', () {
      final item = DailyForecastItem.fromJson({
        'sourceDataDate': '2028-02-28',
        'forecastTargetDate': '2028-02-29',
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
      });
      expect(item.nextCalendarDayVerified, isTrue);
    });

    test('is false when sourceDataDate is absent', () {
      final item = DailyForecastItem.fromJson({
        'forecastTargetDate': '2026-08-21',
        'calculationMode': 'unavailable',
        'statusBand': 'UNAVAILABLE',
      });
      expect(item.nextCalendarDayVerified, isFalse);
    });
  });

  group('DEFECT F — model provenance separation', () {
    test('keeps generation version distinct from the active version', () {
      final item = DailyForecastItem.fromJson({
        'stationId': 'sto_nino',
        'sourceDataDate': '2026-08-20',
        'forecastTargetDate': '2026-08-21',
        'predictedWaterLevel': 14.2,
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
        'generationCandidateId': 'Candidate 13',
        'generationModelVersion': '3.0.0-C13-RULE-B',
        'activeModel': {
          'candidateId': 'Candidate 13',
          'modelVersion': '3.0.0-CALIBRATED-AB12CD',
        },
        'isStaleModelSnapshot': true,
      });

      expect(item.generationModelVersion, '3.0.0-C13-RULE-B');
      expect(item.activeModelVersion, '3.0.0-CALIBRATED-AB12CD');
      expect(item.isStaleModelSnapshot, isTrue);
      expect(item.candidateId, 'Candidate 13');
    });

    test('is not marked stale when generation and active versions agree', () {
      final item = DailyForecastItem.fromJson({
        'sourceDataDate': '2026-08-20',
        'forecastTargetDate': '2026-08-21',
        'predictedWaterLevel': 14.2,
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
        'generationModelVersion': '3.0.0-C13-RULE-B',
        'activeModel': {'modelVersion': '3.0.0-C13-RULE-B'},
        'isStaleModelSnapshot': false,
      });
      expect(item.isStaleModelSnapshot, isFalse);
    });
  });

  group('Terminology migration — PAGASA telemetry fields', () {
    test('parses telemetryStatus and sourceTimePht', () {
      final item = PagasaTelemetryItem.fromJson({
        'stationId': 'nangka',
        'stationName': 'Nangka',
        'currentReading': 14.35,
        'rawReading': '14.35',
        'sensorStatus': 'VALID',
        'telemetryStatus': 'SAFE',
        'sourceTimePht': '2026-08-21 20:00 PHT',
        'lastKnownValid': {
          'value': 14.10,
          'sourceTimePht': '2026-08-21 19:00 PHT',
        },
      });

      expect(item.telemetryStatus, 'SAFE');
      expect(item.sourceTimePht, '2026-08-21 20:00 PHT');
      expect(item.lastKnownValidReading, 14.10);
      expect(item.lastKnownValidSource, '2026-08-21 19:00 PHT');
      expect(item.isUnavailable, isFalse);
    });

    test('treats a suspect reading as unavailable and never fabricates SAFE', () {
      final item = PagasaTelemetryItem.fromJson({
        'stationId': 'sto_nino',
        'stationName': 'Sto. Niño',
        'currentReading': null,
        'rawReading': '15.90(*)',
        'sensorStatus': 'SUSPECT',
        'telemetryStatus': 'UNAVAILABLE',
      });

      expect(item.currentReading, isNull);
      expect(item.isUnavailable, isTrue);
      expect(item.telemetryStatus, isNot('SAFE'));
    });

    test('unavailable copy no longer says "Live"', () {
      final item = PagasaTelemetryItem.fromJson({
        'sensorStatus': 'UNAVAILABLE',
        'telemetryStatus': 'UNAVAILABLE',
        'rawReading': '',
      });
      expect(item.unavailableReasonDisplay.toLowerCase(), isNot(contains('live')));
      expect(item.unavailableReasonDisplay, contains('PAGASA'));
    });
  });
}
