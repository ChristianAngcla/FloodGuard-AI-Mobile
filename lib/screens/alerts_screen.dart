import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../utils/station_thresholds.dart';
import '../widgets/flood_warning_scale.dart';
import '../widgets/wave_background.dart';
import '../widgets/floodguard_modal_dialog.dart';

class AlertsScreen extends StatefulWidget {
  final bool isTaglish;
  final bool isDarkMode;

  const AlertsScreen({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  StreamSubscription<void>? _alertsUpdatedSubscription;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _alertsUpdatedSubscription =
        NotificationService.onAlertsUpdated.stream.listen((_) {
      if (mounted) {
        _loadAlerts();
      }
    });
  }

  @override
  void dispose() {
    _alertsUpdatedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // CRITICAL: reload to get updates from background FCM isolate

      final alertsString = prefs.getStringList('app_alerts') ?? [];
      final alerts = alertsString
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();

      if (mounted) {
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAlert(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final alertsString = prefs.getStringList('app_alerts') ?? [];
      final updatedList = alertsString.where((e) {
        try {
          final decoded = jsonDecode(e) as Map<String, dynamic>;
          return decoded['id'] != id && decoded['messageId'] != id;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList('app_alerts', updatedList);
      if (mounted) {
        setState(() {
          _alerts.removeWhere((a) => a['id'] == id || a['messageId'] == id);
        });
      }
    } catch (e) {
      debugPrint('Error deleting alert: $e');
    }
  }

  Future<void> _clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_alerts');
      if (mounted) {
        setState(() {
          _alerts.clear();
        });
      }
    } catch (e) {
      debugPrint('Error clearing alerts: $e');
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final alertsString = prefs.getStringList('app_alerts') ?? [];
      final updatedList = alertsString.map((e) {
        try {
          final decoded = jsonDecode(e) as Map<String, dynamic>;
          if (decoded['id'] == id || decoded['messageId'] == id) {
            decoded['isRead'] = true;
            return jsonEncode(decoded);
          }
        } catch (_) {}
        return e;
      }).toList();
      await prefs.setStringList('app_alerts', updatedList);
      if (mounted) {
        setState(() {
          final index = _alerts.indexWhere((a) => a['id'] == id || a['messageId'] == id);
          if (index != -1) {
            _alerts[index]['isRead'] = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  String _formatDate(String isoString) {
    final date = DateTime.tryParse(isoString) ?? DateTime.now();
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
    final month = months[date.month - 1];
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? "PM" : "AM";
    final minute = date.minute.toString().padLeft(2, '0');
    return "$month ${date.day}, $hour:$minute $amPm";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A2B3C) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B3C);

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          WaveBackground(isDarkMode: isDark),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Column(
                  children: [
                    // Custom Header to fit safely below HomeMapScreen's Top Bar
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 35, left: 24, right: 24, bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 48), // Balance for centering
                          Text(
                            widget.isTaglish ? "Mga Abiso" : "Alerts",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _alerts.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.delete_sweep_rounded,
                                      color: Colors.redAccent),
                                  tooltip: widget.isTaglish
                                      ? "Burahin Lahat"
                                      : "Clear All",
                                  onPressed: () async {
                                    final confirmed = await FloodGuardModalDialog.show(
                                      context,
                                      title: widget.isTaglish ? "Burahin Lahat?" : "Clear All Alerts?",
                                      message: widget.isTaglish
                                          ? "Sigurado ka ba? Mabubura ang lahat ng nakaimbak na abiso at hindi na ito mababawi."
                                          : "Are you sure? All stored emergency alerts will be permanently removed.",
                                      variant: FloodGuardModalVariant.destructive,
                                      confirmLabel: widget.isTaglish ? "Burahin" : "Clear All",
                                      cancelLabel: widget.isTaglish ? "Kanselahin" : "Cancel",
                                      isDarkMode: isDark,
                                    );
                                    if (confirmed == true) {
                                      await _clearAll();
                                    }
                                  },
                                )
                              : const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _alerts.isEmpty
                              ? _buildEmptyState(isDark)
                              : RefreshIndicator(
                                  onRefresh: _loadAlerts,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(
                                        left: 16, right: 16, top: 8, bottom: 140),
                                    itemCount: _alerts.length,
                                    itemBuilder: (context, index) {
                                      final alert = _alerts[index];
                                      return _buildAlertCard(alert, isDark);
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_rounded,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              widget.isTaglish ? "Wala Pang Abiso" : "No Alerts Yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isTaglish
                  ? "Lilitaw dito ang mga abiso kapag may nagawang alerto para sa iyong barangay."
                  : "Alerts will appear here when an emergency broadcast is sent for your barangay.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white60 : Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3784DF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _loadAlerts,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(widget.isTaglish ? "I-reload" : "Reload"),
            ),
          ],
        ),
      ),
    );
  }

  String _extractStatusBand(Map<String, dynamic> alert) {
    final data = alert['data'] as Map<String, dynamic>? ?? {};
    final rawStatus = data['statusBand'] ?? data['status'] ?? data['severity'];
    if (rawStatus != null && rawStatus.toString().trim().isNotEmpty) {
      return rawStatus.toString().trim().toUpperCase();
    }
    final title = (alert['title'] ?? '').toString().toUpperCase();
    final body = (alert['body'] ?? '').toString().toUpperCase();
    final combined = '$title $body';
    if (combined.contains('CRITICAL')) return 'CRITICAL';
    if (combined.contains('ALARM') || combined.contains('WARNING')) return 'ALARM';
    if (combined.contains('ALERT')) return 'ALERT';
    return 'SAFE';
  }

  String _extractStationId(Map<String, dynamic> alert) {
    final data = alert['data'] as Map<String, dynamic>? ?? {};
    final raw = data['stationId'] ?? data['sensorKey'] ?? data['station'];
    if (raw != null && raw.toString().trim().isNotEmpty) {
      final s = raw.toString().trim().toLowerCase();
      if (s.contains('nangka')) return 'nangka';
      if (s.contains('sto') || s.contains('nino')) return 'sto_nino';
      if (s.contains('tumana')) return 'tumana';
      if (s.contains('montalban')) return 'montalban';
      if (s.contains('rosario')) return 'rosario';
      return s;
    }
    final combined = '${alert['title']} ${alert['body']}'.toLowerCase();
    if (combined.contains('nangka')) return 'nangka';
    if (combined.contains('sto') || combined.contains('nino')) return 'sto_nino';
    if (combined.contains('tumana')) return 'tumana';
    if (combined.contains('montalban')) return 'montalban';
    if (combined.contains('rosario')) return 'rosario';
    return 'nangka';
  }

  String _extractStationName(Map<String, dynamic> alert) {
    final stationId = _extractStationId(alert);
    switch (stationId.toLowerCase()) {
      case 'nangka':
        return 'Nangka River';
      case 'sto_nino':
        return 'Sto. Niño (Marikina River)';
      case 'tumana':
        return 'Tumana River';
      case 'montalban':
        return 'Montalban River';
      case 'rosario':
        return 'Rosario Junction';
      default:
        return 'Nangka River';
    }
  }

  String _extractBarangay(Map<String, dynamic> alert) {
    final data = alert['data'] as Map<String, dynamic>? ?? {};
    final b = data['barangay'];
    if (b != null && b.toString().trim().isNotEmpty) {
      return b.toString().trim();
    }
    final combined = '${alert['title']} ${alert['body']}';
    if (combined.contains('Nangka')) return 'Nangka';
    if (combined.contains('Tumana')) return 'Tumana';
    if (combined.contains('Malanday')) return 'Malanday';
    if (combined.contains('Concepcion')) return 'Concepcion';
    return 'Nangka';
  }

  double? _extractPredictedWaterLevel(Map<String, dynamic> alert) {
    final data = alert['data'] as Map<String, dynamic>? ?? {};
    final raw = data['predictedWaterLevel'] ?? data['level'] ?? data['waterLevel'];
    if (raw != null) {
      final cleaned = raw.toString().replaceAll('m', '').replaceAll('M', '').trim();
      final parsed = double.tryParse(cleaned);
      if (parsed != null) return parsed;
    }
    final combined = '${alert['body']} ${alert['title']}';
    final match = RegExp(r'(\d+\.\d+)\s*m?', caseSensitive: false).firstMatch(combined);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  String? _extractCalculationMode(Map<String, dynamic> alert) {
    final data = alert['data'] as Map<String, dynamic>? ?? {};
    final raw = data['calculationMode']?.toString();
    if (raw == null) return null;
    if (raw == 'primary_model') return 'Primary Model';
    if (raw == 'fallback_model') return 'Fallback Model';
    return raw;
  }

  String? _extractTargetDate(Map<String, dynamic> alert) {
    final data = alert['data'] as Map<String, dynamic>? ?? {};
    return data['forecastTargetDate']?.toString();
  }

  bool _isTestDrill(Map<String, dynamic> alert) {
    final data = alert['data'] as Map<String, dynamic>? ?? {};
    if (data['isTest'] == 'true' || data['type'] == 'test_notification_drill') return true;
    final title = (alert['title'] ?? '').toString();
    return title.contains('[TEST');
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFDC2626);
      case 'ALARM':
      case 'WARNING':
        return const Color(0xFFEA580C);
      case 'ALERT':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF16A34A);
    }
  }

  Color _statusBadgeBg(String status, bool isDark) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
      case 'ALARM':
      case 'WARNING':
        return isDark ? const Color(0xFF431407) : const Color(0xFFFFF7ED);
      case 'ALERT':
        return isDark ? const Color(0xFF451A03) : const Color(0xFFFEFCE8);
      default:
        return isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return Icons.crisis_alert_rounded;
      case 'ALARM':
      case 'WARNING':
        return Icons.warning_amber_rounded;
      case 'ALERT':
        return Icons.notifications_active_outlined;
      default:
        return Icons.shield_outlined;
    }
  }

