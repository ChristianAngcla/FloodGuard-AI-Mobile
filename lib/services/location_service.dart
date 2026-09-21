import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const List<String> marikinaBarangays = [
    'Barangka',
    'Calumpang',
    'Concepcion Dos',
    'Concepcion Uno',
    'Fortune',
    'Industrial Valley (IVC)',
    'Jesus Dela Peña',
    'Malanday',
    'Marikina Heights',
    'Nangka',
    'Parang',
    'San Roque',
    'Santa Elena',
    'Santo Niño',
    'Tañong',
    'Tumana',
  ];

  /// Canonicalizes any legacy or ASCII spelling into the official 16 Marikina barangay names.
  static String canonicalizeBarangay(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    const aliases = {
      'jesus de la pena': 'Jesus Dela Peña',
      'jesus dela pena': 'Jesus Dela Peña',
      'jesus de la peña': 'Jesus Dela Peña',
      'jesus dela peña': 'Jesus Dela Peña',
      'santo nino': 'Santo Niño',
      'sto nino': 'Santo Niño',
      'sto. nino': 'Santo Niño',
      'sto. niño': 'Santo Niño',
      'tanong': 'Tañong',
      'concepcion 1': 'Concepcion Uno',
      'concepcion 2': 'Concepcion Dos',
      'sta. elena': 'Santa Elena',
      'sta elena': 'Santa Elena',
      'ivc': 'Industrial Valley (IVC)',
      'industrial valley': 'Industrial Valley (IVC)',
      'industrial valley complex': 'Industrial Valley (IVC)',
      'industrial valley (ivc)': 'Industrial Valley (IVC)',
    };

    final lower = trimmed.toLowerCase();
    if (aliases.containsKey(lower)) {
      return aliases[lower]!;
    }

    for (final b in marikinaBarangays) {
      if (b.toLowerCase() == lower) {
        return b;
      }
    }

    return trimmed;
  }

  /// Returns true if the name matches one of the 16 canonical Marikina barangays.
  static bool isCanonicalMarikinaBarangay(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final canonical = canonicalizeBarangay(name);
    return marikinaBarangays.contains(canonical);
  }

  static Future<bool> handlePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  /// Ray-casting point-in-polygon test.
  /// [polygon] is a list of [lng, lat] coordinate pairs.
  static bool isPointInPolygon(
      double lat, double lng, List<List<double>> polygon) {
    bool isInside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final piLat = polygon[i][1];
      final piLng = polygon[i][0];
      final pjLat = polygon[j][1];
      final pjLng = polygon[j][0];

      if ((piLat > lat) != (pjLat > lat)) {
        if (lng <
            (pjLng - piLng) * (lat - piLat) / (pjLat - piLat) + piLng) {
          isInside = !isInside;
        }
      }
      j = i;
    }
    return isInside;
  }

  static Map<String, List<List<List<double>>>>? _cachedBarangayBoundaries;

  static bool get hasCachedBoundaries =>
      _cachedBarangayBoundaries != null && _cachedBarangayBoundaries!.isNotEmpty;

  /// Loads GeoJSON boundary rings from assets, cached in memory.
  static Future<Map<String, List<List<List<double>>>>> loadBarangayBoundaries({
    String assetPath = 'assets/marikina1.geojson',
  }) async {
    if (_cachedBarangayBoundaries != null) {
      return _cachedBarangayBoundaries!;
    }

    try {
      final data = await rootBundle.loadString(assetPath);
      final json = jsonDecode(data) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>;

      final map = <String, List<List<List<double>>>>{};
      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>? ?? {};
        final rawName = props['NAME_3'] ??
            props['name'] ??
            props['NAME'] ??
            props['barangay'] ??
            '';
        final canonicalName = canonicalizeBarangay(rawName.toString());
        if (canonicalName.isEmpty) continue;

        final geom = feature['geometry'] as Map<String, dynamic>? ?? {};
        final type = geom['type']?.toString();
        final rawCoords = geom['coordinates'] as List<dynamic>? ?? [];

        final polygonRings = <List<List<double>>>[];
        if (type == 'Polygon' && rawCoords.isNotEmpty) {
          for (final ring in rawCoords) {
            final points = <List<double>>[];
            for (final pt in ring) {
              if (pt is List && pt.length >= 2) {
                points.add([
                  (pt[0] as num).toDouble(),
                  (pt[1] as num).toDouble(),
                ]);
              }
            }
            if (points.isNotEmpty) polygonRings.add(points);
          }
        } else if (type == 'MultiPolygon' && rawCoords.isNotEmpty) {
          for (final poly in rawCoords) {
            for (final ring in poly) {
              final points = <List<double>>[];
              for (final pt in ring) {
                if (pt is List && pt.length >= 2) {
                  points.add([
                    (pt[0] as num).toDouble(),
                    (pt[1] as num).toDouble(),
                  ]);
                }
              }
              if (points.isNotEmpty) polygonRings.add(points);
            }
          }
        }

        if (polygonRings.isNotEmpty) {
          map[canonicalName] = polygonRings;
        }
      }

      _cachedBarangayBoundaries = map;
      return map;
    } catch (e) {
      debugPrint('[LocationService] Error loading GeoJSON boundaries: $e');
      return {};
    }
  }

  @visibleForTesting
  static void setMockBarangayBoundaries(
      Map<String, List<List<List<double>>>>? boundaries) {
    _cachedBarangayBoundaries = boundaries;
  }

  /// Resolves latitude and longitude coordinates to one of the 16 Marikina barangays.
  /// Returns null if the coordinates are outside Marikina or cannot be mapped.
  static Future<String?> resolveBarangayFromCoordinates(
      double latitude, double longitude) async {
    final boundaries = await loadBarangayBoundaries();
    if (boundaries.isNotEmpty) {
      for (final entry in boundaries.entries) {
        final name = entry.key;
        for (final ring in entry.value) {
          if (isPointInPolygon(latitude, longitude, ring)) {
            return name;
          }
        }
      }
      return null;
    }

    // Fallback if GeoJSON asset is unavailable (e.g. test environment)
    if (latitude >= 14.610 &&
        latitude <= 14.685 &&
        longitude >= 121.075 &&
        longitude <= 121.145) {
      return 'Marikina';
    }
    return null;
  }

  /// Safe, non-throwing single position fetch.
  static Future<Position?> getCurrentPositionSafe({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: timeout,
      );
    } catch (e) {
      debugPrint('[LocationService] getCurrentPositionSafe failed: $e');
      return null;
    }
  }

  /// Resolves the device's current location to a Marikina barangay.
  /// Returns null if GPS is unavailable, disabled, denied, timed out, or outside Marikina.
  static Future<String?> resolveCurrentLocationBarangay({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final pos = await getCurrentPositionSafe(timeout: timeout);
    if (pos == null) return null;
    return await resolveBarangayFromCoordinates(pos.latitude, pos.longitude);
  }
}

