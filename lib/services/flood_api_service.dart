import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/station_thresholds.dart';

/// 🌊 Flood Data Model - One barangay's current flood monitoring information,
/// sourced from PAGASA-reported station telemetry (/api/status.telemetry_sensors).
class FloodData {
  final String barangay;
  /// Internal status ordinal for UI gates (NOT a flood probability %).
  /// Mapped from river-station status: SAFE≈15, ALERT≈60, WARNING≈75, CRITICAL≈90, UNAVAILABLE≈0.
  final int riskLevel;
  /// PAGASA-reported rainfall for the upstream gauge feeding this station's model, in mm
  /// accumulated over the preceding hour. Null when the source did not report a number.
  final double? rainfall;
  /// Current PAGASA-reported water level in metres (null if unavailable).
  final double? waterLevel;
  /// Retained for display compatibility (mirrors the PAGASA-reported waterLevel).
  final double? peakPredictedLevel;
  final double
      maxWaterLevel; // Critical Level (Dike Height), usually static 20.0m
  final String status; // safe/alert/warning/critical/unavailable
  final DateTime timestamp; // when data was processed

  /// Alias for [waterLevel] (current PAGASA-reported level, null if unavailable).
  double? get currentWaterLevel => waterLevel;

  FloodData({
    required this.barangay,
    required this.riskLevel,
    required this.rainfall,
    this.waterLevel,
    this.peakPredictedLevel,
    required this.maxWaterLevel,
    required this.status,
    required this.timestamp,
  });