  String _statusRiskLabel(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return 'CRITICAL: Severe Flood Risk';
      case 'ALARM':
      case 'WARNING':
        return 'ALARM: High Flood Risk';
      case 'ALERT':
        return 'ALERT: Moderate Flood Risk';
      default:
        return 'SAFE: Normal Water Level';
    }
  }

  String _statusMeaning(String status, bool isTaglish) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return isTaglish
            ? "Napakataas at mapanganib na antas ng tubig sa ilog. Matinding banta ng malawakang pagbaha sa mga apektadong lugar."
            : "Dangerous river levels predicted. High risk of severe flooding in vulnerable areas.";
      case 'ALARM':
      case 'WARNING':
        return isTaglish
            ? "Inaasahan ang mabilis na pagtaas ng tubig sa ilog. Posible ang pagbaha sa mabababang lugar at malapit sa ilog."
            : "River water is rising fast. Flooding in low-lying and riverside areas is likely.";
      case 'ALERT':
        return isTaglish
            ? "Lumalapit na ang tubig sa alert level. Maaaring magsimula ang pag-ipon ng tubig sa mabababang lugar."
            : "River levels are rising toward warning levels. Water may start pooling in low-lying areas.";
      default:
        return isTaglish
            ? "Normal ang lebel ng tubig sa ilog. Walang inaasahang pagbaha sa kasalukuyan."
            : "River water level is normal. No immediate flood risk predicted.";
    }
  }

  String _statusAction(String status, bool isTaglish) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return isTaglish
            ? "Unahin ang kaligtasan. Lumikas agad sa evacuation center kung inatasan ng Marikina LGU / DRRMO."
            : "Prioritize safety and follow emergency or evacuation instructions from local authorities.";
      case 'ALARM':
      case 'WARNING':
        return isTaglish
            ? "Ihanda ang emergency grab bag, i-charge ang cellphone, at maging handa sa paglikas kung iutos ng pamahalaan."
            : "Prepare emergency grab bags, charge your devices, and be ready to evacuate if advised.";
      case 'ALERT':
        return isTaglish
            ? "Maging alerto, itaas ang mahahalagang gamit, at alamin ang ligtas na daan patungong evacuation center."
            : "Stay alert, secure important belongings, and monitor official updates.";
      default:
        return isTaglish
            ? "Manatiling updated sa mga abiso ng FloodGuard at lokal na pamahalaan."
            : "Stay updated on weather forecasts and official announcements.";
    }
  }

  Widget _buildDetailRow({
    required String label,
    String? value,
    Widget? valueWidget,
    Color? valueColor,
    bool isBold = false,
    required bool isDark,
  }) {
    final subColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final valColor = valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: subColor,
          ),
        ),
        valueWidget ??
            Text(
              value ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: valColor,
              ),
            ),
      ],
    );
  }

  void _showAlertDetails(Map<String, dynamic> alert, bool isDark) {
    final bgColor = isDark ? const Color(0xFF253B50) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final statusBand = _extractStatusBand(alert);
    final stationId = _extractStationId(alert);
    final stationDisplayName = _extractStationName(alert);
    final barangay = _extractBarangay(alert);
    final predictedLevel = _extractPredictedWaterLevel(alert) ?? 17.40;
    final isTest = _isTestDrill(alert);
    final calculationMode = _extractCalculationMode(alert);
    final forecastTargetDate = _extractTargetDate(alert);

    final riskColor = _statusColor(statusBand);
    final badgeBg = _statusBadgeBg(statusBand, isDark);
    final riskIcon = _statusIcon(statusBand);
    final meaning = _statusMeaning(statusBand, widget.isTaglish);
    final action = _statusAction(statusBand, widget.isTaglish);
    final thresholds = StationThresholds.forSensor(stationId);

    final title = isTest
        ? '[TEST - NOTIFICATION DRILL] $statusBand — $barangay'
        : _statusRiskLabel(statusBand);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding:
            const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: badgeBg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: riskColor.withValues(alpha: 0.35),
                                  width: 1.5),
                            ),
                            child: Center(
                              child: Icon(riskIcon, color: riskColor, size: 24),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: riskColor,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTest ? 'Monitoring Station: $stationDisplayName' : 'Barangay $barangay',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // What This Means
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: badgeBg.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: riskColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16, color: riskColor),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isTaglish
                                      ? "Ano ang Ibig Sabihin Nito?"
                                      : "What This Means",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: riskColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meaning,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // What You Should Do
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.checklist_rounded,
                                    size: 16, color: riskColor),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isTaglish
                                      ? "Ano ang Dapat Mong Gawin"
                                      : "What You Should Do",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: riskColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              action,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // FLOOD PREDICTION DETAILS
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isTaglish
                                  ? "MGA DETALYE NG PAGTATAYA NG BAHA"
                                  : "FLOOD PREDICTION DETAILS",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              label: widget.isTaglish
                                  ? "Panganib sa Baha:"
                                  : "Predicted Flood Risk:",
                              valueWidget: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: riskColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: riskColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  statusBand,
                                  style: TextStyle(
                                    color: riskColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              label: widget.isTaglish
                                  ? "Tinatayang Lebel ng Tubig:"
                                  : "Predicted Water Level:",
                              value: '${predictedLevel.toStringAsFixed(2)} m',
                              valueColor: riskColor,
                              isBold: true,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              label: widget.isTaglish
                                  ? "Istasyon ng Pagsubaybay:"
                                  : "Monitoring Station:",
                              value: stationDisplayName,
                              isDark: isDark,
                            ),
                            if (calculationMode != null) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                label: widget.isTaglish
                                    ? "Paraan ng Pagkalkula:"
                                    : "Calculation Mode:",
                                value: calculationMode,
                                isDark: isDark,
                              ),
                            ],
                            if (forecastTargetDate != null) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                label: widget.isTaglish
                                    ? "Target na Petsa:"
                                    : "Target Date:",
                                value: forecastTargetDate,
                                isDark: isDark,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              _formatDate(alert['timestamp'] ?? ""),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // FloodWarningScale
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isTaglish
                                  ? "ANTAS NG BABALA SA ILOG"
                                  : "RIVER WARNING LEVEL SCALE",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FloodWarningScale(
                              predictedLevel: predictedLevel,
                              thresholds: thresholds,
                              status: statusBand,
                              stationName: stationDisplayName,
                              isDarkMode: isDark,
                              isTaglish: widget.isTaglish,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // WHY THIS RISK?
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isTaglish
                                  ? "BAKIT ITO ANG PANGANIB?"
                                  : "WHY THIS RISK?",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              statusBand == 'CRITICAL'
                                  ? (widget.isTaglish
                                      ? "Ang pagtatayang lebel ng tubig (${predictedLevel.toStringAsFixed(2)} m) ay umabot o lumagpas sa Critical threshold (${thresholds.critical.toStringAsFixed(2)} m) para sa $stationDisplayName."
                                      : "The predicted water level (${predictedLevel.toStringAsFixed(2)} m) reaches or exceeds the Critical threshold (${thresholds.critical.toStringAsFixed(2)} m) for $stationDisplayName.")
                                  : ((statusBand == 'ALARM' || statusBand == 'WARNING')
                                      ? (widget.isTaglish
                                          ? "Ang pagtatayang lebel ng tubig (${predictedLevel.toStringAsFixed(2)} m) ay nasa Alarm range (${thresholds.alarm.toStringAsFixed(2)} m hanggang ${thresholds.critical.toStringAsFixed(2)} m) para sa $stationDisplayName."
                                          : "The predicted water level (${predictedLevel.toStringAsFixed(2)} m) falls within the Alarm range (${thresholds.alarm.toStringAsFixed(2)} m to ${thresholds.critical.toStringAsFixed(2)} m) for $stationDisplayName.")
                                      : (widget.isTaglish
                                          ? "Ang pagtatayang lebel ng tubig (${predictedLevel.toStringAsFixed(2)} m) ay nasa Alert range (${thresholds.alert.toStringAsFixed(2)} m hanggang ${thresholds.alarm.toStringAsFixed(2)} m) para sa $stationDisplayName."
                                          : "The predicted water level (${predictedLevel.toStringAsFixed(2)} m) falls within the Alert range (${thresholds.alert.toStringAsFixed(2)} m to ${thresholds.alarm.toStringAsFixed(2)} m) for $stationDisplayName.")),
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        widget.isTaglish
                            ? "Ipinapakita ng FloodGuard ang inaasahang panganib sa baha para sa barangay. Hindi nito ipinapakita kung aling mga kalye o bahay ang tiyak na babahain o kung gaano kalalim ang tubig-baha."
                            : "FloodGuard shows the predicted flood risk for the barangay. It does not show exactly which streets or houses will flood or how deep the floodwater will be.",
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.white60 : const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3784DF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.isTaglish ? "Isara" : "Close",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, bool isDark) {
    final isRead = alert['isRead'] ?? false;
    final cardColor = isDark ? const Color(0xFF253B50) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563);

    final statusBand = _extractStatusBand(alert);
    final stationDisplayName = _extractStationName(alert);
    final barangay = _extractBarangay(alert);
    final predictedLevel = _extractPredictedWaterLevel(alert);
    final isTest = _isTestDrill(alert);

    final riskColor = _statusColor(statusBand);
    final badgeBg = _statusBadgeBg(statusBand, isDark);
    final riskIcon = _statusIcon(statusBand);
    final meaning = _statusMeaning(statusBand, widget.isTaglish);
    final action = _statusAction(statusBand, widget.isTaglish);
    final riskTitle = isTest
        ? '[TEST - NOTIFICATION DRILL] $statusBand — $barangay'
        : _statusRiskLabel(statusBand);

    final alertId = (alert['id'] ?? alert['messageId'] ?? UniqueKey().toString()).toString();

    return Dismissible(
      key: Key(alertId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteAlert(alertId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 28),
      ),
      child: GestureDetector(
        onTap: () {
          _markAsRead(alertId);
          _showAlertDetails(alert, isDark);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead
                ? cardColor
                : (isDark ? const Color(0xFF2C3E50) : const Color(0xFFF0F5FA)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? Colors.transparent
                  : riskColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isRead
                      ? (isDark ? Colors.white10 : Colors.grey[100])
                      : badgeBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isRead ? Colors.transparent : riskColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  riskIcon,
                  color: isRead ? Colors.grey : riskColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                riskTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isRead ? textColor : riskColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isTest ? 'Monitoring Station: $stationDisplayName' : 'Barangay $barangay',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(top: 4, left: 6),
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3784DF),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (predictedLevel != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: riskColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          'Predicted: ${predictedLevel.toStringAsFixed(2)} m • $stationDisplayName',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: riskColor,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // What This Means
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isTaglish ? 'Ibig Sabihin: ' : 'What This Means: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            meaning,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subColor,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // What You Should Do
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isTaglish ? 'Gagawin: ' : 'What You Should Do: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            action,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subColor,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDate(alert['timestamp'] ?? ""),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
