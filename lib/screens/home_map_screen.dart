import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/welcome_popup.dart';
import 'login_screen.dart';
import '../models/city.dart';
import '../models/barangay.dart';
import '../data/translations.dart';
import '../widgets/app_drawer.dart';
import '../widgets/multistep_report_sheet.dart';
import '../widgets/flood_legend_card.dart';
import '../widgets/pulsing_location_dot.dart';
import '../widgets/weather_card.dart';
import '../screens/barangay_details_sheet.dart';
import '../services/flood_api_service.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/station_thresholds.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';
import '../widgets/wave_background.dart';

class HomeMapScreen extends StatefulWidget {
  final bool initialDarkMode;
  final bool initialTaglish;

  // Static cache of Marikina barangay centers calculated from GeoJSON.
  // Helps widgets like WeatherCard query coordinates directly without reloading the GeoJSON.
  static final Map<String, LatLng> barangayCenters = {};

  const HomeMapScreen({
    super.key,
    this.initialDarkMode = false,
    this.initialTaglish = false,
  });

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  late bool _isDarkMode;
  double _currentZoom = 13.0;
  List<Barangay> marikinaBarangays = [];
  Map<String, LatLng> _barangayCenters = {};
  Map<String, FloodData> _barangayData = {};
  String? _hoveredBarangayName;
  String? _selectedBarangayName;
  int _currentBarangayIndex = 0;
  bool _hasShownEarlyWarning = false;
  bool _isInitialLoading = true;
  DateTime? _lastFetchTime;
  Timer? _autoRefreshTimer;

  int _currentTabIndex = 1; // Default to Map View
  UserProfile? _userProfile;
  bool _isLoggedIn = false;

  String? _dashboardSelectedBarangay;

  bool _isLegendExpanded = false;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  LatLng? _myLocation;
  final LatLngBounds marikinaBounds = LatLngBounds(
    LatLng(14.62, 121.05), // southwest
    LatLng(14.69, 121.14), // northeast
  );

  late bool _isTaglish;
  bool _isLoading = false;
  bool get _isMarikinaSelected {
    return cities.isNotEmpty &&
        cities[currentCityIndex].name.toLowerCase() == "marikina";
  }

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _loadingRippleController;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
    _isTaglish = widget.initialTaglish;