  factory FloodData.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse numbers (handles String "12.5" and num 12.5)
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase() == 'nodata') return null;
        return double.tryParse(trimmed.replaceAll(RegExp(r'[^\d.-]'), ''));
      }
      return null;
    }

    final rawWl = json['river_level'] ?? json['water_level'];
    final wl = (rawWl != null) ? parseDouble(rawWl) : null;
    final rawPeak = json['peak_predicted_level'] ?? json['peak_level'];
    final peak = (rawPeak != null) ? parseDouble(rawPeak) : wl;
    return FloodData(
      barangay: json['name'] ?? json['barangay'] ?? 'Unknown',
      riskLevel:
          (parseDouble(json['flood_probability'] ?? json['risk_level']) ?? 0)
              .toInt(),
      rainfall: parseDouble(json['local_rain'] ?? json['rainfall']),
      waterLevel: wl,
      peakPredictedLevel: peak,
      maxWaterLevel: parseDouble(json['max_water_level']) ?? 10.0,
      status: (json['status'] ?? (wl == null ? 'unavailable' : 'safe')).toString().toLowerCase(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'FloodData($barangay: statusOrdinal=$riskLevel, WL=$waterLevel, peak=$peakPredictedLevel)';
}

/// 🔗 Flood API Service - Talks to the FloodGuard analytics engine.
///
/// Data flow: PAGASA-reported telemetry → server-side OLS → this service → Flutter UI
///
/// 📡 Data Flow:
///    PAGASA FFWS → Node.js OLS engine → This Service → Flutter UI
///
/// 🔧 Configuration:
///    - For Emulator: Use 'http://10.0.2.2:5000/api'
///    - For Physical Device: Use your PC's IP (e.g., 'http://192.168.1.57:5000/api')
class FloodApiService {
  // 🌐 Predictive analytics + Mongo (same Render service the admin uses)
  static const String baseUrl = ApiConfig.apiBase;

  // 🗄️ Users / reports — must match admin Reports feed
  static const String dbBaseUrl = ApiConfig.apiBase;

  // Timeout duration for API calls (don't wait forever)
  static const Duration _timeout =
      Duration(seconds: 60); // 🚀 Increased to 60s for Render cold-starts

  // 💾 CACHE: Store data here so we don't fetch different random numbers
  static Map<String, FloodData>? _cachedData;
  static DateTime? _lastFetchTime;

  // 💾 Full raw API response cache for prediction timeline & insights
  static Map<String, dynamic>? _cachedFullResponse;

  /// Returns the cached full API /status response.
  /// Contains prediction.rivers, telemetry_sensors, pagasa_telemetry, thresholds, etc.
  static Map<String, dynamic>? getFullPredictionData() => _cachedFullResponse;

  static bool get isSimulationActive =>
      _cachedFullResponse?['isSimulation'] == true ||
      _cachedDailyForecastResponse?['isSimulation'] == true;

  static double? _finiteNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    if (value is String) {
      final d = double.tryParse(value.trim());
      if (d != null && d.isFinite) return d;
    }
    return null;
  }

  /// Display-only map color from a simulated forecast. Returns null when the
  /// simulated result is missing/unavailable so the map stays gray.
  /// Never substitutes 0.0 for a missing prediction.
  static ColorStatus? mapColorStatusFromSimulatedStation({
    required bool simulationActive,
    double? predictedWaterLevel,
    String? statusBand,
    String? calculationMode,
  }) {
    if (!simulationActive) return null;
    if (predictedWaterLevel == null || !predictedWaterLevel.isFinite) {
      return null;
    }
    final mode = (calculationMode ?? '').toLowerCase();
    if (mode == 'unavailable') return null;
    switch ((statusBand ?? '').trim().toUpperCase()) {
      case 'CRITICAL':
        return ColorStatus.critical;
      case 'ALARM':
      case 'WARNING':
        return ColorStatus.warning;
      case 'ALERT':
        return ColorStatus.alert;
      case 'SAFE':
      case 'NORMAL':
        return ColorStatus.safe;
      default:
        return null;
    }
  }

  /// Simulated forecast status for map polygons/chips. Telemetry FloodData is
  /// left unchanged. Uses the existing barangayToSensor mapping only.
  static ColorStatus? simulatedMapStatusForBarangay(String barangayName) {
    if (!isSimulationActive) return null;
    final sensorKey = barangayToSensor[barangayName] ?? 'sto_nino';
    final daily = getDailyForecastForSensor(sensorKey);
    final fromDaily = mapColorStatusFromSimulatedStation(
      simulationActive: true,
      predictedWaterLevel: daily?.predictedWaterLevel,
      statusBand: daily?.statusBand,
      calculationMode: daily?.calculationMode,
    );
    if (fromDaily != null) return fromDaily;

    final full = _cachedFullResponse;
    if (full == null || full['isSimulation'] != true) return null;
    dynamic stationRaw = (full['stations'] as Map?)?[sensorKey];
    if (stationRaw == null) {
      final prediction = full['prediction'];
      if (prediction is Map) {
        final rivers = prediction['rivers'];
        if (rivers is Map) {
          stationRaw = rivers[sensorKey];
        }
      }
    }
    if (stationRaw is! Map) return null;
    return mapColorStatusFromSimulatedStation(
      simulationActive: true,
      predictedWaterLevel: _finiteNumber(
        stationRaw['predictedWaterLevel'] ?? stationRaw['predicted_water_level'],
      ),
      statusBand: (stationRaw['statusBand'] ?? stationRaw['status'])?.toString(),
      calculationMode: stationRaw['calculationMode']?.toString(),
    );
  }

  /// t-1 water-level input from a simulation inputs map. Missing stays null.
  static double? t1FromSimulationInputs(String sensorKey, Map? inputs) {
    if (inputs == null) return null;
    switch (sensorKey) {
      case 'sto_nino':
        return _finiteNumber(inputs['sto_t_1'] ?? inputs['Sto_t_1']);
      case 'nangka':
        return _finiteNumber(inputs['nangka_wl_t_1'] ?? inputs['Nangka_WL_t_1']);
      case 'tumana':
        return _finiteNumber(inputs['tumana_wl_t_1'] ?? inputs['Tumana_WL_t_1']);
      default:
        return null;
    }
  }

  /// Display-only current reading for demo/video. Never mutates telemetry cache.
  static double? presentationCurrentReading({
    required bool simulationActive,
    required bool realTelemetryUnavailable,
    double? t1,
  }) {
    if (!simulationActive || !realTelemetryUnavailable) return null;
    if (t1 == null || !t1.isFinite) return null;
    return t1;
  }

  static Map? _cachedSimulationInputs() {
    final sim = _cachedFullResponse?['simulation'];
    if (sim is Map && sim['inputsUsed'] is Map) {
      return sim['inputsUsed'] as Map;
    }
    return null;
  }

  static double? presentationCurrentReadingForBarangay(String barangayName) {
    if (!isSimulationActive) return null;
    final sensorKey = barangayToSensor[barangayName] ?? 'sto_nino';
    final telemetry = getPagasaTelemetryForSensor(sensorKey);
    final realUnavailable =
        telemetry == null || telemetry.isUnavailable || telemetry.currentReading == null;
    var t1 = t1FromSimulationInputs(sensorKey, _cachedSimulationInputs());
    if (t1 == null) {
      final stations = _cachedDailyForecastResponse?['stations'];
      if (stations is Map) {
        final st = stations[sensorKey];
        if (st is Map && st['inputsUsed'] is Map) {
          t1 = t1FromSimulationInputs(sensorKey, st['inputsUsed'] as Map);
        }
      }
    }
    return presentationCurrentReading(
      simulationActive: true,
      realTelemetryUnavailable: realUnavailable,
      t1: t1,
    );
  }

  // 💾 Daily Forecast cache from /api/forecasts/daily
  static Map<String, dynamic>? _cachedDailyForecastResponse;
  static DateTime? _lastDailyForecastFetchTime;

  /// Returns the cached full /api/forecasts/daily response
  static Map<String, dynamic>? getFullDailyForecastData() =>
      _cachedDailyForecastResponse;

  /// Maps each barangay to its nearest river sensor key.
  /// The API provides 3 sensors: nangka, sto_nino, tumana.
  static const Map<String, String> barangayToSensor = {
    'Tumana': 'tumana',
    'Malanday': 'tumana',
    'Marikina Heights': 'tumana',
    'Concepcion Dos': 'tumana',
    'Industrial Valley': 'sto_nino', // Southern Marikina — Sto. Niño, not Tumana
    'Santo Niño': 'sto_nino',
    'Concepcion Uno': 'tumana',
    'San Roque': 'sto_nino',
    'Barangka': 'sto_nino',
    'Jesus Dela Peña': 'sto_nino',
    'Santa Elena': 'sto_nino',
    'Tañong': 'sto_nino',
    'Calumpang': 'sto_nino', // Southern Marikina — nearer Sto. Niño, not Nangka
    'Nangka': 'nangka',
    'Fortune': 'nangka',
    'Parang': 'nangka',
  };

  /// Human-readable sensor names
  static const Map<String, String> sensorDisplayNames = {
    'nangka': 'Nangka River',
    'sto_nino': 'Sto. Niño River',
    'tumana': 'Tumana River',
  };

  /// Upstream PAGASA rain gauge that feeds each station's certified OLS model.
  /// Sto. Niño (Candidate 13) has no rainfall predictor, so it has no gauge here.
  static const Map<String, String> _sensorToRainGauge = {
    'nangka': 'boso_boso',
    'tumana': 'science_garden',
  };

  /// Helper to normalize names for robust comparison (matches web logic)
  /// e.g. "Concepcion Uno" -> "concepcionuno"
  /// e.g. "Concepcion_Uno" -> "concepcionuno"
  static String normalizeName(String name) {
    String s = name.trim().toLowerCase();
    // Normalize ñ to n so it doesn't get stripped by the regex below
    s = s.replaceAll('ñ', 'n');
    // Handle "Sto." or "Sto " -> "santo" for robust matching
    s = s.replaceAll(RegExp(r'\bsto\.?\b'), 'santo');
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Helper to find data in a map using normqalized names
  static FloodData? findDataForBarangay(
      Map<String, FloodData> map, String name) {
    if (map.containsKey(name)) return map[name];
    final target = normalizeName(name);
    for (var key in map.keys) {
      if (normalizeName(key) == target) return map[key];
    }
    return null;
  }

  /// 🏥 Check if the API server is healthy and reachable
  ///
  /// Endpoint: GET /api/status
  /// Returns: { "status": "ok", ... }
  ///
  /// Use this before making other requests to verify the FloodGuard
  /// Predictive Forecasting Engine is reachable.
  ///
  /// Returns: true if the API is healthy, false otherwise
  static Future<bool> checkApiHealth() async {
    try {
      debugPrint('🔗 Checking API health at $baseUrl/status');

      final response =
          await http.get(Uri.parse('$baseUrl/status')).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isHealthy = data['status'] == 'ok' ||
            data.containsKey('barangay_data') ||
            data.containsKey('prediction');

        if (isHealthy) {
          debugPrint('✅ API is healthy');
        } else {
          debugPrint('⚠️ API returned unhealthy status');
        }

        return isHealthy;
      }

      debugPrint('⚠️ API health check failed: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ API Health Check Failed: $e');
      debugPrint('💡 TIP: Check if server is running on host="0.0.0.0"');
      debugPrint(
          '💡 TIP: If using Physical Device, ensure _baseUrl uses your PC IP');
      return false;
    }
  }

  /// 📊 Fetch flood data for ALL barangays at once
  ///
  /// Endpoint: GET /api/flood-data
  ///
  /// This is what the API returns:
  /// [
  ///   {
  ///     "barangay": "Nangka",
  ///     "risk_level": 15,           ← status ordinal from telemetry (not a probability)
  ///     "rainfall": 61.0,           ← PAGASA hourly increment in mm (null if missing)
  ///     "water_level": 0.6,         ← From PAGASA in meters
  ///     "max_water_level": 19.9,    ← Reference level
  ///     "status": "warning",        ← Auto-calculated: safe/warning/danger
  ///     "timestamp": "2026-01-18T10:30:00"  ← When data was processed
  ///   },
  ///   { more barangays... }
  /// ]
  ///
  /// Returns: `Map<String, FloodData>`
  /// Used by: HomeMapScreen to populate entire map with real data
  static Future<Map<String, FloodData>> getAllBarangayFloodData(
      {bool forceRefresh = false}) async {
    try {
      // 1. Check if we have valid cached data (less than 2 minutes old)
      if (!forceRefresh && _cachedData != null && _lastFetchTime != null) {
        final age = DateTime.now().difference(_lastFetchTime!);
        if (age.inMinutes < 10) {
          debugPrint(
              '⚡ [Service] Using cached flood data (Age: ${age.inSeconds}s)');
          return _cachedData!;
        }
      }

      debugPrint('🔗 Fetching flood data for all barangays...');

      // Use /status because the new API structure provides river data here
      final response =
          await http.get(Uri.parse('$baseUrl/status')).timeout(_timeout);

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final Map<String, FloodData> map = {};

        if (decoded is Map<String, dynamic>) {
          final telemetrySensors =
              decoded['telemetry_sensors'] as Map<String, dynamic>?;
          final pagasaTelemetry =
              decoded['pagasa_telemetry'] as Map<String, dynamic>?;
          final rivers =
              decoded['prediction']?['rivers'] as Map<String, dynamic>?;

          // PAGASA-reported upstream rainfall. `rf1hr` is the hourly INCREMENT for the gauge
          // that feeds the station's model; it is never a cumulative day-to-date total.
          final upstreamRain =
              decoded['upstream_rainfall'] as Map<String, dynamic>? ?? {};
          double? gaugeRainForSensor(String sensorKey) {
            final gauge = _sensorToRainGauge[sensorKey];
            if (gauge == null) return null;
            final v = upstreamRain[gauge];
            return v is num ? v.toDouble() : null;
          }

          final List<String> allBarangays = [
            "Barangka",
            "Calumpang",
            "Concepcion Dos",
            "Concepcion Uno",
            "Fortune",
            "Industrial Valley",
            "Jesus Dela Peña",
            "Malanday",
            "Marikina Heights",
            "Nangka",
            "Parang",
            "San Roque",
            "Santa Elena",
            "Santo Niño",
            "Tañong",
            "Tumana"
          ];

          for (var b in allBarangays) {
            final sensorKey = barangayToSensor[b] ?? 'sto_nino';
            final telemetry =
                pagasaTelemetry?[sensorKey] as Map<String, dynamic>?;
            final liveVal = telemetrySensors?[sensorKey];
            final double? liveWaterLevel =
                (liveVal is num) ? liveVal.toDouble() : null;

            final riverData = rivers?[sensorKey] as Map<String, dynamic>?;
            final thr = StationThresholds.fromApiOrDefault(sensorKey, riverData);
            final double maxWaterLevel = thr.critical;

            final sensorStatus = telemetry?['sensorStatus']?.toString().toUpperCase() ??
                (liveWaterLevel == null ? 'SUSPECT' : 'VALID');

            // Status is computed strictly from a valid PAGASA reading vs station thresholds
            String status = 'unavailable';
            int riskLevel = 0;

            final isValidReading = liveWaterLevel != null &&
                sensorStatus != 'SUSPECT' &&
                sensorStatus != 'STALE' &&
                sensorStatus != 'MISSING' &&
                sensorStatus != 'UNAVAILABLE';

            if (isValidReading) {
              if (liveWaterLevel >= thr.critical) {
                status = 'critical';
                riskLevel = 90;
              } else if (liveWaterLevel >= thr.alarm) {
                status = 'warning';
                riskLevel = 75;
              } else if (liveWaterLevel >= thr.alert) {
                status = 'alert';
                riskLevel = 60;
              } else {
                status = 'safe';
                riskLevel = 15;
              }
            }

            map[b] = FloodData(
              barangay: b,
              riskLevel: riskLevel,
              rainfall: gaugeRainForSensor(sensorKey),
              waterLevel: isValidReading ? liveWaterLevel : null,
              peakPredictedLevel: isValidReading ? liveWaterLevel : null,
              maxWaterLevel: maxWaterLevel,
              status: status,
              timestamp: DateTime.now(),
            );
          }
        }

        debugPrint('✅ Successfully mapped data for ${map.length} barangays');

        // 2. Save to cache
        _cachedData = map;
        _lastFetchTime = DateTime.now();

        // 3. Cache the full raw response for timeline/insights access
        if (decoded is Map<String, dynamic>) {
          _cachedFullResponse = decoded;
        }

        return map;
      } else if (response.statusCode == 404) {
        debugPrint(
            '⚠️ 404 Not Found: Server is running but endpoint is missing.');
        debugPrint(
            '   👉 Your main.py seems to be missing the expected endpoint.');
        return {};
      } else {
        debugPrint('⚠️ Failed to load flood data: HTTP ${response.statusCode}');
        debugPrint('   Response body: ${response.body}');
        return {};
      }
    } catch (e) {
      debugPrint('❌ Error fetching all flood data: $e');
      debugPrint('💡 TIP: Check if server is running on 0.0.0.0 and port 5000');
      return {};
    }
  }

  /// 📍 Fetch flood data for ONE specific barangay
  ///
  /// Endpoint: GET /api/flood-data?barangay=Nangka
  /// Parameter: barangayName - name of barangay to query
  ///
  /// Returns: Single FloodData object for that barangay
  /// Used by: BarangayDetailsSheet when user taps a barangay on map
  static Future<FloodData?> getBarangayFloodData(String barangayName,
      {bool forceRefresh = false}) async {
    try {
      debugPrint('🔗 Fetching flood data for: $barangayName');

      // OPTIMIZATION: Check cache directly first to ensure consistency with Map
      if (!forceRefresh && _cachedData != null) {
        final cachedItem = findDataForBarangay(_cachedData!, barangayName);
        if (cachedItem != null) {
          final age = DateTime.now().difference(_lastFetchTime!);
          if (age.inMinutes < 10) {
            debugPrint(
                '⚡ [Service] Returning cached data for $barangayName: Rain=${cachedItem.rainfall}mm');
            return cachedItem;
          }
        }
      }

      // Since main.py doesn't support filtering, we fetch all and filter here
      final allData = await getAllBarangayFloodData(forceRefresh: forceRefresh);
      return findDataForBarangay(allData, barangayName);
    } catch (e) {
      debugPrint('❌ Error fetching barangay data: $e');
      return null;
    }
  }

  /// 💾 Save a new user's profile to the backend (MongoDB)
  ///
  /// Endpoint: POST /api/user/register
  /// Called after registration to sync user data with the backend.
  static Future<bool> saveUserProfile({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required String houseNo,
    required String streetName,
    required String barangay,
    required String city,
    required String province,
    required String zipCode,
    required String country,
  }) async {
    try {
      debugPrint('🔗 Saving user profile to database...');
      final payload = jsonEncode({
        'uid': uid,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'house_no': houseNo,
        'street_name': streetName,
        'barangay': barangay,
        'city': city,
        'province': province,
        'zip_code': zipCode,
        'country': country,
        'firstName': firstName,
        'lastName': lastName,
        'houseNo': houseNo,
        'streetName': streetName,
        'zipCode': zipCode,
      });

      // Try PUT /user/profile first
      var response = await http
          .put(
            Uri.parse('$dbBaseUrl/user/profile'),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ User profile saved to MongoDB successfully.');
        return true;
      }

      // Fallback 1: POST /user/profile
      response = await http
          .post(
            Uri.parse('$dbBaseUrl/user/profile'),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ User profile saved to MongoDB successfully.');
        return true;
      }

      // Fallback 2: POST /user/register (legacy deployed endpoint)
      response = await http
          .post(
            Uri.parse('$dbBaseUrl/user/register'),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 400) {
        debugPrint('✅ User profile saved (registered/synced locally & remote).');
        return true;
      }

      debugPrint(
          '⚠️ User profile save failed (HTTP ${response.statusCode}).');
      return true; // Return true so user changes in local profile are never lost
    } catch (e) {
      debugPrint('⚠️ Network error saving profile to remote: $e (using local profile cache)');
      return true; // Return true so user updates locally regardless of remote network status
    }
  }

  /// 📢 Submit a user-generated flood report to the backend
  ///
  /// Endpoint: POST /api/reports
  /// Body: { "location": "...", "isRaining": true, "isSafe": false, "uid": "..." }
  static Future<bool> submitFloodReport({
    required String location,
    required bool isRaining,
    required bool isSafe,
    required String uid,
    double? floodDepth,
    String? floodLevel,
    String? reporterName,
    String? reporterPhone,
    double? latitude,
    double? longitude,
    String? status,
    String? helpNeeded,
  }) async {
    try {
      debugPrint('🔗 Submitting flood report to database...');
      debugPrint('   📝 Reporter: $reporterName, Phone: $reporterPhone');
      debugPrint('   📝 Flood Level: $floodLevel, Depth: ${floodDepth}m');
      debugPrint('   📝 Help needed: $helpNeeded');
      final response = await http
          .post(
            Uri.parse('$dbBaseUrl/reports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'location': location,
              'is_raining': isRaining,
              'is_safe': isSafe,
              'uid': uid,
              'flood_depth': floodDepth,
              'flood_level': floodLevel ?? 'Unknown',
              'reporter_name': reporterName ?? 'Unknown Reporter',
              'reporter_phone': reporterPhone ?? '',
              'help_needed': helpNeeded,
              'floodDepth': floodDepth,
              'floodLevel': floodLevel ?? 'Unknown',
              'reporterName': reporterName ?? 'Unknown Reporter',
              'reporterPhone': reporterPhone ?? '',
              'helpNeeded': helpNeeded,
              'latitude': latitude,
              'longitude': longitude,
              'status': status ?? 'pending',
            }),
          )
          .timeout(_timeout);

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        debugPrint(
            '⚠️ Server returned HTML. Please ensure you have DEPLOYED the new backend code to Render.');
        return false;
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 ||
          (response.statusCode == 200 && data['success'] == true)) {
        debugPrint('✅ Flood report submitted successfully.');
        return true;
      } else {
        debugPrint(
            '⚠️ Flood report submission failed: HTTP ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error submitting flood report: $e');
      return false;
    }
  }

  /// 📅 Fetch authoritative daily forecasts from GET /api/forecasts/daily
  static Future<Map<String, dynamic>?> fetchDailyForecasts(
      {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh &&
          _cachedDailyForecastResponse != null &&
          _lastDailyForecastFetchTime != null) {
        final age = DateTime.now().difference(_lastDailyForecastFetchTime!);
        if (age.inMinutes < 5) {
          return _cachedDailyForecastResponse;
        }
      }

      debugPrint(
          '📅 Fetching authoritative daily forecast from $baseUrl/forecasts/daily');
      final response =
          await http.get(Uri.parse('$baseUrl/forecasts/daily')).timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          _cachedDailyForecastResponse = decoded;
          _lastDailyForecastFetchTime = DateTime.now();
          return decoded;
        }
      }
      return _cachedDailyForecastResponse;
    } catch (e) {
      debugPrint('❌ Failed to fetch daily forecasts: $e');
      return _cachedDailyForecastResponse;
    }
  }

  static DailyForecastItem? getDailyForecastForSensor(String sensorKey) {
    if (_cachedDailyForecastResponse == null) return null;
    final stations =
        _cachedDailyForecastResponse!['stations'] as Map<String, dynamic>?;
    final data = stations?[sensorKey] as Map<String, dynamic>?;
    if (data == null) return null;
    return DailyForecastItem.fromJson(data);
  }

  static DailyForecastItem? getDailyForecastForBarangay(String barangay) {
    final sensorKey = barangayToSensor[barangay] ?? 'sto_nino';
    return getDailyForecastForSensor(sensorKey);
  }

  static PagasaTelemetryItem? getPagasaTelemetryForSensor(String sensorKey) {
    if (_cachedFullResponse == null) return null;
    final telemetryMap =
        _cachedFullResponse!['pagasa_telemetry'] as Map<String, dynamic>?;
    final data = telemetryMap?[sensorKey] as Map<String, dynamic>?;
    if (data != null) {
      return PagasaTelemetryItem.fromJson(data);
    }

    // Fallback: build from prediction.rivers and telemetry_sensors
    final telemetrySensors =
        _cachedFullResponse!['telemetry_sensors'] as Map<String, dynamic>?;
    final lkvMap =
        _cachedFullResponse!['last_known_valid'] as Map<String, dynamic>?;
    final rivers =
        _cachedFullResponse!['prediction']?['rivers'] as Map<String, dynamic>?;
    final riverData = rivers?[sensorKey] as Map<String, dynamic>?;

    final rawVal = telemetrySensors?[sensorKey];
    final double? reading = (rawVal is num) ? rawVal.toDouble() : null;
    final lkvObj = lkvMap?[sensorKey];
    double? lkvVal;
    String? lkvSrc;
    if (lkvObj is Map) {
      lkvVal = (lkvObj['value'] is num)
          ? (lkvObj['value'] as num).toDouble()
          : null;
      lkvSrc = lkvObj['sourceTimePht']?.toString();
    } else if (lkvObj is num) {
      lkvVal = lkvObj.toDouble();
    }

    return PagasaTelemetryItem(
      stationId: sensorKey,
      stationName: sensorDisplayNames[sensorKey] ?? sensorKey,
      currentReading: reading,
      rawReading: reading?.toString() ?? '',
      sensorStatus: reading == null ? 'SUSPECT' : 'VALID',
      telemetryStatus: riverData?['status']?.toString().toUpperCase() ??
          (reading == null ? 'UNAVAILABLE' : 'SAFE'),
      sourceTimePht: riverData?['sourceTimePht']?.toString(),
      lastKnownValidReading: lkvVal,
      lastKnownValidSource: lkvSrc,
    );
  }

  static PagasaTelemetryItem? getPagasaTelemetryForBarangay(String barangay) {
    final sensorKey = barangayToSensor[barangay] ?? 'sto_nino';
    return getPagasaTelemetryForSensor(sensorKey);
  }
}

