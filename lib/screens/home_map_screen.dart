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
import '../screens/barangay_details_sheet.dart';
import '../services/flood_api_service.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/station_thresholds.dart';
import 'alerts_screen.dart';
import 'help_requests_screen.dart';
import '../widgets/wave_background.dart';
import '../config/api_config.dart';

class HomeMapScreen extends StatefulWidget {
  final bool initialDarkMode;
  final bool initialTaglish;

  // Static cache of Marikina barangay centers calculated from GeoJSON, so other widgets can
  // query coordinates without reloading and reparsing the GeoJSON.
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Color _accessibleBlue = Color(0xFF1769AA);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  late bool _isDarkMode;
  double _currentZoom = 13.0;
  List<Barangay> marikinaBarangays = [];
  List<Polygon> _cachedStaticPolygons = [];
  Map<String, LatLng> _barangayCenters = {};
  String? _hoveredBarangayName;
  String? _selectedBarangayName;
  int _currentBarangayIndex = 0;
  bool _hasShownEarlyWarning = false;
  bool _isInitialLoading = true;
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

  /// Visual-only offsets for labels whose geographic centres sit at the map
  /// edge. The polygon, flood value, tap target, and camera position stay at
  /// the original barangay centre.
  LatLng _labelPointFor(String name, LatLng center) {
    switch (name) {
      case 'Barangka':
        // Restore the label to the centre of Barangka's actual polygon.
        // (The source centre has an older crowding adjustment applied.)
        return LatLng(center.latitude + 0.0045, center.longitude + 0.0010);
      case 'Industrial Valley':
        return center;
      case 'Fortune':
        return center;
      case 'Marikina Heights':
        return LatLng(center.latitude, center.longitude - 0.0040);
      default:
        return center;
    }
  }

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Cached GeoJSON features — avoid re-parsing asset on every refresh.
  static List<dynamic>? _cachedGeoFeatures;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isDarkMode = widget.initialDarkMode;
    _isTaglish = widget.initialTaglish;

