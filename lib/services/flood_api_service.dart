import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// 🌊 Flood Data Model - One barangay's current live flood monitoring information,
/// sourced from live sensor telemetry (/api/status.live_sensors).
class FloodData {
  final String barangay;
  /// Internal status ordinal for UI gates (NOT a flood probability %).
  /// Mapped from river-station status: SAFE≈15, ALERT≈60, WARNING≈75, CRITICAL≈90, UNAVAILABLE≈0.
  final int riskLevel;
  final double rainfall; // mm/hour from PAGASA
  /// Current observed live water level in meters from live_sensors (null if unavailable).
  final double? waterLevel;
  /// Retained for display compatibility (mirrors live waterLevel).
  final double? peakPredictedLevel;
  final double
      maxWaterLevel; // Critical Level (Dike Height), usually static 20.0m
  final String status; // safe/alert/warning/critical/unavailable
  final DateTime timestamp; // when data was processed

  /// Alias for [waterLevel] (current live observed level, null if unavailable).
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
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        // Remove non-numeric characters (except dot) and parse
        return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      }
      return 0.0;
    }

    final rawWl = json['river_level'] ?? json['water_level'];
    final wl = (rawWl != null) ? parseDouble(rawWl) : null;
    final rawPeak = json['peak_predicted_level'] ?? json['peak_level'];
    final peak = (rawPeak != null) ? parseDouble(rawPeak) : wl;
    return FloodData(
      barangay: json['name'] ?? json['barangay'] ?? 'Unknown',
      riskLevel:
          parseDouble(json['flood_probability'] ?? json['risk_level']).toInt(),
      rainfall: parseDouble(json['local_rain'] ?? json['rainfall']),
      waterLevel: wl,
      peakPredictedLevel: peak,
      maxWaterLevel: parseDouble(json['max_water_level'] ?? 10.0),
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
/// Data flow: authorized/raw observations → time-series OLS → this service → UI
/// (Not a third-party flood algorithm; OLS coefficients are project-trained.)
///
/// 📡 Data Flow:
///    PAGASA → Python AI → Flask API → This Service → Flutter UI
///
/// 🔧 Configuration:
///    - For Emulator: Use 'http://10.0.2.2:5000/api'
///    - For Physical Device: Use your PC's IP (e.g., 'http://192.168.1.57:5000/api')
class FloodApiService {
  // 🌐 Live predictive analytics + Mongo (same Render service the admin uses)
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
  /// Contains prediction.rivers, live_sensors, thresholds, etc.
  static Map<String, dynamic>? getFullPredictionData() => _cachedFullResponse;

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
  /// Returns: { "status": "ok", "model_loaded": true, ... }
  ///
  /// Use this before making other requests to verify connection
  /// and that your ML model loaded successfully
  ///
  /// Returns: true if API is healthy and model is loaded, false otherwise
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
  ///     "risk_level": 74,           ← From ML model (0-100%)
  ///     "rainfall": 61.0,           ← From PAGASA in mm
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
          final liveSensors = decoded['live_sensors'] as Map<String, dynamic>?;
          final rivers =
              decoded['prediction']?['rivers'] as Map<String, dynamic>?;
          final weather = decoded['weather'] as Map<String, dynamic>? ?? {};
          final rainfall = (weather['precipitation'] ?? 0.0).toDouble();

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
            final liveVal = liveSensors?[sensorKey];
            final double? liveWaterLevel =
                (liveVal is num) ? liveVal.toDouble() : null;

            final riverData = rivers?[sensorKey] as Map<String, dynamic>?;
            final thresholds =
                riverData?['thresholds'] as Map<String, dynamic>? ?? {};
            final double maxWaterLevel =
                (thresholds['critical'] ?? 20.0).toDouble();

            // Live status is computed strictly from liveWaterLevel vs station thresholds
            String status = 'unavailable';
            int riskLevel = 0;

            if (liveWaterLevel != null) {
              final double alertThr =
                  (thresholds['alert'] ?? (sensorKey == 'nangka' ? 16.5 : 15.0))
                      .toDouble();
              final double alarmThr =
                  (thresholds['alarm'] ?? (sensorKey == 'nangka' ? 17.1 : 16.0))
                      .toDouble();
              final double critThr =
                  (thresholds['critical'] ?? (sensorKey == 'nangka' ? 17.7 : 17.0))
                      .toDouble();

              if (liveWaterLevel >= critThr) {
                status = 'critical';
                riskLevel = 90;
              } else if (liveWaterLevel >= alarmThr) {
                status = 'warning';
                riskLevel = 75;
              } else if (liveWaterLevel >= alertThr) {
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
              rainfall: rainfall,
              waterLevel: liveWaterLevel,
              peakPredictedLevel: liveWaterLevel,
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

    return DailyForecastItem(
      stationId: json['stationId']?.toString() ?? '',
      forecastTargetDate: json['forecastTargetDate']?.toString() ?? '',
      sourceDataDate: json['sourceDataDate']?.toString(),
      predictedWaterLevel: parseDouble(json['predictedWaterLevel']),
      calculationMode: json['calculationMode']?.toString() ?? 'unavailable',
      statusBand: json['statusBand']?.toString() ?? 'SAFE',
      candidateId: json['candidateId']?.toString() ?? '',
      targetSemantics: json['targetSemantics']?.toString() ?? '',
      thresholdMappingAllowed: json['thresholdMappingAllowed'] == true,
      fallbackReason: json['fallbackReason']?.toString(),
    );
  }

  bool get isUnavailable =>
      calculationMode == 'unavailable' || predictedWaterLevel == null;

  String get modeDisplayLabel {
    switch (calculationMode) {
      case 'primary_model':
        return 'PRIMARY MODEL';
      case 'persistence_fallback':
        return 'PERSISTENCE FALLBACK';
      default:
        return 'FORECAST UNAVAILABLE';
    }
  }
}