/// 💧 Latest PAGASA-reported station reading from GET /api/status.pagasa_telemetry
class PagasaTelemetryItem {
  final String stationId;
  final String stationName;
  final double? currentReading;
  final String rawReading;
  final String sensorStatus; // VALID, SUSPECT, STALE, MISSING, UNAVAILABLE
  final String telemetryStatus; // SAFE, ALERT, ALARM, CRITICAL, UNAVAILABLE
  final String? sourceTimePht;
  final double? lastKnownValidReading;
  final String? lastKnownValidSource;

  PagasaTelemetryItem({
    required this.stationId,
    required this.stationName,
    this.currentReading,
    required this.rawReading,
    required this.sensorStatus,
    required this.telemetryStatus,
    this.sourceTimePht,
    this.lastKnownValidReading,
    this.lastKnownValidSource,
  });

  factory PagasaTelemetryItem.fromJson(Map<String, dynamic> json) {
    double? parseVal(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) {
        if (v.contains('(') || v.contains('*')) return null;
        return double.tryParse(v);
      }
      return null;
    }

    final lkv = json['lastKnownValid'];
    double? lkvReading;
    String? lkvSource;
    if (lkv is Map) {
      lkvReading = parseVal(lkv['value']);
      lkvSource = lkv['sourceTimePht']?.toString();
    } else if (lkv != null) {
      lkvReading = parseVal(lkv);
    }

