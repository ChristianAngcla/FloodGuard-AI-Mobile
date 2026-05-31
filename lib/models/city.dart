import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class City {
  final String name;
  final LatLng center;
  final Polygon polygon;

  City({
    required this.name,
    required this.center,
    required this.polygon,
  });
}
