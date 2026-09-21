import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load alerts from local storage (populated by FCM notifications)
      // Note: Alerts are saved locally by NotificationService when FCM
      // messages arrive (foreground, background, and terminated states).

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
      setState(() {
        _alerts.removeWhere((a) => a['id'] == id);
      });
      final alertsString = _alerts.map((a) => jsonEncode(a)).toList();
      await prefs.setStringList('app_alerts', alertsString);
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
      final index = _alerts.indexWhere((a) => a['id'] == id);
      if (index != -1 && _alerts[index]['isRead'] == false) {
        setState(() {
          _alerts[index]['isRead'] = true;
        });
        final alertsString = _alerts.map((a) => jsonEncode(a)).toList();
        await prefs.setStringList('app_alerts', alertsString);
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

  void _showAlertDetails(Map<String, dynamic> alert, bool isDark) {
    final bgColor = isDark ? const Color(0xFF253B50) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding:
            const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 32),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Builder(builder: (context) {
                final title = alert['title'] ?? "Alert";
                final body = alert['body'] ?? "";
                final fullText = "$title $body ${alert['data']?['status'] ?? ''}".toUpperCase();

                final bool isCritical = fullText.contains("CRITICAL");
                final bool isAlarm = fullText.contains("ALARM") || fullText.contains("WARNING");
                final bool isAlert = fullText.contains("ALERT");

                final Color riskColor = isCritical
                    ? const Color(0xFFDC2626)
                    : (isAlarm
                        ? const Color(0xFFEA580C)
                        : (isAlert ? const Color(0xFFD97706) : const Color(0xFF0284C7)));

                final Color badgeBg = isCritical
                    ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                    : (isAlarm
                        ? (isDark ? const Color(0xFF431407) : const Color(0xFFFFF7ED))
                        : (isAlert
                            ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEFCE8))
                            : (isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF))));

                final IconData riskIcon = isCritical
                    ? Icons.crisis_alert_rounded
                    : (isAlarm
                        ? Icons.warning_amber_rounded
                        : (isAlert ? Icons.notifications_active_outlined : Icons.shield_outlined));

                final String? meaning = isCritical
                    ? (widget.isTaglish
                        ? "Napakataas at mapanganib na antas ng tubig sa ilog. Matinding banta ng malawakang pagbaha sa mga apektadong lugar."
                        : "Dangerous river levels predicted. High risk of severe flooding in vulnerable areas.")
                    : (isAlarm
                        ? (widget.isTaglish
                            ? "Inaasahan ang mabilis na pagtaas ng tubig sa ilog. Posible ang pagbaha sa mabababang lugar at malapit sa ilog."
                            : "River water is rising fast. Flooding in low-lying and riverside areas is likely.")
                        : (isAlert
                            ? (widget.isTaglish
                                ? "Lumalapit na ang tubig sa alert level. Maaaring magsimula ang pag-ipon ng tubig sa mabababang lugar."
                                : "River levels are rising toward warning levels. Water may start pooling in low-lying areas.")
                            : null));

                final String? action = isCritical
                    ? (widget.isTaglish
                        ? "Unahin ang kaligtasan. Lumikas agad sa evacuation center kung inatasan ng Marikina LGU / DRRMO."
                        : "Prioritize safety and follow emergency or evacuation instructions from local authorities.")
                    : (isAlarm
                        ? (widget.isTaglish
                            ? "Ihanda ang emergency grab bag, i-charge ang cellphone, at maging handa sa paglikas kung iutos ng pamahalaan."
                            : "Prepare emergency grab bags, charge your devices, and be ready to evacuate if advised.")
                        : (isAlert
                            ? (widget.isTaglish
                                ? "Maging alerto, itaas ang mahahalagang gamit, at alamin ang ligtas na daan patungong evacuation center."
                                : "Stay alert, secure important belongings, and monitor official updates.")
                            : null));

                final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
                final cardBorder = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: badgeBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: riskColor.withValues(alpha: 0.35), width: 1.5),
                          ),
                          child: Center(
                            child: Icon(riskIcon, color: riskColor, size: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: riskColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (meaning != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: badgeBg.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: riskColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: riskColor),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isTaglish ? "Ano ang Ibig Sabihin Nito?" : "What This Means",
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
                      const SizedBox(height: 10),
                    ],

                    if (action != null) ...[
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
                                Icon(Icons.checklist_rounded, size: 16, color: riskColor),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isTaglish ? "Inirerekomendang Aksyon" : "Recommended Action",
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
                      const SizedBox(height: 14),
                    ],

                    if (body.isNotEmpty) ...[
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
                              widget.isTaglish ? "MGA DETALYE NG PAGTATAYA NG BAHA" : "FLOOD PREDICTION DETAILS",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              body,
                              style: TextStyle(fontSize: 14, color: textColor, height: 1.4, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(alert['timestamp'] ?? ""),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (meaning != null) ...[
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
                              widget.isTaglish ? "BAKIT ITO ANG PANGANIB?" : "WHY THIS RISK?",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isCritical
                                  ? (widget.isTaglish
                                      ? "Ang pagtatayang lebel ng tubig ay umabot o lumagpas sa Critical threshold para sa itinalagang monitoring station."
                                      : "The predicted water level reaches or exceeds the Critical threshold for the assigned monitoring station.")
                                  : (isAlarm
                                      ? (widget.isTaglish
                                          ? "Ang pagtatayang lebel ng tubig ay nasa Alarm range para sa itinalagang monitoring station."
                                          : "The predicted water level falls within the Alarm range for the assigned monitoring station.")
                                      : (widget.isTaglish
                                          ? "Ang pagtatayang lebel ng tubig ay nasa Alert range para sa itinalagang monitoring station."
                                          : "The predicted water level falls within the Alert range for the assigned monitoring station.")),
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
                    ],

                    Text(
                      widget.isTaglish
                          ? "Ipinapakita ng FloodGuard ang inaasahang panganib sa baha para sa barangay. Hindi nito ipinapakita kung aling mga kalye o bahay ang tiyak na babahain o kung gaano kalalim ang tubig-baha."
                          : "FloodGuard shows the predicted flood risk for the barangay. It does not show exactly which streets or houses will flood or how deep the floodwater will be.",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 22),
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
    final subColor = isDark ? Colors.white : const Color(0xFF4B5563);

    return Dismissible(
      key: Key(alert['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteAlert(alert['id']),
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
          _markAsRead(alert['id']);
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
                  : const Color(0xFF3784DF).withValues(alpha: 0.3),
              width: 1,
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
                      : Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: isRead ? Colors.grey : Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            alert['title'] ?? "Alert",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.bold,
                              color: isRead ? textColor : Colors.red,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3784DF),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert['body'] ?? "",
                      style: TextStyle(
                        fontSize: 14,
                        color: isRead ? subColor : textColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatDate(alert['timestamp'] ?? ""),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF475569),
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