    final currentVal = parseVal(json['currentReading']);
    final rawStr = json['rawReading']?.toString() ?? (currentVal?.toString() ?? '');
    final sStatus = json['sensorStatus']?.toString().toUpperCase() ??
        (currentVal == null ? 'SUSPECT' : 'VALID');
    final tStatus = json['telemetryStatus']?.toString().toUpperCase() ??
        (currentVal == null ? 'UNAVAILABLE' : 'SAFE');

    return PagasaTelemetryItem(
      stationId: json['stationId']?.toString() ?? '',
      stationName: json['stationName']?.toString() ?? '',
      currentReading: currentVal,
      rawReading: rawStr,
      sensorStatus: sStatus,
      telemetryStatus: tStatus,
      sourceTimePht: json['sourceTimePht']?.toString(),
      lastKnownValidReading: lkvReading,
      lastKnownValidSource: lkvSource,
    );
  }

  bool get isUnavailable =>
      currentReading == null ||
      sensorStatus == 'SUSPECT' ||
      sensorStatus == 'STALE' ||
      sensorStatus == 'MISSING' ||
      sensorStatus == 'UNAVAILABLE' ||
      telemetryStatus == 'UNAVAILABLE';

  String get unavailableReasonDisplay {
    switch (sensorStatus) {
      case 'SUSPECT':
        return 'Suspect Sensor';
      case 'STALE':
        return 'Stale Reading';
      case 'MISSING':
        return 'No Current Reading';
      case 'UNAVAILABLE':
        return 'PAGASA Reading Unavailable';
      case 'NETWORK_ERROR':
      case 'FETCH_FAILED':
        return 'Telemetry Temporarily Unavailable';
      default:
        return 'Telemetry Temporarily Unavailable';
    }
  }
}

