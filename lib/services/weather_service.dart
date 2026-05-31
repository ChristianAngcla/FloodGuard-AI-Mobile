import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 🌦️ Current Weather Model
class CurrentWeather {
  final double temperature;
  final int relativeHumidity;
  final double precipitation;
  final int weatherCode;
  final double windGust;
  final int rainChance;

  CurrentWeather({
    required this.temperature,
    required this.relativeHumidity,
    required this.precipitation,
    required this.weatherCode,
    required this.windGust,
    required this.rainChance,
  });

  String get weatherStatusText => WeatherTranslator.translateCode(weatherCode);
  IconData get weatherIcon => WeatherTranslator.getIcon(weatherCode);
}

/// 📅 Daily Forecast Model
class DailyForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final int weatherCode;

  DailyForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.weatherCode,
  });

  String get dayOfWeek {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String get weatherStatusText => WeatherTranslator.translateCode(weatherCode);
  IconData get weatherIcon => WeatherTranslator.getIcon(weatherCode);
}

/// 📦 Weather Data Wrapper
class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> daily;

  WeatherData({
    required this.current,
    required this.daily,
  });
}

/// ☀️ WMO Weather Code Translator
class WeatherTranslator {
  static String translateCode(int code) {
    switch (code) {
      case 0:
        return 'CLEAR SKY';
      case 1:
      case 2:
      case 3:
        return 'PARTLY CLOUDY';
      case 45:
      case 48:
        return 'FOGGY';
      case 51:
      case 53:
      case 55:
        return 'DRIZZLE';
      case 56:
      case 57:
        return 'FREEZING DRIZZLE';
      case 61:
        return 'LIGHT RAIN';
      case 63:
        return 'MODERATE RAIN';
      case 65:
        return 'HEAVY RAIN';
      case 66:
      case 67:
        return 'FREEZING RAIN';
      case 71:
        return 'LIGHT SNOW';
      case 73:
        return 'MODERATE SNOW';
      case 75:
        return 'HEAVY SNOW';
      case 77:
        return 'SNOW GRAINS';
      case 80:
        return 'LIGHT SHOWERS';
      case 81:
        return 'MODERATE SHOWERS';
      case 82:
        return 'HEAVY SHOWERS';
      case 85:
      case 86:
        return 'SNOW SHOWERS';
      case 95:
        return 'THUNDERSTORM';
      case 96:
      case 99:
        return 'HEAVY THUNDERSTORM';
      default:
        return 'RAINY';
    }
  }

  static IconData getIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
      case 3:
        return Icons.wb_cloudy_rounded;
      case 45:
      case 48:
        return Icons.blur_on_rounded;
      case 51:
      case 53:
      case 55:
        return Icons.grain_rounded;
      case 61:
      case 63:
        return Icons.umbrella_rounded;
      case 65:
        return Icons.thunderstorm_rounded;
      case 80:
      case 81:
      case 82:
        return Icons.umbrella_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.cloud_rounded;
    }
  }
}

/// 📡 Cache Entry Model
class _CacheEntry {
  final DateTime timestamp;
  final WeatherData data;

  _CacheEntry({required this.timestamp, required this.data});
}

/// ⚙️ Weather API Client & Cache Service
class WeatherService {
  static final Map<String, _CacheEntry> _cache = {};

  /// Fetches weather data for specific coordinates with 10-minute cache validation.
  static Future<WeatherData?> fetchWeather(double lat, double lng) async {
    // Round to 4 decimal places to normalize cache keys
    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    final now = DateTime.now();

    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (now.difference(entry.timestamp).inMinutes < 10) {
        debugPrint('⚡ [WeatherService] Using cached weather for $cacheKey');
        return entry.data;
      }
    }

    try {
      debugPrint('🔗 Querying Open-Meteo directly for ($lat, $lng)...');
      final url = 'https://api.open-meteo.com/v1/forecast?'
          'latitude=$lat&longitude=$lng'
          '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_gusts_10m'
          '&hourly=precipitation_probability'
          '&daily=temperature_2m_max,temperature_2m_min,weather_code'
          '&timezone=Asia/Singapore';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final weatherData = _parseWeatherData(decoded);
        _cache[cacheKey] = _CacheEntry(timestamp: now, data: weatherData);
        return weatherData;
      } else {
        debugPrint('⚠️ Weather API failed: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching weather from Open-Meteo: $e');
      return null;
    }
  }

  static WeatherData _parseWeatherData(Map<String, dynamic> decoded) {
    // Current conditions parsing
    final currentMap = decoded['current'] as Map<String, dynamic>;
    final temp = (currentMap['temperature_2m'] as num).toDouble();
    final humidity = (currentMap['relative_humidity_2m'] as num).toInt();
    final precipitation = (currentMap['precipitation'] as num).toDouble();
    final code = (currentMap['weather_code'] as num).toInt();
    final windGust = (currentMap['wind_gusts_10m'] as num).toDouble();

    // Rain chance parsing (estimate from current hour probability in hourly array)
    int rainChance = 0;
    try {
      final currentHourStr = currentMap['time'] as String?;
      if (currentHourStr != null) {
        final hourlyTimes = decoded['hourly']['time'] as List<dynamic>?;
        final hourlyProbabilities = decoded['hourly']['precipitation_probability'] as List<dynamic>?;
        if (hourlyTimes != null && hourlyProbabilities != null) {
          final currentDT = DateTime.parse(currentHourStr);
          int closestIndex = 0;
          int minDiff = 999999;
          for (int i = 0; i < hourlyTimes.length; i++) {
            final hourDT = DateTime.parse(hourlyTimes[i] as String);
            final diff = (hourDT.difference(currentDT).inMinutes).abs();
            if (diff < minDiff) {
              minDiff = diff;
              closestIndex = i;
            }
          }
          rainChance = (hourlyProbabilities[closestIndex] as num).toInt();
        }
      }
    } catch (e) {
      debugPrint('Error parsing rain chance: $e');
    }

    // 5-Day Forecast parsing
    final List<DailyForecast> dailyList = [];
    try {
      final dailyMap = decoded['daily'] as Map<String, dynamic>;
      final times = dailyMap['time'] as List<dynamic>;
      final maxTemps = dailyMap['temperature_2m_max'] as List<dynamic>;
      final minTemps = dailyMap['temperature_2m_min'] as List<dynamic>;
      final codes = dailyMap['weather_code'] as List<dynamic>;

      // Pull up to 5 days
      final count = times.length > 5 ? 5 : times.length;
      for (int i = 0; i < count; i++) {
        dailyList.add(DailyForecast(
          date: DateTime.parse(times[i] as String),
          tempMax: (maxTemps[i] as num).toDouble(),
          tempMin: (minTemps[i] as num).toDouble(),
          weatherCode: (codes[i] as num).toInt(),
        ));
      }
    } catch (e) {
      debugPrint('Error parsing daily forecast: $e');
    }

    return WeatherData(
      current: CurrentWeather(
        temperature: temp,
        relativeHumidity: humidity,
        precipitation: precipitation,
        weatherCode: code,
        windGust: windGust,
        rainChance: rainChance,
      ),
      daily: dailyList,
    );
  }
}