    // 🌊 Setup "Breathing" Animation for Map Polygons
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation =
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine);
    _pulseController.addListener(() {
      // Only rebuild the UI if the user is actively on the Map Tab to prevent massive typing lag in other tabs!
      if (mounted && _currentTabIndex == 1) setState(() {});
    });

    // 🌊 Setup Ripple Animation for Loading Screen
    _loadingRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // 🔄 Auto-refresh timer every 3 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (mounted && _currentTabIndex == 1 && !_isLoading) {
        _refreshData(silent: true);
      }
    });

    _performInitialLoad();
  }

  Future<void> _performInitialLoad() async {
    // Load boundaries and barangay data
    await loadBoundaries();
    await loadMarikinaBarangays();
    await _fetchUserProfile();
    _startLocationTracking();

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
      // Show welcome pop-up after loading is complete
      _showWelcomePopup();
    }
  }

  Future<void> _fetchUserProfile() async {
    _isLoggedIn = await AuthService().isLoggedIn();
    if (!_isLoggedIn) {
      if (mounted) setState(() => _userProfile = null);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        final profile = UserProfile.fromJson(jsonDecode(userDataString));

        if (mounted) {
          setState(() {
            _userProfile = profile;
          });

          debugPrint(
              '👤 PROFILE LOADED: ${profile.firstName} ${profile.lastName}');
          debugPrint('🏠 BARANGAY: "${profile.barangay}"');

          // 🔔 AUTO-SUBSCRIBE: Ensure the user is subscribed to their barangay alerts
          if (profile.barangay.isNotEmpty) {
            NotificationService.subscribeToBarangay(profile.barangay);
          } else {
            debugPrint('⚠️ NO BARANGAY FOUND: Skipping alert subscription.');
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading profile on Map: $e");
    }
  }

  void _animateCameraToBarangay() {
    if (marikinaBarangays.isEmpty) return;
    final name = marikinaBarangays[_currentBarangayIndex].name;
    final target = _barangayCenters[name];
    if (target == null) return;

    final start = _mapController.center;
    final startZoom = _mapController.zoom;
    const endZoom = 15.5;

    const duration = Duration(milliseconds: 600);
    const steps = 30;
    final stepTime = duration.inMilliseconds ~/ steps;

    int currentStep = 0;

    Timer.periodic(Duration(milliseconds: stepTime), (timer) {
      currentStep++;

      final t = Curves.easeInOutCubic.transform(currentStep / steps);

      final lat = start.latitude + (target.latitude - start.latitude) * t;
      final lng = start.longitude + (target.longitude - start.longitude) * t;
      final zoom = startZoom + (endZoom - startZoom) * t;

      _mapController.move(LatLng(lat, lng), zoom);

      if (currentStep >= steps) {
        timer.cancel();
      }
    });
  }

  void _animateCameraReset() {
    final target = LatLng(14.6503, 121.1020); // Marikina center
    final start = _mapController.center;
    final startZoom = _mapController.zoom;
    const endZoom = 13.0;

    const duration = Duration(milliseconds: 600);
    const steps = 30;
    final stepTime = duration.inMilliseconds ~/ steps;

    int currentStep = 0;

    Timer.periodic(Duration(milliseconds: stepTime), (timer) {
      currentStep++;

      final t = Curves.easeInOutCubic.transform(currentStep / steps);

      final lat = start.latitude + (target.latitude - start.latitude) * t;
      final lng = start.longitude + (target.longitude - start.longitude) * t;
      final zoom = startZoom + (endZoom - startZoom) * t;

      _mapController.move(LatLng(lat, lng), zoom);

      if (currentStep >= steps) {
        timer.cancel();
      }
    });
  }

  void _startLocationTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // updates every 5 meters
        ),
      ).listen((Position position) {
        setState(() {
          _currentLocation = LatLng(
            position.latitude,
            position.longitude,
          );
          _myLocation = LatLng(position.latitude, position.longitude);
        });
      });
    }
  }

  void _centerOnMe() {
    if (_myLocation == null) return;

    _mapController.move(
      _myLocation!,
      16, // zoom level (feels good for city navigation)
    );
  }

  void _showReportSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isTaglish
              ? "Salamat! Natanggap na ang iyong ulat."
              : "Thank you! Your report has been sent.",
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showSafeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t("gladSafe"),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Color _getRiskColor(int risk) {
    if (risk < 20) return const Color(0xFF4CAF50); // Green (Safe)
    if (risk < 50) return const Color(0xFFFFC107); // Yellow (Alert)
    if (risk < 80) {
      return const Color(0xFFFF9800); // Orange (Prepare to Evacuate)
    }
    return const Color(0xFFE53935); // Red (Force Evacuation)
  }

  LatLng _calculateCentroid(List<LatLng> points) {
    double latSum = 0;
    double lngSum = 0;
    for (var p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygonPoints) {
    bool isInside = false;
    int j = polygonPoints.length - 1;
    for (int i = 0; i < polygonPoints.length; i++) {
      if ((polygonPoints[i].latitude > point.latitude) !=
          (polygonPoints[j].latitude > point.latitude)) {
        if (point.longitude <
            (polygonPoints[j].longitude - polygonPoints[i].longitude) *
                    (point.latitude - polygonPoints[i].latitude) /
                    (polygonPoints[j].latitude - polygonPoints[i].latitude) +
                polygonPoints[i].longitude) {
          isInside = !isInside;
        }
      }
      j = i;
    }
    return isInside;
  }

  Future<void> loadMarikinaBarangays({bool forceRefresh = false}) async {
    try {
      // Step 1: Load barangay boundaries from GeoJSON
      final data = await rootBundle.loadString(
        'assets/marikina1.geojson',
      );

      final json = jsonDecode(data);
      final features = json['features'] as List<dynamic>;

      final List<Barangay> loaded = [];
      final Map<String, LatLng> centers = {};
      final Map<String, FloodData> loadedData = {};

      // Step 2: Fetch REAL data from your teammate's Python backend
      Map<String, FloodData> apiData = {};
      try {
        apiData = await FloodApiService.getAllBarangayFloodData(
            forceRefresh: forceRefresh);
        if (apiData.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Connection failed. Check IP & Server."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        debugPrint("⚠️ Could not fetch API data, using defaults. Error: $e");
      }

      for (int i = 0; i < features.length; i++) {
        final feature = features[i];
        final props = feature['properties'] ?? {};
        final name = props['NAME_3'] ??
            props['name'] ??
            props['NAME'] ??
            props['barangay'] ??
            'Unknown Barangay';

        final geometry = feature['geometry'];
        List coords;

        if (geometry['type'] == 'Polygon') {
          coords = geometry['coordinates'][0];
        } else if (geometry['type'] == 'MultiPolygon') {
          coords = geometry['coordinates'][0][0];
        } else {
          debugPrint("⚠️ Skipping $name - Unsupported geometry type");
          continue;
        }

        final points = coords
            .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();

        if (points.isEmpty) {
          debugPrint("⚠️ Skipping $name - No coordinates");
          continue;
        }

        debugPrint("📍 $name - ${points.length} points");

        LatLng center = _calculateCentroid(points);

        // 🛠️ Manual Adjustments to prevent marker overcrowding
        if (name == "Tañong" || name == "Tanong") {
          center = LatLng(center.latitude + 0.003, center.longitude - 0.002);
        } else if (name == "Barangka") {
          center = LatLng(center.latitude - 0.0045, center.longitude - 0.001);
        } else if (name == "Jesus Dela Peña" ||
            name == "Jesus de la Peña" ||
            name == "Jesus De La Pena") {
          center = LatLng(center.latitude - 0.003, center.longitude + 0.002);
        }

        centers[name] = center;

        // Color by THIS barangay's river WL vs THAT river's Alert/Alarm/Critical
        final matchedData = FloodApiService.findDataForBarangay(apiData, name);
        final sensorKey = FloodApiService.barangayToSensor[name] ?? 'sto_nino';
        final thr = StationThresholds.forSensor(sensorKey);
        double levelForColor = matchedData?.waterLevel ?? 0.0;
        // Prefer peak when available from full API cache
        final full = FloodApiService.getFullPredictionData();
        final river = full?['prediction']?['rivers']?[sensorKey];
        if (river is Map) {
          final peak = river['time_series_insights']?['peak_predicted_level'];
          final pred = river['predicted_water_level'];
          if (peak is num) {
            levelForColor = peak.toDouble();
          } else if (pred is num) {
            levelForColor = pred.toDouble();
          }
          final apiThr = river['thresholds'];
          if (apiThr is Map) {
            // keep StationThresholds.forSensor unless API has all three
          }
        }

        Color baseColor;
        switch (thr.statusFor(levelForColor)) {
          case ColorStatus.critical:
            baseColor = const Color(0xFFD32F2F);
            break;
          case ColorStatus.warning:
            baseColor = const Color(0xFFFF9800);
            break;
          case ColorStatus.alert:
            baseColor = const Color(0xFFFBC02D);
            break;
          case ColorStatus.safe:
            baseColor = const Color(0xFF4CAF50);
            break;
        }

        if (matchedData != null) {
          loadedData[name] = matchedData;
          debugPrint(
              "🌊 $name: ${levelForColor.toStringAsFixed(2)}m → ${thr.statusFor(levelForColor).label} ($sensorKey)");
        }

        loaded.add(
          Barangay(
            name: name,
            polygon: Polygon(
              points: points,
              color: baseColor.withValues(alpha: 0.5),
              borderColor: baseColor.withValues(alpha: 0.9),
              borderStrokeWidth: 2,
            ),
          ),
        );
      }

      setState(() {
        marikinaBarangays = loaded;
        _barangayCenters = centers;
        HomeMapScreen.barangayCenters.clear();
        HomeMapScreen.barangayCenters.addAll(centers);
        _barangayData = loadedData;
      });

      // Check for early warning based on user location
      _checkEarlyWarning();

      debugPrint("✅ Barangays loaded: ${loaded.length}");
    } catch (e) {
      debugPrint("❌ Barangay load failed: $e");
    }
  }

  void _checkEarlyWarning() async {
    // Prevent showing multiple times in one session
    if (_hasShownEarlyWarning) return;

    // Only check if user is logged in
    if (!_isLoggedIn || _userProfile == null) return;

    final userBarangay = _userProfile!.barangay;
    final sensorKey =
        FloodApiService.barangayToSensor[userBarangay] ?? 'sto_nino';
    final thr = StationThresholds.forSensor(sensorKey);

    double level = 0.0;
    final data =
        FloodApiService.findDataForBarangay(_barangayData, userBarangay);
    if (data != null) level = data.waterLevel;

    final river = FloodApiService.getFullPredictionData()?['prediction']
        ?['rivers']?[sensorKey];
    if (river is Map) {
      final peak = river['time_series_insights']?['peak_predicted_level'];
      final pred = river['predicted_water_level'];
      if (peak is num) {
        level = peak.toDouble();
      } else if (pred is num) {
        level = pred.toDouble();
      }
    }

    final status = thr.statusFor(level);
    // Only warn when this barangay's river reaches Alert / Alarm / Critical
    if (status == ColorStatus.safe) return;

    _hasShownEarlyWarning = true;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _showEarlyWarningDialog(status.label, level, userBarangay, thr);
      }
    });
  }

  void _showEarlyWarningDialog(
    String statusLabel,
    double level,
    String location,
    StationThresholds thr,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.red, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t("earlyWarningTitle"),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isTaglish
                  ? 'Babala ($statusLabel): ${level.toStringAsFixed(2)} m sa $location.\n'
                      'Alert ${thr.alert.toStringAsFixed(2)} · Alarm ${thr.alarm.toStringAsFixed(2)} · Critical ${thr.critical.toStringAsFixed(2)} m.\n'
                      'Sundin ang opisyal na babala ng PAGASA/MDRRMO. Ang prediksyon ay hindi 100% tumpak.'
                  : 'Warning ($statusLabel): ${level.toStringAsFixed(2)} m at $location.\n'
                      'Alert ${thr.alert.toStringAsFixed(2)} · Alarm ${thr.alarm.toStringAsFixed(2)} · Critical ${thr.critical.toStringAsFixed(2)} m.\n'
                      'Follow official PAGASA/MDRRMO advisories. Predictions are not 100% accurate.',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isTaglish
                          ? "Pinapayuhan ang paghahanda at pagiging alerto."
                          : "Preparation and monitoring is strongly advised.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t("dismiss"),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _showBarangayDetails(location);
              _showPreparednessGuide();
            },
            child: Text(t("beReady")),
          ),
        ],
      ),
    );
  }

  void _showPreparednessGuide() {
    final isDark = _isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A2B3C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B3C);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.health_and_safety_rounded,
                      color: Color(0xFF3784DF), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    t("prepTitle"),
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: [
                    _buildPrepStep(Icons.backpack_outlined, t("prepStep1Title"),
                        t("prepStep1Desc")),
                    _buildPrepStep(Icons.home_work_outlined,
                        t("prepStep2Title"), t("prepStep2Desc")),
                    _buildPrepStep(Icons.radio_outlined, t("prepStep3Title"),
                        t("prepStep3Desc")),
                    _buildPrepStep(Icons.directions_run_rounded,
                        t("prepStep4Title"), t("prepStep4Desc")),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.contact_phone_rounded,
                                  color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                t("emergencyHotlines"),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildHotlineItem(Icons.phone_in_talk_rounded,
                              "Marikina Rescue", "161"),
                          _buildHotlineItem(Icons.security_rounded,
                              "PNP Marikina", "(02) 8942-0489"),
                          _buildHotlineItem(Icons.local_hospital_rounded,
                              "Amang Rodriguez Med Ctr", "(02) 8941-5854"),
                          _buildHotlineItem(Icons.warning_rounded,
                              "National Emergency", "911"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3784DF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(t("gotIt"),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrepStep(IconData icon, String title, String desc) {
    final titleColor = _isDarkMode ? Colors.white : Colors.black87;
    final descColor = _isDarkMode ? Colors.white70 : Colors.grey[700];
    final bg = _isDarkMode ? const Color(0xFF253B50) : Colors.white;
    final border = _isDarkMode ? Colors.white10 : Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3784DF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF3784DF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: titleColor),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(color: descColor, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotlineItem(IconData icon, String name, String number) {
    final nameColor = _isDarkMode ? Colors.white : Colors.black87;
    final numColor = _isDarkMode ? Colors.white70 : Colors.grey[700];
    final bg = _isDarkMode ? const Color(0xFF253B50) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final Uri launchUri = Uri(
              scheme: 'tel',
              path: number.replaceAll(RegExp(r'[^\d+]'), ''),
            );
            try {
              // Bypass canLaunchUrl bug in Android 11+ and force intent
              await launchUrl(launchUri, mode: LaunchMode.externalApplication);
            } catch (e) {
              debugPrint("Could not launch dialer: $e");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(_isTaglish
                          ? "Hindi mabuksan ang dialer."
                          : "Could not open dialer.")),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: nameColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        number,
                        style: TextStyle(
                            color: numColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_rounded,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData({bool silent = false}) async {
    if (_isLoading) return;
    if (!silent) setState(() => _isLoading = true);

    await loadMarikinaBarangays(forceRefresh: true);
    await _fetchUserProfile();

    if (mounted) {
      setState(() {
        if (!silent) _isLoading = false;
        _lastFetchTime = DateTime.now();
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t("refreshSuccess")),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(
          position.latitude,
          position.longitude,
        );
      });

      // 👇 Move map to your location
      _mapController.move(_currentLocation!, 15);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  String t(String key) {
    return Translations.texts[key]?[_isTaglish ? "tl" : "en"] ?? key;
  }

  final String _lightMapUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  final String _darkMapUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  List<City> cities = [];
  int currentCityIndex = 0; // start with the first city
  List<Polygon> polygons = [];
  LatLng? _highlightedLocation;
  String? _highlightedPlaceName;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _pulseController.dispose();
    _loadingRippleController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  void _showBarangayDetails(String barangayName) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return BarangayDetailsSheet(
          barangayName: barangayName,
          isTaglish: _isTaglish,
          isDarkMode: _isDarkMode,
        );
      },
    );

    if (mounted) {
      setState(() {
        _selectedBarangayName = null;
      });
      _animateCameraReset();
    }
  }

  // Load polygons function (same as before)
  Future<Polygon> loadPolygon(String assetPath, Color color) async {
    final data = await rootBundle.loadString(assetPath);
    final jsonData = jsonDecode(data);

    final feature = jsonData["features"][0];
    final geometry = feature["geometry"];

    List<dynamic> coords;

    if (geometry["type"] == "Polygon") {
      coords = geometry["coordinates"][0];
    } else if (geometry["type"] == "MultiPolygon") {
      coords = geometry["coordinates"][0][0];
    } else {
      throw Exception("Unsupported geometry type");
    }

    final points = coords
        .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
        .toList();

    return Polygon(
      points: points,
      color: color.withValues(alpha: 0.15),
      borderColor: color.withValues(alpha: 0.9),
      borderStrokeWidth: 2,
    );
  }

  /// Loads the boundaries of the floodguard areas from geojson files
  /// and adds them to the [polygons] list. The boundaries are
  /// colored according to the flood zone they represent.
  ///
  /// The boundaries are loaded from the following files:
  /// - "assets/geojson/quezon_city.geojson"
  /// - "assets/geojson/manila.geojson"
  /// - "assets/geojson/pasig.geojson"
  /// - "assets/geojson/marikina.geojson"
  ///
  /// The boundaries are colored as follows:
  /// - Blue: Quezon City
  /// - Red: Manila
  /// - Green: Pasig
  /// - Orange: Marikina
  ///
  /// After loading the boundaries, the state is updated to show them
  /// on the map.
  Future<void> loadBoundaries() async {
    try {
      debugPrint("🔥 loadBoundaries() STARTED");

      cities = [
        City(
          name: "Marikina",
          center: LatLng(14.6503, 121.1020),
          polygon: Polygon(
            points: [LatLng(14.6503, 121.1020)],
            color: Colors.transparent,
          ),
        ),
      ];

      debugPrint("✅ loadBoundaries() FINISHED — cities loaded");

      setState(() {});
    } catch (e, stack) {
      debugPrint("❌ loadBoundaries FAILED: $e");
      debugPrint(stack.toString());
    }
  }

  Polygon buildOutsideMask(Polygon marikinaPolygon) {
    return Polygon(
      points: [
        LatLng(-90, -180),
        LatLng(-90, 180),
        LatLng(90, 180),
        LatLng(90, -180),
      ],
      holePointsList: [
        marikinaPolygon.points,
      ],
      color: _isDarkMode
          ? Colors.black.withValues(alpha: 0.65)
          : Colors.black.withValues(alpha: 0.45),
      borderStrokeWidth: 0,
    );
  }

  void nextBarangay() {
    HapticFeedback.selectionClick();
    if (marikinaBarangays.isEmpty) return;

    setState(() {
      _currentBarangayIndex =
          (_currentBarangayIndex + 1) % marikinaBarangays.length;
      _selectedBarangayName = marikinaBarangays[_currentBarangayIndex].name;
    });

    _animateCameraToBarangay();
  }

  void prevBarangay() {
    HapticFeedback.selectionClick();
    if (marikinaBarangays.isEmpty) return;

    setState(() {
      _currentBarangayIndex =
          (_currentBarangayIndex - 1 + marikinaBarangays.length) %
              marikinaBarangays.length;
      _selectedBarangayName = marikinaBarangays[_currentBarangayIndex].name;
    });

    _animateCameraToBarangay();
  }

  void _showWelcomePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WelcomePopup(
          isTaglish: _isTaglish,
          isDarkMode: _isDarkMode,
          warningTitle: t("marikinaWarningTitle"),
          warningBody: t("marikinaWarningDesc"),
          onOpenFloodMap: () {
            Navigator.pop(context);
            // You are already on the map screen,
            // so this simply closes the popup
          },
        );
      },
    );
  }

  void _showReportFloodSheet() {
    // 🔒 Security Check: Must be logged in to report
    if (!_isLoggedIn) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              // const Icon(Icons.lock_rounded, color: Color(0xFF3784DF)),
              const SizedBox(width: 10),
              Text(t("loginRequired")),
            ],
          ),
          content: Text(t("loginToReport")),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text(t("close"), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3784DF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      isTaglish: _isTaglish,
                      isDarkMode: _isDarkMode,
                    ),
                  ),
                );
              },
              child: Text(t("signInUp")),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF1A2B3C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return MultistepReportSheet(
          isTaglish: _isTaglish,
          isDarkMode: _isDarkMode,
          onSuccess: _showReportSuccess,
          onSafe: _showSafeMessage,
          onUnsafe: _showPreparednessGuide,
        );
      },
    );
  }

  void _handleMapHover(Offset localPosition) {
    if (!cities.isNotEmpty || cities[currentCityIndex].name != "Marikina") {
      return;
    }

    // Convert screen point to LatLng
    final point = _mapController.camera.pointToLatLng(
      math.Point(localPosition.dx, localPosition.dy),
    );

    String? foundBarangay;
    for (var b in marikinaBarangays) {
      if (_isPointInPolygon(point, b.polygon.points)) {
        foundBarangay = b.name;
        break;
      }
    }

    if (_hoveredBarangayName != foundBarangay) {
      setState(() {
        _hoveredBarangayName = foundBarangay;
      });
    }
  }

  Widget _buildMenuButton() {
    return IconButton(
      icon: Icon(Icons.settings_rounded,
          color: _isDarkMode ? Colors.white : const Color(0xFF3784DF)),
      onPressed: () {
        _scaffoldKey.currentState?.openEndDrawer();
      },
    );
  }

  Widget _buildRefreshButton() {
    final timeStr = _lastFetchTime != null 
        ? "${_lastFetchTime!.hour > 12 ? _lastFetchTime!.hour - 12 : (_lastFetchTime!.hour == 0 ? 12 : _lastFetchTime!.hour)}:${_lastFetchTime!.minute.toString().padLeft(2, '0')} ${_lastFetchTime!.hour >= 12 ? 'PM' : 'AM'}"
        : "";
        
    if (timeStr.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, 
            size: 14, 
            color: _isDarkMode ? Colors.white70 : Colors.black54),
          const SizedBox(width: 4),
          Text(
            _isTaglish ? "Huling update: $timeStr" : "Last updated: $timeStr",
            style: TextStyle(
              fontSize: 11, 
              color: _isDarkMode ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detect if the keyboard is currently open to prevent UI overlapping
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkMode
          ? const Color(0xFF1A2B3C) // dark background
          : const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // 1. Main Content (Map, Home, or Profile)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _currentTabIndex == 0
                ? _buildHomeDashboard()
                : _currentTabIndex == 3
                    ? AlertsScreen(
                        isTaglish: _isTaglish,
                        isDarkMode: _isDarkMode,
                      )
                    : _currentTabIndex == 2
                        ? ProfileScreen(
                            isTaglish: _isTaglish,
                            isDarkMode: _isDarkMode,
                            onLogout: () =>
                                setState(() => _currentTabIndex = 1),
                          )
                        : MouseRegion(
                            key: const ValueKey('map_view'),
                            onHover: (event) =>
                                _handleMapHover(event.localPosition),
                            child: FlutterMap(
                              key: ValueKey(_isDarkMode),
                              mapController: _mapController,
                              options: MapOptions(
                                center: LatLng(
                                    14.6503, 121.1020), // Marikina center
                                zoom: 13,
                                minZoom: 12,
                                maxZoom: 18,
                                onPositionChanged: (position, hasGesture) {
                                  if (position.zoom != null) {
                                    setState(
                                        () => _currentZoom = position.zoom!);
                                  }
                                },
                                onTap: (tapPosition, point) {
                                  if (_isMarikinaSelected) {
                                    String? tappedBarangay;
                                    for (var b in marikinaBarangays) {
                                      if (_isPointInPolygon(
                                          point, b.polygon.points)) {
                                        tappedBarangay = b.name;
                                        break;
                                      }
                                    }
                                    setState(() {
                                      _selectedBarangayName = tappedBarangay;
                                      if (tappedBarangay != null) {
                                        final index =
                                            marikinaBarangays.indexWhere((b) =>
                                                b.name == tappedBarangay);
                                        if (index != -1) {
                                          _currentBarangayIndex = index;
                                        }
                                      }
                                    });
                                    if (tappedBarangay != null) {
                                      debugPrint("Selected: $tappedBarangay");
                                      _showBarangayDetails(tappedBarangay);
                                    }
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      _isDarkMode ? _darkMapUrl : _lightMapUrl,
                                  subdomains: ['a', 'b', 'c', 'd'],
                                  userAgentPackageName:
                                      'com.example.floodguard_ai',
                                ),
                                if (_currentLocation != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _currentLocation!,
                                        width: 50,
                                        height: 50,
                                        alignment: Alignment.center,
                                        child: const PulsingLocationDot(),
                                      ),
                                    ],
                                  ),
                                if (_highlightedLocation != null)
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: _highlightedLocation!,
                                        radius: 18,
                                        useRadiusInMeter: false,
                                        color: const Color(0xFF2BA7A0)
                                            .withValues(alpha: 0.25),
                                        borderStrokeWidth: 3,
                                        borderColor: const Color(0xFF2BA7A0),
                                      ),
                                    ],
                                  ),
                                if (_highlightedLocation != null &&
                                    _highlightedPlaceName != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _highlightedLocation!,
                                        width: 200,
                                        height: 60,
                                        alignment: Alignment.topCenter,
                                        child: Column(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4F8BBF),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 6,
                                                  )
                                                ],
                                              ),
                                              child: Text(
                                                _highlightedPlaceName!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.arrow_drop_down,
                                              color: Color(0xFF4F8BBF),
                                              size: 28,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                if (marikinaBarangays.isNotEmpty)
                                  PolygonLayer(
                                    polygons: marikinaBarangays.map((b) {
                                      final isHovered =
                                          b.name == _hoveredBarangayName;
                                      final isSelected =
                                          b.name == _selectedBarangayName;

                                      // 🎨 Dynamic Border Color (Black & White)
                                      final themeBorderColor = _isDarkMode
                                          ? Colors.white
                                          : Colors.black;

                                      // 🌊 Animation Value (0.0 to 1.0)
                                      final double pulse =
                                          _pulseAnimation.value;

                                      // Dynamic styling based on zoom
                                      final double baseStroke =
                                          _currentZoom < 14.0
                                              ? 2.0
                                              : 3.0; // Thicker base

                                      double strokeWidth = baseStroke;
                                      Color borderColor = themeBorderColor
                                          .withValues(alpha: _isDarkMode
                                              ? 0.6
                                              : 0.4); // More visible default
                                      Color fillColor =
                                          b.polygon.color.withValues(alpha: 0.35);

                                      if (isSelected || isHovered) {
                                        // ✨ Active State: Strong Pulse & Thicker Line
                                        strokeWidth += 2.0 +
                                            (pulse *
                                                2.0); // Breaths 2px-4px extra
                                        borderColor =
                                            themeBorderColor.withValues(
                                                alpha: (_isDarkMode ? 0.8 : 0.7) +
                                                    (pulse * 0.2));
                                        fillColor =
                                            b.polygon.color.withValues(alpha: 0.6);
                                      } else {
                                        // 💤 Idle State: Breathing Animation
                                        strokeWidth += (pulse * 1.5);
                                      }

                                      return Polygon(
                                        points: b.polygon.points,
                                        color: fillColor,
                                        borderColor: borderColor,
                                        borderStrokeWidth: strokeWidth,
                                        isFilled: true,
                                      );
                                    }).toList(),
                                  ),
                                if (marikinaBarangays.isNotEmpty)
                                  MarkerLayer(
                                    markers:
                                        _barangayCenters.entries.map((entry) {
                                      final name = entry.key;
                                      final center = entry.value;
                                      final sensorKey =
                                          FloodApiService.barangayToSensor[name] ??
                                              'sto_nino';
                                      final thr =
                                          StationThresholds.forSensor(sensorKey);
                                      double level =
                                          _barangayData[name]?.waterLevel ?? 0.0;
                                      final river = FloodApiService
                                              .getFullPredictionData()?[
                                          'prediction']?['rivers']?[sensorKey];
                                      if (river is Map) {
                                        final peak = river['time_series_insights']
                                            ?['peak_predicted_level'];
                                        final pred = river['predicted_water_level'];
                                        if (peak is num) {
                                          level = peak.toDouble();
                                        } else if (pred is num) {
                                          level = pred.toDouble();
                                        }
                                      }
                                      final status = thr.statusFor(level);
                                      late Color riskColor;
                                      late String statusText;
                                      late Color textColor;
                                      late IconData statusIcon;
                                      switch (status) {
                                        case ColorStatus.safe:
                                          riskColor = const Color(0xFF4CAF50);
                                          statusText =
                                              _isTaglish ? "Ligtas" : "Safe";
                                          textColor = Colors.white;
                                          statusIcon = Icons.check_circle_rounded;
                                          break;
                                        case ColorStatus.alert:
                                          riskColor = const Color(0xFFFBC02D);
                                          statusText =
                                              _isTaglish ? "Alerto" : "Alert";
                                          textColor = Colors.black87;
                                          statusIcon =
                                              Icons.warning_amber_rounded;
                                          break;
                                        case ColorStatus.warning:
                                          riskColor = const Color(0xFFFF9800);
                                          statusText =
                                              _isTaglish ? "Maghanda" : "Alarm";
                                          textColor = Colors.black87;
                                          statusIcon = Icons.warning_rounded;
                                          break;
                                        case ColorStatus.critical:
                                          riskColor = const Color(0xFFD32F2F);
                                          statusText =
                                              _isTaglish ? "Lumikas" : "Critical";
                                          textColor = Colors.white;
                                          statusIcon = Icons.dangerous_rounded;
                                          break;
                                      }

                                      // Dynamic Layout: Switch to compact single-pill mode when zoomed out
                                      // to drastically reduce overcrowding while keeping info visible.
                                      final bool isZoomedOut =
                                          _currentZoom < 14.2;

                                      return Marker(
                                        point: center,
                                        width: isZoomedOut ? 160.0 : 200.0,
                                        height: isZoomedOut ? 60.0 : 110.0,
                                        child: isZoomedOut
                                            ? Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  // Compact Pill: [Icon] Name Risk%
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: riskColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      border: Border.all(
                                                          color: Colors.white,
                                                          width: 2),
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color: Colors.black26,
                                                          blurRadius: 4,
                                                          offset: Offset(0, 2),
                                                        )
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(statusIcon,
                                                            size: 16,
                                                            color: textColor),
                                                        const SizedBox(
                                                            width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            name,
                                                            style: TextStyle(
                                                              color: textColor,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Small pointer
                                                  ClipPath(
                                                    clipper: _TriangleClipper(),
                                                    child: Container(
                                                      width: 10,
                                                      height: 6,
                                                      color: riskColor,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  // 1. Barangay Name Label (Top)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: _isDarkMode
                                                          ? Colors.black87
                                                          : Colors.white
                                                              .withValues(
                                                                  alpha: 0.95),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: Colors.black12,
                                                          width: 1),
                                                    ),
                                                    child: Text(
                                                      name,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: _isDarkMode
                                                            ? Colors.white
                                                            : Colors.black87,
                                                        fontSize: 13.0,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  // 2. Risk Pill (Bottom)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: riskColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                          color: Colors.white,
                                                          width: 2),
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color: Colors.black26,
                                                          blurRadius: 4,
                                                          offset: Offset(0, 2),
                                                        )
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(statusIcon,
                                                            size: 16.0,
                                                            color: textColor),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                          statusText,
                                                          style: TextStyle(
                                                            color: textColor,
                                                            fontSize: 13.0,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Triangle pointer
                                                  ClipPath(
                                                    clipper: _TriangleClipper(),
                                                    child: Container(
                                                      width: 14,
                                                      height: 9,
                                                      color: riskColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
          ),

          // 2. Top Elements (Floating Top Bar & Search)
          if (!isKeyboardOpen &&
              (_currentTabIndex == 0 || _currentTabIndex == 1))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Bar
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? const Color(0xFF1A2B3C)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Center: Logo + Title
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Animated Logo
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: Image.asset(
                                  'assets/new_logo_nobg.png',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Animated Text
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutQuad,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(20 * (1 - value), 0),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  "FloodGuard",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF3784DF),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Left & Right Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildRefreshButton(),
                              _buildMenuButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Floating Bottom Navigation Bar
          if (!isKeyboardOpen)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (_isDarkMode
                                ? const Color(0xFF253B50)
                                : Colors.white)
                            .withValues(alpha: 0.85),
                        border: Border.all(
                          color: _isDarkMode
                              ? Colors.white10
                              : Colors.white.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(
                            icon: Icons.home_rounded,
                            label: _isTaglish ? "Tahanan" : "Home",
                            index: 0,
                          ),
                          _buildNavItem(
                            icon: Icons.map_rounded,
                            label: _isTaglish ? "Mapa" : "Map",
                            index: 1,
                          ),
                          _buildReportButton(),
                          _buildNavItem(
                            icon: Icons.notifications_active_rounded,
                            label: _isTaglish ? "Abiso" : "Alerts",
                            index: 3,
                          ),
                          _buildNavItem(
                            icon: Icons.person_rounded,
                            label: "Profile",
                            index: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4. Legend (Above Bottom Bar)
          if (_isMarikinaSelected && _currentTabIndex == 1 && !isKeyboardOpen)
            Positioned(
              bottom: 100, // Adjusted to sit above the floating bottom bar
              left: 16,
              child: FloodLegendCard(
                isDarkMode: _isDarkMode,
                isTaglish: _isTaglish,
                isExpanded: _isLegendExpanded,
                onToggle: () {
                  setState(() {
                    _isLegendExpanded = !_isLegendExpanded;
                  });
                },
              ),
            ),

          // 4b. Center Me Button (Right side, above bottom bar)
          if (_currentTabIndex == 1 && !isKeyboardOpen)
            Positioned(
              bottom: 108,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  if (_myLocation != null) {
                    _centerOnMe();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isTaglish
                              ? "Hindi makuha ang lokasyon. Paki-enable ang GPS."
                              : "Location unavailable. Please enable GPS.",
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? const Color(0xFF253B50).withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: _isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.my_location_rounded,
                    color: _myLocation != null
                        ? const Color(0xFF3784DF)
                        : (_isDarkMode ? Colors.white38 : Colors.grey),
                    size: 24,
                  ),
                ),
              ),
            ),

          // 5. Loading Indicator Overlay
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(_isDarkMode
                      ? const Color(0xFF2BA7A0)
                      : const Color(0xFF3784DF)),
                ),
              ),
            ),

          // 6. Initial Loading Screen
          IgnorePointer(
            ignoring: !_isInitialLoading,
            child: AnimatedOpacity(
              opacity: _isInitialLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              child: Container(
                color: _isDarkMode ? const Color(0xFF1A2B3C) : Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with subtle breathing and glow
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3784DF).withValues(
                                      alpha: 0.2 + (_pulseController.value * 0.3)),
                                  blurRadius:
                                      30 + (_pulseController.value * 20),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.1),
                              child: Image.asset(
                                'assets/new_logo_nobg.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 50),

                      // Title
                      Text(
                        "FloodGuard",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: _isDarkMode
                              ? Colors.white
                              : const Color(0xFF1A2B3C),
                          letterSpacing: -1.0,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        _isTaglish
                            ? "Inihahanda ang datos..."
                            : "Loading flood data...",
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              _isDarkMode ? Colors.white60 : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Minimalist Loader
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          backgroundColor:
                              _isDarkMode ? Colors.white10 : Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF3784DF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      endDrawer: AppDrawer(
        isDarkMode: _isDarkMode,
        isTaglish: _isTaglish,
        onToggleDarkMode: (value) async {
          setState(() => _isDarkMode = value);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_dark_mode', value);
        },
        onToggleLanguage: (value) async {
          setState(() => _isTaglish = value);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_taglish', value);
        },
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    bool isAction = false,
  }) {
    final isSelected = !isAction && _currentTabIndex == index;
    final activeColor = const Color(0xFF3784DF);
    final inactiveColor = _isDarkMode ? Colors.grey[500]! : Colors.grey[400]!;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isAction) {
            } else {
              setState(() => _currentTabIndex = index);
            }
          },
          borderRadius: BorderRadius.circular(34),
          highlightColor: activeColor.withValues(alpha: 0.1),
          splashColor: activeColor.withValues(alpha: 0.2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeDashboard() {
    // Get current date for the dashboard
    final now = DateTime.now();
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    final dateString = "${months[now.month - 1]} ${now.day}, ${now.year}";

    if (!_isLoggedIn) {
      return SizedBox(
        key: const ValueKey('home_no_auth'),
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_work_rounded, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _isTaglish
                    ? "Mag-login upang makita ang iyong dashboard"
                    : "Log in to view your dashboard",
                style: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    if (_userProfile == null) {
      return SizedBox(
        key: const ValueKey('home_loading'),
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                _isDarkMode ? Colors.white : const Color(0xFF3784DF)),
          ),
        ),
      );
    }

    _dashboardSelectedBarangay ??= _userProfile!.barangay;
    final allBarangays = FloodApiService.barangayToSensor.keys.toList()..sort();

    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final subColor = _isDarkMode ? Colors.white54 : Colors.grey[600];

    final selectedBarangayName =
        _dashboardSelectedBarangay ?? _userProfile?.barangay ?? 'Santo Niño';
    final center = HomeMapScreen.barangayCenters[selectedBarangayName] ??
        LatLng(14.6503, 121.1020);

    return SizedBox(
      key: const ValueKey('home_dashboard'),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          WaveBackground(isDarkMode: _isDarkMode),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  top: 140, bottom: 120, left: 24, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isTaglish ? "Magandang Araw," : "Good Day,",
                            style: TextStyle(
                                fontSize: 16,
                                color: _isDarkMode
                                    ? Colors.white70
                                    : Colors.grey[600]),
                          ),
                          Text(
                            _userProfile!.firstName,
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _isDarkMode
                                    ? Colors.white
                                    : Colors.black87),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white10 : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dateString,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[800]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Live Risk Assessment Title ──
                  Text(
                    _isTaglish
                        ? 'Live na Pagsusuri ng Panganib'
                        : 'Live Risk Assessment',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Barangay Dropdown ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color:
                          _isDarkMode ? const Color(0xFF253B50) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            _isDarkMode ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _dashboardSelectedBarangay,
                        dropdownColor: _isDarkMode
                            ? const Color(0xFF253B50)
                            : Colors.white,
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: subColor),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        items: allBarangays
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _dashboardSelectedBarangay = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Forecast header row (MOVED UP FOR PRIORITY) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isTaglish
                            ? 'Pagtataya para sa $_dashboardSelectedBarangay'
                            : 'Forecast for $_dashboardSelectedBarangay',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Sensor: $_dashboardSensorDisplayName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Forecast card ──
                  _buildDashboardForecastCard(textColor, subColor),
                  const SizedBox(height: 20),

                  // ── Weather Card ──
                  WeatherCard(
                    latitude: center.latitude,
                    longitude: center.longitude,
                    locationName: selectedBarangayName,
                    isDarkMode: _isDarkMode,
                    isTaglish: _isTaglish,
                  ),
                  const SizedBox(height: 28),

                  // ── 24-Hour Timeline ──
                  Text(
                    _isTaglish
                        ? '24-Oras na Inaasahang Timeline'
                        : '24-Hour Projected Timeline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDashboardTimeline(textColor, subColor),
                  const SizedBox(height: 28),

                  // Action Banner
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showPreparednessGuide,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? const Color(0xFF253B50)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      const Color(0xFF3784DF).withValues(alpha: 0.3),
                                  width: 1)),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF3784DF)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    Icons.health_and_safety_rounded,
                                    color: Color(0xFF3784DF),
                                    size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _isTaglish
                                          ? "Gabay sa Paghahanda"
                                          : "Preparedness Guide",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _isDarkMode
                                              ? Colors.white
                                              : Colors.black87)),
                                  const SizedBox(height: 4),
                                  Text(
                                      _isTaglish
                                          ? "Mga dapat gawin bago bumaha."
                                          : "What to do before a flood.",
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: _isDarkMode
                                              ? Colors.white70
                                              : Colors.grey[600])),
                                ],
                              )),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFF3784DF))
                            ],
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dashboard Data Helpers ──
  String get _dashboardSensorKey =>
      FloodApiService.barangayToSensor[_dashboardSelectedBarangay ??
          _userProfile?.barangay ??
          'Santo Niño'] ??
      'sto_nino';

  String get _dashboardSensorDisplayName =>
      FloodApiService.sensorDisplayNames[_dashboardSensorKey] ??
      'Unknown River';

  Map<String, dynamic>? get _dashboardRiverData {
    final full = FloodApiService.getFullPredictionData();
    if (full == null) return null;
    final rivers = full['prediction']?['rivers'] as Map<String, dynamic>?;
    return rivers?[_dashboardSensorKey] as Map<String, dynamic>?;
  }

  List<dynamic>? get _dashboardTimeline {
    final full = FloodApiService.getFullPredictionData();
    if (full == null) return null;
    return full['prediction']?['timeline'] as List<dynamic>?;
  }

  double get _dashboardCurrentWaterLevel {
    final full = FloodApiService.getFullPredictionData();
    if (full == null) return 0.0;
    final sensors = full['live_sensors'] as Map<String, dynamic>?;
    return (sensors?[_dashboardSensorKey] ?? 0.0).toDouble();
  }

  double get _dashboardPeakLevel {
    final insights = _dashboardRiverData?['time_series_insights'];
    if (insights == null) return _dashboardCurrentWaterLevel;
    return (insights['peak_predicted_level'] ?? _dashboardCurrentWaterLevel)
        .toDouble();
  }

  String get _dashboardPeakTimeShort {
    final insights = _dashboardRiverData?['time_series_insights'];
    if (insights == null) return '--';
    final full = insights['peak_expected_time']?.toString() ?? '--';
    final parts = full.split(', ');
    if (parts.length >= 2) return parts.last;
    return full;
  }

  Color _dashboardAlarmColor(double level) {
    final thr = StationThresholds.fromApiOrDefault(
        _dashboardSensorKey, _dashboardRiverData);
    switch (thr.statusFor(level)) {
      case ColorStatus.critical:
        return const Color(0xFFD32F2F);
      case ColorStatus.warning:
        return const Color(0xFFFF9800);
      case ColorStatus.alert:
        return const Color(0xFFFBC02D);
      case ColorStatus.safe:
        return const Color(0xFF4CAF50);
    }
  }

  String _dashboardAlarmLabel(double level) {
    final thr = StationThresholds.fromApiOrDefault(
        _dashboardSensorKey, _dashboardRiverData);
    switch (thr.statusFor(level)) {
      case ColorStatus.critical:
        return 'CRITICAL';
      case ColorStatus.warning:
        return 'ALARM';
      case ColorStatus.alert:
        return 'ALERT';
      case ColorStatus.safe:
        return 'NORMAL — SAFE';
    }
  }

  String _dashboardAlarmShortLabel(double level) {
    final thr = StationThresholds.fromApiOrDefault(
        _dashboardSensorKey, _dashboardRiverData);
    switch (thr.statusFor(level)) {
      case ColorStatus.critical:
        return 'CRITICAL';
      case ColorStatus.warning:
        return 'ALARM';
      case ColorStatus.alert:
        return 'ALERT';
      case ColorStatus.safe:
        return 'SAFE';
    }
  }

  Widget _buildDashboardForecastCard(Color textColor, Color? subColor) {
    final peak = _dashboardPeakLevel;
    final color = _dashboardAlarmColor(peak);
    final label = _dashboardAlarmLabel(peak);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF253B50) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROJECTED PEAK (@ ${_dashboardPeakTimeShort.toUpperCase()})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: subColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: peak.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: 'm',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: color.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _dashboardSensorDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDashboardAlarmGauge(peak),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final thr = StationThresholds.fromApiOrDefault(
                  _dashboardSensorKey, _dashboardRiverData);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isTaglish
                        ? 'Tandaan: Ang prediksyon ay HINDI 100% tumpak. Sundin ang opisyal na babala ng PAGASA/MDRRMO.'
                        : 'Note: Predictions are NOT 100% accurate. Always follow official PAGASA/MDRRMO advisories.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: _isDarkMode ? Colors.white60 : Colors.grey[700],
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildDashboardLegendItem(const Color(0xFFD32F2F),
                          'CRITICAL: ≥ ${thr.critical.toStringAsFixed(2)}m'),
                      _buildDashboardLegendItem(const Color(0xFFFF9800),
                          'ALARM: ≥ ${thr.alarm.toStringAsFixed(2)}m'),
                      _buildDashboardLegendItem(const Color(0xFFFBC02D),
                          'ALERT: ≥ ${thr.alert.toStringAsFixed(2)}m'),
                      _buildDashboardLegendItem(const Color(0xFF4CAF50),
                          'SAFE: < ${thr.alert.toStringAsFixed(2)}m'),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _isDarkMode ? Colors.white60 : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardAlarmGauge(double currentLevel) {
    final thr = StationThresholds.fromApiOrDefault(
        _dashboardSensorKey, _dashboardRiverData);
    const min = 0.0;
    final max = thr.gaugeMax;
    final clamped = currentLevel.clamp(min, max);
    final ratio = (clamped - min) / (max - min);

    final alertPos = (thr.alert - min) / (max - min);
    final alarmPos = (thr.alarm - min) / (max - min);
    final critPos = (thr.critical - min) / (max - min);

    String fmt(double m) =>
        '${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 2)}m';

    Color barColor;
    final status = thr.statusFor(currentLevel);
    switch (status) {
      case ColorStatus.critical:
        barColor = const Color(0xFFD32F2F);
        break;
      case ColorStatus.warning:
        barColor = const Color(0xFFFF9800);
        break;
      case ColorStatus.alert:
        barColor = const Color(0xFFFBC02D);
        break;
      case ColorStatus.safe:
        barColor = const Color(0xFF4CAF50);
        break;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_dashboardSensorDisplayName thresholds (EL.m)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _isDarkMode ? Colors.white70 : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _dashThrChip('Current', currentLevel.toStringAsFixed(2), barColor),
                  const SizedBox(width: 8),
                  _dashThrChip('Alert', thr.alert.toStringAsFixed(2),
                      const Color(0xFFFBC02D)),
                  const SizedBox(width: 8),
                  _dashThrChip('Alarm', thr.alarm.toStringAsFixed(2),
                      const Color(0xFFFF9800)),
                  const SizedBox(width: 8),
                  _dashThrChip('Critical', thr.critical.toStringAsFixed(2),
                      const Color(0xFFD32F2F)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 28,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 14,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    left: 0,
                    child: Container(
                      height: 14,
                      width: (w * ratio).clamp(0.0, w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        color: barColor,
                      ),
                    ),
                  ),
                  Positioned(
                      left: (w * alertPos - 1.5).clamp(0.0, w - 3),
                      top: 4,
                      child: Container(
                          width: 3,
                          height: 20,
                          decoration: BoxDecoration(
                              color: const Color(0xFFFBC02D),
                              borderRadius: BorderRadius.circular(1.5)))),
                  Positioned(
                      left: (w * alarmPos - 1.5).clamp(0.0, w - 3),
                      top: 4,
                      child: Container(
                          width: 3,
                          height: 20,
                          decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(1.5)))),
                  Positioned(
                      left: (w * critPos - 1.5).clamp(0.0, w - 3),
                      top: 4,
                      child: Container(
                          width: 3,
                          height: 20,
                          decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(1.5)))),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(fmt(min),
                style: TextStyle(
                    fontSize: 10,
                    color: _isDarkMode ? Colors.white38 : Colors.grey[500])),
            Text(fmt(max),
                style: TextStyle(
                    fontSize: 10,
                    color: _isDarkMode ? Colors.white38 : Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _dashThrChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? Colors.white54 : Colors.grey[600])),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTimeline(Color textColor, Color? subColor) {
    final timeline = _dashboardTimeline;
    if (timeline == null || timeline.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF253B50) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            _isTaglish
                ? 'Walang datos ng timeline'
                : 'No timeline data available',
            style: TextStyle(color: subColor, fontSize: 14),
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: timeline.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = timeline[index] as Map<String, dynamic>;
          final time = entry['time']?.toString() ?? '';
          final level = (entry[_dashboardSensorKey] ?? 0.0).toDouble();
          final color = _dashboardAlarmColor(level);
          final statusText = _dashboardAlarmShortLabel(level);

          String shortTime = time;
          final parts = time.split(', ');
          if (parts.length >= 2) shortTime = parts.last;
          if (shortTime.contains(':')) {
            final tParts = shortTime.split(':');
            shortTime = '${tParts[0]} ${shortTime.split(' ').last}';
          }

          return Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: _isDarkMode ? color.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  shortTime.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: level.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      TextSpan(
                        text: 'm',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

/*************  ✨ Windsurf Command ⭐  *************/
  /// Builds a button to report a flood. The button is
  /// displayed in the navigation bar and has a gradient
  /// background with a white text and a warning icon.
  /// When tapped, it shows a [ReportFloodSheet].
  ///
/// *****  2c13d96e-27e7-42ae-b43d-754886f52360  ****** Widget
      _buildReportButton() {
    return Expanded(
      flex: 3,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showReportFloodSheet,
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withValues(alpha: 0.3),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        t("askForHelp"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                      ),
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
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