/// 📅 Authoritative Daily Forecast Data Model from GET /api/forecasts/daily
class DailyForecastItem {
  final String stationId;
  final String forecastTargetDate;
  final String? sourceDataDate;
  final double? predictedWaterLevel;
  final String calculationMode; // primary_model, persistence_fallback, unavailable
  final String statusBand; // SAFE, ALERT, ALARM, CRITICAL, UNMAPPED_DAILY_OBSERVATION
  final String candidateId;
  final String targetSemantics;
  final bool thresholdMappingAllowed;
  final String? fallbackReason;

  /// Model that actually produced this stored snapshot (never rewritten when the active
  /// production model changes).
  final String? generationModelVersion;

  /// Model that is active in production right now.
  final String? activeModelVersion;

  /// True when the snapshot was produced by a model that has since been superseded.
  final bool isStaleModelSnapshot;

  /// True only when [forecastTargetDate] is literally the calendar day after
  /// [sourceDataDate]. UI copy may say "next calendar day" only while this holds.
  final bool nextCalendarDayVerified;
  final bool isSimulation;

  DailyForecastItem({
    required this.stationId,
    required this.forecastTargetDate,
    this.sourceDataDate,
    this.predictedWaterLevel,
    required this.calculationMode,
    required this.statusBand,
    required this.candidateId,
    required this.targetSemantics,
    required this.thresholdMappingAllowed,
    this.fallbackReason,
    this.generationModelVersion,
    this.activeModelVersion,
    this.isStaleModelSnapshot = false,
    this.nextCalendarDayVerified = false,
    this.isSimulation = false,
  });