    // 🌊 Breathing animation for map polygons (rebuild scoped via AnimatedBuilder)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation =
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine);

    _startAutoRefreshTimer();
    _performInitialLoad();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (mounted && _currentTabIndex == 1 && !_isLoading) {
        _refreshData(silent: true);
      }
    });
  }

  void _pauseBackgroundWork() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
    if (_pulseController.isAnimating) _pulseController.stop();
  }

  void _resumeBackgroundWork() {
    _startAutoRefreshTimer();
    _startLocationTracking();
    if (_currentTabIndex == 1 && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseBackgroundWork();
    } else if (state == AppLifecycleState.resumed) {
      _resumeBackgroundWork();
    }
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

    final start = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
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
    final start = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
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
      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter:
              15, // updates every 15 meters for optimal battery/CPU efficiency
        ),
      ).listen((Position position) {
        if (!mounted) return;
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

  List<Polygon> _buildDynamicPolygons() {
    final double pulse = _pulseAnimation.value;
    final themeBorderColor = _isDarkMode ? Colors.white : Colors.black;
    final double baseStroke = _currentZoom < 14.0 ? 2.0 : 3.0;

    return marikinaBarangays.map((b) {
      final isHovered = b.name == _hoveredBarangayName;
      final isSelected = b.name == _selectedBarangayName;

      if (isSelected || isHovered) {
        final double strokeWidth = baseStroke + 2.0 + (pulse * 2.0);
        final borderColor = themeBorderColor.withValues(
          alpha: (_isDarkMode ? 0.8 : 0.7) + (pulse * 0.2),
        );
        final fillColor = b.polygon.color.withValues(alpha: 0.6);

        return Polygon(
          points: b.polygon.points,
          color: fillColor,
          borderColor: borderColor,
          borderStrokeWidth: strokeWidth,
          isFilled: true,
        );
      } else {
        return Polygon(
          points: b.polygon.points,
          color: b.polygon.color.withValues(alpha: 0.35),
          borderColor:
              themeBorderColor.withValues(alpha: _isDarkMode ? 0.6 : 0.4),
          borderStrokeWidth: baseStroke,
          isFilled: true,
        );
      }
    }).toList();
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
      // Step 1: Load barangay boundaries from GeoJSON (cached after first parse)
      late final List<dynamic> features;
      if (_cachedGeoFeatures != null) {
        features = _cachedGeoFeatures!;
      } else {
        final data = await rootBundle.loadString(
          'assets/marikina1.geojson',
        );
        final json = jsonDecode(data);
        features = json['features'] as List<dynamic>;
        _cachedGeoFeatures = features;
      }

      final List<Barangay> loaded = [];
      final Map<String, LatLng> centers = {};

      // Step 2: Fetch REAL data from FloodGuard /api/status and /api/forecasts/daily
      Map<String, FloodData> apiData = {};
      try {
        final results = await Future.wait([
          FloodApiService.getAllBarangayFloodData(forceRefresh: forceRefresh),
          FloodApiService.fetchDailyForecasts(forceRefresh: forceRefresh),
        ]);
        apiData = results[0] as Map<String, FloodData>;
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

        final sensorKey = FloodApiService.barangayToSensor[name] ?? 'sto_nino';
        ColorStatus? colorStatus =
            FloodApiService.operationalMapStatusForBarangay(name);

        Color baseColor;
        switch (colorStatus) {
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
          case null:
            baseColor = const Color(0xFF64748B);
            break;
        }

        debugPrint("🌊 $name: mapStatus=$colorStatus ($sensorKey)");

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

      final themeBorderColor = _isDarkMode ? Colors.white : Colors.black;
      final double baseStroke = _currentZoom < 14.0 ? 2.0 : 3.0;
      final staticList = loaded.map((b) {
        return Polygon(
          points: b.polygon.points,
          color: b.polygon.color.withValues(alpha: 0.35),
          borderColor:
              themeBorderColor.withValues(alpha: _isDarkMode ? 0.6 : 0.4),
          borderStrokeWidth: baseStroke,
          isFilled: true,
        );
      }).toList();

      setState(() {
        marikinaBarangays = loaded;
        _cachedStaticPolygons = staticList;
        _barangayCenters = centers;
        HomeMapScreen.barangayCenters.clear();
        HomeMapScreen.barangayCenters.addAll(centers);
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
    final daily = FloodApiService.getDailyForecastForBarangay(userBarangay);
    final warnStatus =
        FloodApiService.operationalMapStatusForBarangay(userBarangay);
    if (warnStatus == null || warnStatus == ColorStatus.safe) return;

    final level = daily?.predictedWaterLevel;
    if (level == null || !level.isFinite) return;

    final riverRaw = FloodApiService.getFullPredictionData()?['prediction']
        ?['rivers']?[sensorKey];
    Map<String, dynamic>? riverMap;
    if (riverRaw is Map<String, dynamic>) {
      riverMap = riverRaw;
    } else if (riverRaw is Map) {
      riverMap = Map<String, dynamic>.from(riverRaw);
    }
    final thr = StationThresholds.fromApiOrDefault(sensorKey, riverMap);

    _hasShownEarlyWarning = true;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _showEarlyWarningDialog(warnStatus.label, level, userBarangay, thr);
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
                  ? 'Pagtataya ng FloodGuard ($statusLabel): ${level.toStringAsFixed(2)} m para sa $location.\n'
                      'Alert ${thr.alert.toStringAsFixed(2)} · Alarm ${thr.alarm.toStringAsFixed(2)} · Critical ${thr.critical.toStringAsFixed(2)} m.\n'
                      'Ito ay pagtataya para sa susunod na araw, hindi kasalukuyang reading ng PAGASA. Sundin ang opisyal na babala ng PAGASA/MDRRMO.'
                  : 'FloodGuard forecast ($statusLabel): ${level.toStringAsFixed(2)} m for $location.\n'
                      'Alert ${thr.alert.toStringAsFixed(2)} · Alarm ${thr.alarm.toStringAsFixed(2)} · Critical ${thr.critical.toStringAsFixed(2)} m.\n'
                      'This is a next-day FloodGuard forecast, not a current PAGASA reading. Follow official PAGASA/MDRRMO advisories.',
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
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2)),
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

  String t(String key) {
    return Translations.texts[key]?[_isTaglish ? "tl" : "en"] ?? key;
  }

  static const String _cartoKey = ApiConfig.cartoBasemapKey;

  final String _lightMapUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=$_cartoKey';

  final String _darkMapUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png?key=$_cartoKey';

  List<City> cities = [];
  int currentCityIndex = 0; // start with the first city
  List<Polygon> polygons = [];
  LatLng? _highlightedLocation;
  String? _highlightedPlaceName;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _pulseController.dispose();
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
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: BarangayDetailsSheet(
            barangayName: barangayName,
            isTaglish: _isTaglish,
            isDarkMode: _isDarkMode,
          ),
        );
      },
    );

    if (mounted) {
      setState(() {
        _selectedBarangayName = null;
      });
      if (_pulseController.isAnimating) _pulseController.stop();
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
      tooltip: _isTaglish ? 'Buksan ang settings' : 'Open settings',
      icon: Icon(Icons.settings_rounded,
          color: _isDarkMode ? Colors.white : _accessibleBlue),
      onPressed: () {
        _scaffoldKey.currentState?.openEndDrawer();
      },
    );
  }

  Widget _buildRefreshButton() {
    return Semantics(
      label: _isTaglish ? 'Bersyon 1.0.0' : 'Version 1.0.0',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
          const SizedBox(width: 4),
          Text(
            _isTaglish ? 'Bersyon 1.0.0' : 'Version 1.0.0',
            style: TextStyle(
              fontSize: 11,
              color: _isDarkMode ? Colors.white : Colors.black,
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
    final systemTopInset = MediaQuery.of(context).padding.top;
    final statusBarColor =
        _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        // A dedicated status-bar colour gives every Home state a clear phone
        // boundary instead of letting its screen background run behind it.
        statusBarColor: statusBarColor,
        statusBarIconBrightness:
            _isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkMode
          ? const Color(0xFF1A2B3C) // dark background
          : const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // 1. Main Content (Map, Home, or My Requests)
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
                        ? HelpRequestsScreen(
                            isTaglish: _isTaglish,
                            isDarkMode: _isDarkMode,
                            embeddedInNavigation: true,
                          )
                        : SafeArea(
                            top: true,
                            bottom: false,
                            left: false,
                            right: false,
                            child: MouseRegion(
                              key: const ValueKey('map_view'),
                              onHover: (event) =>
                                  _handleMapHover(event.localPosition),
                              child: Semantics(
                                container: true,
                                label:
                                    _isTaglish ? 'Mapa ng baha' : 'Flood map',
                                child: FlutterMap(
                                  key: ValueKey('flood_map_$_isDarkMode'),
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: const LatLng(
                                        14.6503, 121.1020), // Marikina center
                                    initialZoom: 13,
                                    minZoom: 12,
                                    maxZoom: 18,
                                    backgroundColor: _isDarkMode
                                        ? const Color(0xFF141E28)
                                        : const Color(0xFFE5EDF5),
                                    onPositionChanged: (position, hasGesture) {
                                      if (position.zoom != null) {
                                        setState(() =>
                                            _currentZoom = position.zoom!);
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
                                          _selectedBarangayName =
                                              tappedBarangay;
                                          if (tappedBarangay != null) {
                                            final index = marikinaBarangays
                                                .indexWhere((b) =>
                                                    b.name == tappedBarangay);
                                            if (index != -1) {
                                              _currentBarangayIndex = index;
                                            }
                                          }
                                        });
                                        if (tappedBarangay != null) {
                                          debugPrint(
                                              "Selected: $tappedBarangay");
                                          _showBarangayDetails(tappedBarangay);
                                        }
                                      }
                                    },
                                  ),
                                  children: [
                                    TileLayer(
                                      key: ValueKey('tile_layer_$_isDarkMode'),
                                      urlTemplate: _isDarkMode
                                          ? _darkMapUrl
                                          : _lightMapUrl,
                                      fallbackUrl: _isDarkMode
                                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png?key=$_cartoKey'
                                          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=$_cartoKey',
                                      subdomains: const ['a', 'b', 'c', 'd'],
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
                                            child: Semantics(
                                              label: _isTaglish
                                                  ? 'Marker ng kasalukuyang lokasyon'
                                                  : 'Current location marker',
                                              child: const PulsingLocationDot(),
                                            ),
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
                                            borderColor:
                                                const Color(0xFF2BA7A0),
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
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF4F8BBF),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Colors.black26,
                                                        blurRadius: 6,
                                                      )
                                                    ],
                                                  ),
                                                  child: Semantics(
                                                    label: _isTaglish
                                                        ? 'Napiling lokasyon: $_highlightedPlaceName'
                                                        : 'Selected location: $_highlightedPlaceName',
                                                    child: ExcludeSemantics(
                                                      child: Text(
                                                        _highlightedPlaceName!,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
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
                                      (_selectedBarangayName != null ||
                                              _hoveredBarangayName != null)
                                          ? AnimatedBuilder(
                                              animation: _pulseAnimation,
                                              builder: (context, _) =>
                                                  PolygonLayer(
                                                polygons:
                                                    _buildDynamicPolygons(),
                                              ),
                                            )
                                          : PolygonLayer(
                                              polygons: _cachedStaticPolygons
                                                      .isNotEmpty
                                                  ? _cachedStaticPolygons
                                                  : _buildDynamicPolygons(),
                                            ),
                                    if (marikinaBarangays.isNotEmpty)
                                      MarkerLayer(
                                        markers: _barangayCenters.entries
                                            .map((entry) {
                                          final name = entry.key;
                                          final center = entry.value;
                                          final labelPoint =
                                              _labelPointFor(name, center);
                                          final ColorStatus? status =
                                              FloodApiService
                                                  .operationalMapStatusForBarangay(
                                                      name);
                                          late Color riskColor;
                                          late String statusText;
                                          late Color textColor;
                                          late IconData statusIcon;
                                          if (status == null) {
                                            riskColor = const Color(0xFF64748B);
                                            statusText = _isTaglish
                                                ? 'Hindi available'
                                                : 'Unavailable';
                                            textColor = Colors.white;
                                            statusIcon = Icons.help_outline;
                                          } else {
                                            switch (status) {
                                              case ColorStatus.safe:
                                                riskColor =
                                                    const Color(0xFF4CAF50);
                                                statusText = _isTaglish
                                                    ? "Ligtas"
                                                    : "Safe";
                                                textColor = Colors.white;
                                                statusIcon =
                                                    Icons.check_circle_rounded;
                                                break;
                                              case ColorStatus.alert:
                                                riskColor =
                                                    const Color(0xFFFBC02D);
                                                statusText = _isTaglish
                                                    ? "Alerto"
                                                    : "Alert";
                                                textColor = Colors.black87;
                                                statusIcon =
                                                    Icons.warning_amber_rounded;
                                                break;
                                              case ColorStatus.warning:
                                                riskColor =
                                                    const Color(0xFFFF9800);
                                                statusText = _isTaglish
                                                    ? "Babala"
                                                    : "Warning";
                                                textColor = Colors.black87;
                                                statusIcon =
                                                    Icons.warning_rounded;
                                                break;
                                              case ColorStatus.critical:
                                                riskColor =
                                                    const Color(0xFFD32F2F);
                                                statusText = _isTaglish
                                                    ? "Lumikas"
                                                    : "Critical";
                                                textColor = Colors.white;
                                                statusIcon =
                                                    Icons.dangerous_rounded;
                                                break;
                                            }
                                          }

                                          // Dynamic Layout: Switch to compact single-pill mode when zoomed out
                                          // to drastically reduce overcrowding while keeping info visible.
                                          final bool isZoomedOut =
                                              _currentZoom < 14.2;

                                          return Marker(
                                            point: labelPoint,
                                            width: isZoomedOut ? 160.0 : 200.0,
                                            height: isZoomedOut ? 60.0 : 110.0,
                                            child: Semantics(
                                              container: true,
                                              label: '$name: $statusText',
                                              child: isZoomedOut
                                                  ? Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        // Compact Pill: [Icon] Name Risk%
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: riskColor,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .white,
                                                                width: 2),
                                                            boxShadow: const [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black26,
                                                                blurRadius: 4,
                                                                offset: Offset(
                                                                    0, 2),
                                                              )
                                                            ],
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(statusIcon,
                                                                  size: 16,
                                                                  color:
                                                                      textColor),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Flexible(
                                                                child: Text(
                                                                  name,
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        textColor,
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        // Small pointer
                                                        ClipPath(
                                                          clipper:
                                                              _TriangleClipper(),
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
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        // 1. Barangay Name Label (Top)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _isDarkMode
                                                                ? Colors.black87
                                                                : Colors.white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.95),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .black12,
                                                                width: 1),
                                                          ),
                                                          child: Text(
                                                            name,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              color: _isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black87,
                                                              fontSize: 13.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        // 2. Risk Pill (Bottom)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: riskColor,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .white,
                                                                width: 2),
                                                            boxShadow: const [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black26,
                                                                blurRadius: 4,
                                                                offset: Offset(
                                                                    0, 2),
                                                              )
                                                            ],
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(statusIcon,
                                                                  size: 16.0,
                                                                  color:
                                                                      textColor),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                statusText,
                                                                style:
                                                                    TextStyle(
                                                                  color:
                                                                      textColor,
                                                                  fontSize:
                                                                      13.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        // Triangle pointer
                                                        ClipPath(
                                                          clipper:
                                                              _TriangleClipper(),
                                                          child: Container(
                                                            width: 14,
                                                            height: 9,
                                                            color: riskColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
          ),

          // Keep non-map screens visually below the phone status bar.
          if (_currentTabIndex != 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: systemTopInset,
              child: ColoredBox(
                color: statusBarColor,
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
                minimum: const EdgeInsets.only(top: 12),
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
                      child: Row(
                        children: [
                          // Left: Brand
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/new_logo_nobg.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "FloodGuard",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF3784DF),
                              letterSpacing: -0.5,
                            ),
                          ),
                          // Middle: last updated
                          Expanded(
                            child: Center(
                              child: _buildRefreshButton(),
                            ),
                          ),
                          _buildMenuButton(),
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
              bottom: MediaQuery.of(context).padding.bottom,
              left: 12,
              right: 12,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
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
                            icon: Icons.support_agent_rounded,
                            label: t("myRequests"),
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
              bottom: MediaQuery.of(context).padding.bottom + 88,
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
              bottom: MediaQuery.of(context).padding.bottom + 88,
              right: 16,
              child: Semantics(
                button: true,
                label: _isTaglish
                    ? 'I-center sa kasalukuyang lokasyon'
                    : 'Center on current location',
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
                                      alpha:
                                          0.2 + (_pulseController.value * 0.3)),
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
    final navColor = _isDarkMode ? Colors.white : const Color(0xFF1A1A1A);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: label,
          child: InkWell(
            onTap: () {
              if (isAction) {
              } else {
                setState(() => _currentTabIndex = index);
                if (index == 1) {
                  if ((_selectedBarangayName != null ||
                          _hoveredBarangayName != null) &&
                      !_pulseController.isAnimating) {
                    _pulseController.repeat(reverse: true);
                  }
                } else if (_pulseController.isAnimating) {
                  _pulseController.stop();
                }
              }
            },
            borderRadius: BorderRadius.circular(34),
            highlightColor: navColor.withValues(alpha: 0.1),
            splashColor: navColor.withValues(alpha: 0.2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? navColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: navColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: navColor,
                    ),
                  ),
                ),
              ],
            ),
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
                    color:
                        _isDarkMode ? Colors.white : const Color(0xFF1A1A1A)),
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

    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = _isDarkMode ? Colors.white : Colors.black;

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
                                color:
                                    _isDarkMode ? Colors.white : Colors.black),
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
                              color: _isDarkMode ? Colors.white : Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Flood Risk Assessment Title ──
                  Text(
                    _isTaglish
                        ? 'Pagsusuri ng Panganib'
                        : 'Flood Risk Assessment',
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
                    children: [
                      Expanded(
                        flex: 6,
                        child: Text(
                          _isTaglish
                              ? 'Pagtataya para sa $_dashboardSelectedBarangay'
                              : 'Forecast for $_dashboardSelectedBarangay',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Sensor: $_dashboardSensorDisplayName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: subColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Daily forecast card ──
                  _buildDashboardTelemetryAndForecastCard(textColor, subColor),
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
                                  color: const Color(0xFF3784DF)
                                      .withValues(alpha: 0.3),
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
                                              ? Colors.white
                                              : const Color(0xFF1A1A1A))),
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

  Widget _buildDashboardTelemetryAndForecastCard(
      Color textColor, Color subColor) {
    final selectedBarangay =
        _dashboardSelectedBarangay ?? _userProfile?.barangay ?? 'Santo Niño';
    final daily = FloodApiService.getDailyForecastForBarangay(selectedBarangay);
    final cardColor =
        _isDarkMode ? const Color(0xFF253B50) : const Color(0xFFF8FAFC);

    // DEFECT G: only claim "next calendar day" when the dates actually say so.
    final nextDayVerified = daily?.nextCalendarDayVerified ?? false;
    final forecastHeading = nextDayVerified
        ? (_isTaglish
            ? 'PAGTATAYA SA SUSUNOD NA ARAW'
            : 'NEXT-CALENDAR-DAY FORECAST')
        : (_isTaglish ? 'PANG-ARAW NA PAGTATAYA' : 'DAILY FORECAST');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          forecastHeading,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: subColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDarkMode ? cardColor : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isDarkMode ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child:
              _buildDashboardDailyForecastContent(daily, textColor, subColor),
        ),
      ],
    );
  }

  Widget _buildDashboardDailyForecastContent(
      DailyForecastItem? daily, Color textColor, Color subColor) {
    if (daily == null ||
        daily.isUnavailable ||
        daily.predictedWaterLevel == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isTaglish
                ? 'Hindi available ang pagtataya'
                : 'Forecast unavailable',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          if (daily?.fallbackReason != null &&
              daily!.fallbackReason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              daily.fallbackReason!,
              style: TextStyle(
                fontSize: 12,
                color: subColor,
                height: 1.3,
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${daily.predictedWaterLevel!.toStringAsFixed(2)} m',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0369A1),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${daily.statusBand} · ${daily.modeDisplayLabel}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0369A1),
          ),
        ),
        if (daily.forecastTargetDate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _isTaglish
                  ? 'Para sa: ${daily.forecastTargetDate}'
                  : 'For: ${daily.forecastTargetDate}',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
          ),
        if (daily.sourceDataDate != null && daily.sourceDataDate!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _isTaglish
                  ? 'Batay sa datos ng: ${daily.sourceDataDate}'
                  : 'Based on observations from: ${daily.sourceDataDate}',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
          ),
      ],
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

  Widget _buildReportButton() {
    return Expanded(
      flex: 2,
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Semantics(
          button: true,
          label: _isTaglish
              ? 'Humingi ng tulong at mag-report ng baha'
              : 'Ask for help and report flooding',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showReportFloodSheet,
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withValues(alpha: 0.3),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t("askForHelp"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
