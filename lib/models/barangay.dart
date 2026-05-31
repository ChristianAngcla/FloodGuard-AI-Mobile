import 'package:flutter_map/flutter_map.dart';

class Barangay {
  final String name;
  final Polygon polygon;

  Barangay({
    required this.name,
    required this.polygon,
  });
}
