import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class WeatherCard extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String locationName;
  final bool isDarkMode;
  final bool isTaglish;

  const WeatherCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.isDarkMode,
    required this.isTaglish,
  });

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> with SingleTickerProviderStateMixin {
  WeatherData? _weatherData;
  bool _isLoading = false;
  String? _error;
  bool _show5DayForecast = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void didUpdateWidget(covariant WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude || oldWidget.longitude != widget.longitude) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await WeatherService.fetchWeather(widget.latitude, widget.longitude);
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoading = false;
          if (data == null) {
            _error = widget.isTaglish
                ? "Hindi makuha ang datos ng panahon"
                : "Unable to load weather data";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF253B50) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final Color subColor = widget.isDarkMode ? Colors.white54 : const Color(0xFF757575);
    final cardBorderColor = widget.isDarkMode ? Colors.white10 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: _isLoading && _weatherData == null
          ? _buildLoadingState(textColor)
          : _error != null
              ? _buildErrorState(textColor, subColor)
              : _weatherData == null
                  ? const SizedBox.shrink()
                  : _buildWeatherContent(textColor, subColor),
    );
  }

  Widget _buildLoadingState(Color textColor) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.isDarkMode ? Colors.white70 : const Color(0xFF3784DF),
              ),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              widget.isTaglish ? "Kinukuha ang panahon..." : "Loading weather...",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Color textColor, Color subColor) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wb_cloudy_outlined, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              _error ?? "",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchWeather,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(widget.isTaglish ? "Subukan Muli" : "Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3784DF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherContent(Color textColor, Color subColor) {
    final cur = _weatherData!.current;
    final detailBg = widget.isDarkMode ? const Color(0xFF1E2E3E) : const Color(0xFFF7F9FC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Top Row: Location, Status Badge & Temp ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.locationName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3784DF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3784DF).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      cur.weatherStatusText.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3784DF),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cur.temperature.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    height: 1.0,
                  ),
                ),
                Text(
                  '°C',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor.withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // --- Inside Grid Parameters Card ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: detailBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem(
                    widget.isTaglish ? "Tsansa ng Ulan:" : "Rain Chance:",
                    '${cur.rainChance}%',
                    subColor,
                    textColor,
                  ),
                  _buildDetailItem(
                    widget.isTaglish ? "Patak ng Ulan:" : "Precipitation:",
                    '${cur.precipitation.toStringAsFixed(1)} mm',
                    subColor,
                    textColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem(
                    widget.isTaglish ? "Halumigmig:" : "Humidity:",
                    '${cur.relativeHumidity}%',
                    subColor,
                    textColor,
                  ),
                  _buildDetailItem(
                    widget.isTaglish ? "Hangin:" : "Wind Speed:",
                    '${cur.windSpeed.toStringAsFixed(0)} km/h',
                    subColor,
                    textColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem(
                    widget.isTaglish ? "Heat Index:" : "Heat Index:",
                    '${cur.heatIndex.toStringAsFixed(1)}°C',
                    subColor,
                    textColor,
                  ),
                  const Expanded(child: SizedBox()), // Empty space to align left
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Expand/Collapse Button ---
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _show5DayForecast = !_show5DayForecast;
              });
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF3784DF).withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: const Color(0xFF3784DF).withValues(alpha: 0.05),
              foregroundColor: const Color(0xFF3784DF),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _show5DayForecast
                      ? (widget.isTaglish ? "I-collapse ang 5-Araw" : "Hide 5-Day Forecast")
                      : (widget.isTaglish ? "Ipakita ang 5-Araw na Ulat" : "Show 5-Day Forecast"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 6),
                Icon(
                  _show5DayForecast ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // --- Expandable 5-Day Forecast ---
        if (_show5DayForecast) ...[
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _weatherData!.daily.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final day = _weatherData!.daily[index];
              return _buildDailyForecastRow(day, textColor, subColor);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, Color labelColor, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyForecastRow(DailyForecast day, Color textColor, Color subColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Day name
        SizedBox(
          width: 55,
          child: Text(
            day.dayOfWeek.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
        // Weather Icon + Status
        Expanded(
          child: Row(
            children: [
              Icon(day.weatherIcon, size: 20, color: const Color(0xFF3784DF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  day.weatherStatusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: subColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Min / Max Temps
        Row(
          children: [
            Text(
              '${day.tempMax.toStringAsFixed(0)}°',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${day.tempMin.toStringAsFixed(0)}°',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: subColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