class HelpRequestCoordinates {
  final double latitude;
  final double longitude;

  const HelpRequestCoordinates({
    required this.latitude,
    required this.longitude,
  });

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}

enum HelpRequestLocationFailure {
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
  outsideMarikina,
}

class HelpRequestLocationOutcome {
  final HelpRequestCoordinates? coordinates;
  final HelpRequestLocationFailure? failure;

  const HelpRequestLocationOutcome._({this.coordinates, this.failure});

  factory HelpRequestLocationOutcome.granted(
          HelpRequestCoordinates coordinates) =>
      HelpRequestLocationOutcome._(coordinates: coordinates);

  factory HelpRequestLocationOutcome.failed(
          HelpRequestLocationFailure failure) =>
      HelpRequestLocationOutcome._(failure: failure);

  bool get canSubmit =>
      coordinates != null && coordinates!.isValid && failure == null;

  bool get needsOpenSettings =>
      failure == HelpRequestLocationFailure.deniedForever;
}

const kHelpRequestLocationRequiredEn =
    'To send a Help Request, please turn on your location so FloodGuard can confirm that you are within Marikina City.';
const kHelpRequestLocationRequiredTl =
    'Para makapagpadala ng Saklolo, mangyaring buksan ang iyong lokasyon upang makumpirma ng FloodGuard na ikaw ay nasa loob ng Lungsod ng Marikina.';
const kHelpRequestOutsideMarikinaEn =
    'FloodGuard Help Request is only available to users currently within Marikina City. We cannot process this request because your current location is outside the service area.';
