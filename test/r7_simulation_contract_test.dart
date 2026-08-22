import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/services/flood_api_service.dart';
import 'package:floodguard_ai/utils/station_thresholds.dart';

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

  group('R7 historical replay marker', () {
    test('DailyForecastItem keeps replay flag without public badge wording', () {
      final item = DailyForecastItem.fromJson({
        'stationId': 'sto_nino',
        'sourceDataDate': '2023-07-24',
        'forecastTargetDate': '2023-07-25',
        'predictedWaterLevel': 13.85,
        'calculationMode': 'primary_model',
        'statusBand': 'SAFE',
        'isSimulation': true,
        'isHistoricalReplay': true,
        'mode': 'historical_replay',
        'candidateId': 'Candidate 13',
        'modelVersion': '3.0.0-C13-RULE-B',
      });
      expect(item.isSimulation, isTrue);
      expect(item.modeDisplayLabel, 'PRIMARY MODEL');
      expect(item.modeDisplayLabel, isNot(contains('SIMULATION')));
      expect(item.modeDisplayLabel, isNot(contains('TEST DATA')));
      expect(item.modeDisplayLabel, isNot(contains('DEMO')));
      expect(item.modeDisplayLabel, isNot(contains('HISTORICAL REPLAY')));
      expect(item.forecastTargetDate, '2023-07-25');
      expect(item.sourceDataDate, '2023-07-24');
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

  group('replay map display coloring', () {
    test('Nangka, Parang, and Fortune share the existing nangka mapping', () {
      expect(FloodApiService.barangayToSensor['Nangka'], 'nangka');
      expect(FloodApiService.barangayToSensor['Parang'], 'nangka');
      expect(FloodApiService.barangayToSensor['Fortune'], 'nangka');
    });

    test('replay overlay OFF does not override map color', () {
      expect(
        FloodApiService.mapColorStatusFromSimulatedStation(
          simulationActive: false,
          predictedWaterLevel: 18.5,
          statusBand: 'CRITICAL',
          calculationMode: 'primary_model',
        ),
        isNull,
      );
    });

    test('valid replayed bands map to existing color statuses', () {
      ColorStatus? color(String band) =>
          FloodApiService.mapColorStatusFromSimulatedStation(
            simulationActive: true,
            predictedWaterLevel: 12.0,
            statusBand: band,
            calculationMode: 'primary_model',
          );
      expect(color('SAFE'), ColorStatus.safe);
      expect(color('NORMAL'), ColorStatus.safe);
      expect(color('ALERT'), ColorStatus.alert);
      expect(color('ALARM'), ColorStatus.warning);
      expect(color('WARNING'), ColorStatus.warning);
      expect(color('CRITICAL'), ColorStatus.critical);
    });

    test('unavailable or missing replayed forecast stays gray', () {
      expect(
        FloodApiService.mapColorStatusFromSimulatedStation(
          simulationActive: true,
          predictedWaterLevel: null,
          statusBand: 'CRITICAL',
          calculationMode: 'primary_model',
        ),
        isNull,
      );
      expect(
        FloodApiService.mapColorStatusFromSimulatedStation(
          simulationActive: true,
          predictedWaterLevel: 18.5,
          statusBand: 'UNAVAILABLE',
          calculationMode: 'unavailable',
        ),
        isNull,
      );
    });

    test('explicit replayed 0.0 remains a valid SAFE reading', () {
      expect(
        FloodApiService.mapColorStatusFromSimulatedStation(
          simulationActive: true,
          predictedWaterLevel: 0.0,
          statusBand: 'SAFE',
          calculationMode: 'primary_model',
        ),
        ColorStatus.safe,
      );
    });
  });

  group('operational forecast map colors', () {
    test('DailyForecast status colors the map without telemetry', () {
      expect(
        FloodApiService.mapColorStatusFromForecastStation(
          predictedWaterLevel: 15.2,
          statusBand: 'ALERT',
          calculationMode: 'primary_model',
        ),
        ColorStatus.alert,
      );
      expect(
        FloodApiService.mapColorStatusFromForecastStation(
          predictedWaterLevel: 16.4,
          statusBand: 'ALARM',
          calculationMode: 'primary_model',
        ),
        ColorStatus.warning,
      );
      expect(
        FloodApiService.mapColorStatusFromForecastStation(
          predictedWaterLevel: null,
          statusBand: 'SAFE',
          calculationMode: 'unavailable',
        ),
        isNull,
      );
    });
  });
}
