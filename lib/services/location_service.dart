import 'package:geolocator/geolocator.dart';

class LocationService {
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
    'Location access is required to send a help request so responders can locate you.';
const kHelpRequestLocationRequiredTl =
    'Kailangan ng access sa lokasyon para makapagpadala ng help request upang mahanap ka ng mga tagapagligtas.';
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

  const HelpRequestLocationResolver({
    required this.isLocationServiceEnabled,
    required this.checkPermission,
    required this.requestPermission,
    required this.getCurrentCoordinates,
    required this.openAppSettings,
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
      return HelpRequestLocationOutcome.granted(coords);
    } catch (_) {
      return HelpRequestLocationOutcome.failed(
        HelpRequestLocationFailure.unavailable,
      );
    }
  }
}