const kHelpRequestOutsideMarikinaTl =
    'Ang FloodGuard Help Request ay para lamang sa mga user na kasalukuyang nasa loob ng Lungsod ng Marikina. Hindi namin maproseso ang kahilingang ito dahil ang iyong lokasyon ay nasa labas ng service area.';
const kHelpRequestLocationUnavailableEn =
    'Could not get your current location. Please try again.';
const kHelpRequestLocationUnavailableTl =
    'Hindi makuha ang iyong kasalukuyang lokasyon. Subukan muli.';
const kHelpRequestLocationServicesOffEn =
    'Location services are turned off. Turn on GPS to send a help request.';
const kHelpRequestLocationServicesOffTl =
    'Naka-off ang location services. Buksan ang GPS para makapagpadala ng help request.';

String helpRequestLocationMessage({
  required HelpRequestLocationFailure failure,
  required bool isTaglish,
}) {
  switch (failure) {
    case HelpRequestLocationFailure.outsideMarikina:
      return isTaglish
          ? kHelpRequestOutsideMarikinaTl
          : kHelpRequestOutsideMarikinaEn;
    case HelpRequestLocationFailure.denied:
    case HelpRequestLocationFailure.deniedForever:
      return isTaglish
          ? kHelpRequestLocationRequiredTl
          : kHelpRequestLocationRequiredEn;
    case HelpRequestLocationFailure.serviceDisabled:
      return isTaglish
          ? kHelpRequestLocationServicesOffTl
          : kHelpRequestLocationServicesOffEn;
    case HelpRequestLocationFailure.unavailable:
      return isTaglish
          ? kHelpRequestLocationUnavailableTl
          : kHelpRequestLocationUnavailableEn;
  }
}

/// Resolves GPS permission + coordinates before a Help Request may be sent.
class HelpRequestLocationResolver {
  final Future<bool> Function() isLocationServiceEnabled;
  final Future<LocationPermission> Function() checkPermission;
  final Future<LocationPermission> Function() requestPermission;
  final Future<HelpRequestCoordinates> Function() getCurrentCoordinates;
  final Future<bool> Function() openAppSettings;
  final Future<bool> Function(double lat, double lng)? isInsideMarikina;

  const HelpRequestLocationResolver({
    required this.isLocationServiceEnabled,
    required this.checkPermission,
    required this.requestPermission,
    required this.getCurrentCoordinates,
    required this.openAppSettings,
    this.isInsideMarikina,
  });

  factory HelpRequestLocationResolver.geolocator() {
    return HelpRequestLocationResolver(
      isLocationServiceEnabled: Geolocator.isLocationServiceEnabled,
      checkPermission: Geolocator.checkPermission,
      requestPermission: Geolocator.requestPermission,
      openAppSettings: Geolocator.openAppSettings,
      getCurrentCoordinates: () async {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        return HelpRequestCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      },
    );
  }

  Future<HelpRequestLocationOutcome> resolveForSubmit() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return HelpRequestLocationOutcome.failed(
        HelpRequestLocationFailure.serviceDisabled,
      );
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return HelpRequestLocationOutcome.failed(
        HelpRequestLocationFailure.deniedForever,
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return HelpRequestLocationOutcome.failed(
        HelpRequestLocationFailure.denied,
      );
    }

    try {
      final coords = await getCurrentCoordinates();
      if (!coords.isValid) {
        return HelpRequestLocationOutcome.failed(
          HelpRequestLocationFailure.unavailable,
        );
      }

      final checkBoundary = isInsideMarikina ??
          ((lat, lng) async {
            if (LocationService.hasCachedBoundaries) {
              final b =
                  await LocationService.resolveBarangayFromCoordinates(lat, lng);
              return b != null;
            }
            return lat >= 14.610 &&
                lat <= 14.685 &&
                lng >= 121.075 &&
                lng <= 121.145;
          });
      final inside = await checkBoundary(coords.latitude, coords.longitude);
      if (!inside) {
        return HelpRequestLocationOutcome.failed(
          HelpRequestLocationFailure.outsideMarikina,
        );
      }

      return HelpRequestLocationOutcome.granted(coords);
    } catch (_) {
      return HelpRequestLocationOutcome.failed(
        HelpRequestLocationFailure.unavailable,
      );
    }
  }
}
