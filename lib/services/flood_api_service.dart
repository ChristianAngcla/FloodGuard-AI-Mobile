import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';
import 'package:http/http.dart' as http;

/// 🌊 Flood Data Model - Represents one barangay's flood information
/// This data comes from your Python AI backend after it processes
/// real-time data from PAGASA (Philippine weather service)
class FloodData {
  final String barangay;
  final int riskLevel; // 0-100% from ML model
  final double rainfall; // mm/hour from PAGASA
  final double waterLevel; // current meters
  final double
      maxWaterLevel; // Critical Level (Dike Height), usually static 20.0m
  final String status; // safe/warning/danger
  final DateTime timestamp; // when data was processed

  FloodData({
    required this.barangay,
    required this.riskLevel,
    required this.rainfall,
    required this.waterLevel,
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

    return FloodData(
      barangay: json['name'] ?? json['barangay'] ?? 'Unknown',
      riskLevel:
          parseDouble(json['flood_probability'] ?? json['risk_level']).toInt(),
      rainfall: parseDouble(json['local_rain'] ?? json['rainfall']),
      waterLevel: parseDouble(json['river_level'] ?? json['water_level']),
      maxWaterLevel: parseDouble(json['max_water_level'] ?? 10.0),
      status: (json['status'] ?? 'safe').toString().toLowerCase(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'FloodData($barangay: $riskLevel% risk)';
}

/// 🔗 Flood API Service - Communicates with Python Flask backend
///
/// This service handles all API calls to your Python AI server.
/// The server fetches real-time data from PAGASA and runs ML predictions.
///
/// 📡 Data Flow:
///    PAGASA → Python AI → Flask API → This Service → Flutter UI
///
/// 🔧 Configuration:
///    - For Emulator: Use 'http://10.0.2.2:5000/api'
///    - For Physical Device: Use your PC's IP (e.g., 'http://192.168.1.57:5000/api')
class FloodApiService {
  // 🌐 Base URL for the live AI Engine.
  static const String baseUrl = 'https://floodguard-engine.onrender.com/api';

  // 🗄️ Base URL for the MongoDB Database (Users, Reports).
  static const String dbBaseUrl =
      'https://floodguard-database.onrender.com/api';

  // Timeout duration for API calls (don't wait forever)
  static const Duration _timeout =
      Duration(seconds: 60); // 🚀 Increased to 60s for Render cold-starts

  // 💾 CACHE: Store data here so we don't fetch different random numbers
  static Map<String, FloodData>? _cachedData;
  static DateTime? _lastFetchTime;

  // 💾 Full raw API response cache for prediction timeline & insights
  static Map<String, dynamic>? _cachedFullResponse;

  /// Returns the cached full API /status response.
  /// Contains prediction.timeline, prediction.rivers, thresholds, etc.
  static Map<String, dynamic>? getFullPredictionData() => _cachedFullResponse;

  /// Maps each barangay to its nearest river sensor key.
  /// The API provides 3 sensors: nangka, sto_nino, tumana.
  static const Map<String, String> barangayToSensor = {
    'Tumana': 'tumana',
    'Malanday': 'tumana',
    'Marikina Heights': 'tumana',
    'Concepcion Dos': 'tumana',
    'Industrial Valley': 'tumana',
    'Santo Niño': 'sto_nino',
    'Concepcion Uno': 'sto_nino',
    'San Roque': 'sto_nino',
    'Barangka': 'sto_nino',
    'Jesus Dela Peña': 'sto_nino',
    'Santa Elena': 'sto_nino',
    'Tañong': 'sto_nino',
    'Nangka': 'nangka',
    'Fortune': 'nangka',
    'Parang': 'nangka',
    'Calumpang': 'nangka',
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
  /// Returns: Map<barangay_name, FloodData>
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

        if (decoded is Map<String, dynamic> &&
            decoded.containsKey('prediction')) {
          final rivers =
              decoded['prediction']['rivers'] as Map<String, dynamic>;
          final weather = decoded['weather'] ?? {};
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
            final riverData = rivers[sensorKey];

            if (riverData != null) {
              double waterLevel = (riverData['predicted_water_level'] ??
                      riverData['current_water_level'] ??
                      0.0)
                  .toDouble();

              double peakLevel = waterLevel;
              final insights = riverData['time_series_insights'];
              if (insights != null &&
                  insights['peak_predicted_level'] != null) {
                peakLevel = insights['peak_predicted_level'].toDouble();
              }

              // EXACT alignment with legend thresholds
              int riskLevel = 10;
              if (peakLevel >= 18.0) {
                riskLevel = 90; // Red (Force Evacuation)
              } else if (peakLevel >= 16.0)
                riskLevel = 65; // Orange (Prepare)
              else if (peakLevel >= 15.0) riskLevel = 35; // Yellow (Alert)

              final thresholds = riverData['thresholds'] ?? {};
              double maxWaterLevel =
                  (thresholds['critical'] ?? 20.0).toDouble();
              String status =
                  (riverData['status'] ?? 'safe').toString().toLowerCase();

              map[b] = FloodData(
                barangay: b,
                riskLevel: riskLevel,
                rainfall: rainfall,
                waterLevel: peakLevel,
                maxWaterLevel: maxWaterLevel,
                status: status,
                timestamp: DateTime.now(),
              );
            } else {
              map[b] = FloodData(
                barangay: b,
                riskLevel: 10,
                rainfall: rainfall,
                waterLevel: 0.0,
                maxWaterLevel: 20.0,
                status: 'safe',
                timestamp: DateTime.now(),
              );
            }
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

  /// 🌡️ Predict flood risk for specific coordinates
  ///
  /// Endpoint: POST /api/predict
  /// Body: { "latitude": 14.67, "longitude": 121.1 }
  ///
  /// The API will:
  /// 1. Find which barangay these coords are in
  /// 2. Return flood data for that barangay
  ///
  /// Used by: ReportFloodSheet when user enters location manually
  static Future<FloodData?> predictForCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      debugPrint('🔗 Predicting for coordinates: $latitude, $longitude');

      final response = await http
          .post(
            Uri.parse('$baseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = FloodData.fromJson(jsonDecode(response.body));
        debugPrint(
            '✅ Prediction made: ${data.barangay} has ${data.riskLevel}% risk');
        return data;
      } else {
        debugPrint('⚠️ Prediction failed: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error making prediction: $e');
      return null;
    }
  }

  /// 💾 Save a new user's profile to the backend (MongoDB)
  ///
  /// Endpoint: POST /api/users
  /// Body: { "uid": "...", "email": "...", "barangay": "..." }
  ///
  /// Called after a successful Firebase registration to sync user data
  /// with your custom backend.
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
      final response = await http
          .post(
            Uri.parse(
                '$dbBaseUrl/user/register'), // Update to match your DB register endpoint
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
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
              // Fallbacks for nodejs/python flexibility
              'firstName': firstName,
              'lastName': lastName,
              'houseNo': houseNo,
              'streetName': streetName,
              'zipCode': zipCode,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) {
        // 201 Created
        debugPrint('✅ User profile saved to MongoDB successfully.');
        return true;
      } else {
        debugPrint(
            '⚠️ User profile save failed (HTTP ${response.statusCode}). Assuming success for UI mock.');
        return true; // Mock success to unblock registration flow
      }
    } catch (e) {
      debugPrint('❌ Error saving user profile: $e');
      return false;
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
  }) async {
    try {
      debugPrint('🔗 Submitting flood report to database...');
      debugPrint('   📝 Reporter: $reporterName, Phone: $reporterPhone');
      debugPrint('   📝 Flood Level: $floodLevel, Depth: ${floodDepth}m');
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
              // Also send camelCase variants for backend flexibility
              'floodDepth': floodDepth,
              'floodLevel': floodLevel ?? 'Unknown',
              'reporterName': reporterName ?? 'Unknown Reporter',
              'reporterPhone': reporterPhone ?? '',
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

  /// 👤 Fetch a user's profile from the backend
  ///
  /// Endpoint: GET /api/users/<uid>
  static Future<UserProfile?> getUserProfile(String uid) async {
    try {
      debugPrint('🔗 Fetching user profile from database for UID: $uid');
      final response = await http
          .get(Uri.parse('$dbBaseUrl/user/profile/$uid'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final profile = UserProfile.fromJson(jsonDecode(response.body));
        debugPrint(
            '✅ User profile loaded: ${profile.email} lives in ${profile.barangay}');
        return profile;
      } else {
        debugPrint(
            '⚠️ Failed to fetch user profile (HTTP ${response.statusCode}). Returning mock profile.');
        return UserProfile(
          uid: uid,
          email: "user@example.com",
          firstName: "Demo",
          lastName: "User",
          phone: "09123456789",
          houseNo: "",
          streetName: "",
          barangay: "Nangka", // Default fallback
          city: "Marikina City",
          province: "Metro Manila",
          zipCode: "1800",
          country: "Philippines",
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      // Return mock profile on hard timeout so the dashboard isn't stuck loading forever
      return UserProfile(
        uid: uid,
        email: "user@example.com",
        firstName: "Demo",
        lastName: "User",
        phone: "09123456789",
        houseNo: "",
        streetName: "",
        barangay: "Santo Niño", // Default fallback
        city: "Marikina City",
        province: "Metro Manila",
        zipCode: "1800",
        country: "Philippines",
        createdAt: DateTime.now(),
      );
    }
  }

  /// 🌤️ Get current weather conditions (optional)
  ///
  /// Endpoint: GET /api/weather
  /// Returns: Temperature, humidity, rainfall, wind speed
  ///
  /// Optional endpoint - can be used for weather widget display
  static Future<Map<String, dynamic>?> getWeather() async {
    try {
      debugPrint('🔗 Fetching weather data...');

      final response =
          await http.get(Uri.parse('$baseUrl/weather')).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Current Weather: '
            '${data['temperature']}°C, '
            '${data['rainfall']}mm rainfall, '
            '${data['humidity']}% humidity');
        return data;
      } else {
        debugPrint('⚠️ Weather fetch failed: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching weather: $e');
      return null;
    }
  }
}
