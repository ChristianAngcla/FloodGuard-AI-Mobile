import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/services/flood_api_service.dart';

void main() {
  group('R7 missing != 0', () {
    test('FloodData.fromJson keeps missing water level null instead of 0.0', () {
      final data = FloodData.fromJson({
        'barangay': 'Nangka',
        'status': 'unavailable',
      });
      expect(data.waterLevel, isNull);
      expect(data.rainfall, isNull);
    });

    test('FloodData.fromJson preserves explicit numeric zero', () {
      final data = FloodData.fromJson({
        'barangay': 'Nangka',
        'water_level': 0.0,
        'rainfall': 0.0,
        'status': 'safe',
      });
      expect(data.waterLevel, 0.0);
      expect(data.rainfall, 0.0);
    });
  });

  group('R7 simulation marker', () {
    test('DailyForecastItem surfaces SIMULATION / TEST DATA', () {
      final item = DailyForecastItem.fromJson({
        'stationId': 'sto_nino',
        'sourceDataDate': '2026-08-20',
        'forecastTargetDate': '2026-08-21',
        'predictedWaterLevel': 13.85,
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
        'isSimulation': true,
        'mode': 'simulation',
        'candidateId': 'Candidate 13',
        'modelVersion': '3.0.0-C13-RULE-B',
      });
      expect(item.isSimulation, isTrue);
      expect(item.modeDisplayLabel, contains('SIMULATION / TEST DATA'));
    });

    test('operational forecast is not marked simulation', () {
      final item = DailyForecastItem.fromJson({
        'stationId': 'sto_nino',
        'sourceDataDate': '2026-08-20',
        'forecastTargetDate': '2026-08-21',
        'predictedWaterLevel': 13.85,
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
      });
      expect(item.isSimulation, isFalse);
      expect(item.modeDisplayLabel, isNot(contains('SIMULATION')));
    });
  });
}