  factory DailyForecastItem.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) {
        return double.tryParse(val.replaceAll(RegExp(r'[^\d.]'), ''));
      }
      return null;
    }

    final source = json['sourceDataDate']?.toString();
    final target = json['forecastTargetDate']?.toString() ?? '';
    final activeModel = json['activeModel'];

    return DailyForecastItem(
      stationId: json['stationId']?.toString() ?? '',
      forecastTargetDate: target,
      sourceDataDate: source,
      predictedWaterLevel: parseDouble(json['predictedWaterLevel']),
      calculationMode: json['calculationMode']?.toString() ?? 'unavailable',
      statusBand: json['statusBand']?.toString() ?? 'SAFE',
      candidateId: json['generationCandidateId']?.toString() ??
          json['candidateId']?.toString() ??
          '',
      targetSemantics: json['targetSemantics']?.toString() ?? '',
      thresholdMappingAllowed: json['thresholdMappingAllowed'] == true,
      fallbackReason: json['fallbackReason']?.toString(),
      generationModelVersion: json['generationModelVersion']?.toString() ??
          json['modelVersion']?.toString(),
      activeModelVersion:
          activeModel is Map ? activeModel['modelVersion']?.toString() : null,
      isStaleModelSnapshot: json['isStaleModelSnapshot'] == true,
      // Trust the server flag when present; otherwise verify locally so an older API
      // response can never make the UI claim something the dates do not support.
      nextCalendarDayVerified: json['nextCalendarDayVerified'] == true ||
          _isNextCalendarDay(source, target),
      isSimulation: json['isSimulation'] == true || json['mode'] == 'simulation',
    );
  }

  /// True when [target] is exactly one calendar day after [source] (both YYYY-MM-DD).
  static bool _isNextCalendarDay(String? source, String? target) {
    if (source == null || target == null) return false;
    final s = DateTime.tryParse(source);
    final t = DateTime.tryParse(target);
    if (s == null || t == null) return false;
    final expected = DateTime.utc(s.year, s.month, s.day)
        .add(const Duration(days: 1));
    return expected.year == t.year &&
        expected.month == t.month &&
        expected.day == t.day;
  }

  bool get isUnavailable =>
      calculationMode == 'unavailable' || predictedWaterLevel == null;

  String get modeDisplayLabel {
    return switch (calculationMode) {
      'primary_model' => 'PRIMARY MODEL',
      'persistence_fallback' => 'PERSISTENCE FALLBACK',
      _ => 'FORECAST UNAVAILABLE',
    };
  }
}

