/// Shared FloodGuard HTTPS API base (Render).
class ApiConfig {
  static const String host = 'https://floodguard-api-xyjx.onrender.com';
  static const String apiBase = '$host/api';

  /// Carto basemap API key to eliminate "API key required" watermark on mobile tiles.
  static const String cartoBasemapKey = String.fromEnvironment(
    'CARTO_BASEMAP_KEY',
    defaultValue: 'cb1_2ly2_1_0d9e8d060d164bd275073907',
  );

  static String get cartoVoyagerUrl {
    final key = cartoBasemapKey.trim();
    final query = key.isNotEmpty ? '?key=$key' : '';
    return 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png$query';
  }

  static String get cartoDarkUrl {
    final key = cartoBasemapKey.trim();
    final query = key.isNotEmpty ? '?key=$key' : '';
    return 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png$query';
  }
}
