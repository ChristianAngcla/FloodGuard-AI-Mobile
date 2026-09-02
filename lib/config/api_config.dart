/// Shared FloodGuard HTTPS API base (Render).
class ApiConfig {
  static const String host = 'https://floodguard-api-xyjx.onrender.com';
  static const String apiBase = '$host/api';

  /// Carto basemap API key to eliminate "API key required" watermark on mobile tiles.
  static const String cartoBasemapKey = 'cb1_2ly2_1_0d9e8d060d164bd275073907';
}
