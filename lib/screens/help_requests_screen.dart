import 'package:flutter/material.dart';

import '../services/flood_api_service.dart';
import '../utils/help_request_status.dart';
import '../widgets/wave_background.dart';

class HelpRequestsScreen extends StatefulWidget {
  final bool isTaglish;
  final bool isDarkMode;
  final bool embeddedInNavigation;

  const HelpRequestsScreen({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
    this.embeddedInNavigation = false,
  });

  @override
  State<HelpRequestsScreen> createState() => _HelpRequestsScreenState();
}

class _HelpRequestsScreenState extends State<HelpRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await FloodApiService.fetchMyHelpRequests();
      if (!mounted) return;
      setState(() {
        _requests = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().contains('not_authenticated')
            ? (widget.isTaglish
                ? 'Mag-sign in para makita ang iyong mga help request.'
                : 'Sign in to see your help requests.')
            : (widget.isTaglish
                ? 'Hindi ma-load ang mga help request. Subukan muli.'
                : 'Could not load your help requests. Please try again.');
      });
    }
  }

  String _formatDate(dynamic value) {
    DateTime? date;
    if (value is DateTime) {
      date = value.toLocal();
    } else if (value != null) {
      date = DateTime.tryParse(value.toString())?.toLocal();
    }
    if (date == null) return widget.isTaglish ? 'Walang petsa' : 'Unknown';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[date.month - 1];
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month ${date.day}, ${date.year} • $hour:$minute $amPm';
  }

  String _locationLabel(Map<String, dynamic> request) {
    final location = (request['location'] ?? '').toString().trim();
    if (location.isNotEmpty) return location;
    final street = (request['street'] ?? '').toString().trim();
    final barangay = (request['barangay'] ?? '').toString().trim();
    if (street.isNotEmpty && barangay.isNotEmpty) return '$street, $barangay';
    return barangay.isNotEmpty
        ? barangay
        : (widget.isTaglish ? 'Walang lokasyon' : 'Unknown location');
  }

  Color _statusColor(String status) {
    switch (HelpRequestStatus.normalize(status)) {
      case HelpRequestStatus.helpOnTheWay:
        return const Color(0xFFC2410C);
      case HelpRequestStatus.resolved:
        return const Color(0xFF15803D);
      case HelpRequestStatus.rejected:
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF3784DF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A2B3C) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B3C);

    final body = Stack(
      children: [
        WaveBackground(isDarkMode: isDark),
        SafeArea(
          bottom: widget.embeddedInNavigation ? false : true,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                    child: Row(
                      children: [
                        widget.embeddedInNavigation
                            ? const SizedBox(width: 48)
                            : IconButton(
                                icon: Icon(Icons.arrow_back_rounded,
                                    color: textColor),
                                onPressed: () => Navigator.pop(context),
                              ),
                        Expanded(
                          child: Text(
                            widget.isTaglish
                                ? 'Aking Help Requests'
                                : 'My Help Requests',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(child: _buildBody(isDark, textColor)),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.embeddedInNavigation) {
      return Container(color: bgColor, child: body);
    }
    return Scaffold(
      backgroundColor: bgColor,
      body: body,
    );
  }

  Widget _buildBody(bool isDark, Color textColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessageState(
        isDark,
        icon: Icons.error_outline_rounded,
        title: widget.isTaglish ? 'May Problema' : 'Something went wrong',
        body: _error!,
      );
    }
    if (_requests.isEmpty) {
      return _buildMessageState(
        isDark,
        icon: Icons.support_agent_rounded,
        title: widget.isTaglish ? 'Wala Pang Request' : 'No Help Requests Yet',
        body: widget.isTaglish
            ? 'Lilitaw dito ang iyong mga Ask for Help request.'
            : 'Your Ask for Help requests will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: widget.embeddedInNavigation ? 140 : 32),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(_requests[index], isDark, textColor);
        },
      ),
    );
  }

  Widget _buildMessageState(
    bool isDark, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            32, 32, 32, widget.embeddedInNavigation ? 140 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 80, color: isDark ? Colors.white24 : Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
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
              onPressed: _loadRequests,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(widget.isTaglish ? 'I-reload' : 'Reload'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> request,
    bool isDark,
    Color textColor,
  ) {
    final status = HelpRequestStatus.normalize(request['status']?.toString());
    final statusColor = _statusColor(status);
    final cardColor = isDark ? const Color(0xFF253B50) : Colors.white;
    final subColor = isDark ? Colors.white60 : Colors.grey[600];
    final submittedAt = request['submittedAt'] ?? request['timestamp'];
    final updatedAt = request['statusUpdatedAt'] ?? submittedAt;

    return GestureDetector(
      onTap: () => _showDetails(request, isDark),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              HelpRequestStatus.label(status, isTaglish: widget.isTaglish),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _locationLabel(request),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.isTaglish ? 'Naisumite' : 'Submitted'}: ${_formatDate(submittedAt)}',
              style: TextStyle(
                  fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
            ),
            Text(
              '${widget.isTaglish ? 'Na-update' : 'Updated'}: ${_formatDate(updatedAt)}',
              style: TextStyle(
                  fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
            ),
            if (status == HelpRequestStatus.rejected) ...[
              const SizedBox(height: 8),
              Text(
                '${widget.isTaglish ? 'Dahilan' : 'Reason'}: ${(request['statusReason'] ?? '').toString().trim().isEmpty ? (widget.isTaglish ? 'Walang dahilan' : 'No reason provided') : request['statusReason']}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> request, bool isDark) {
    final bgColor = isDark ? const Color(0xFF253B50) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final status = HelpRequestStatus.normalize(request['status']?.toString());
    final statusColor = _statusColor(status);
    final submittedAt = request['submittedAt'] ?? request['timestamp'];
    final updatedAt = request['statusUpdatedAt'] ?? submittedAt;
    final reason = (request['statusReason'] ?? '').toString().trim();

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
              const SizedBox(height: 24),
              Text(
                HelpRequestStatus.label(status, isTaglish: widget.isTaglish),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _locationLabel(request),
                style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.isTaglish ? 'Naisumite' : 'Submitted'}: ${_formatDate(submittedAt)}',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600),
              ),
              Text(
                '${widget.isTaglish ? 'Na-update' : 'Updated'}: ${_formatDate(updatedAt)}',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600),
              ),
              if (status == HelpRequestStatus.helpOnTheWay) ...[
                const SizedBox(height: 16),
                Text(
                  widget.isTaglish
                      ? 'Paparating ang tulong. Manatiling maaabot at asahan ang tawag o karagdagang utos mula sa inyong LGU.'
                      : 'Help is on the way. Please stay reachable and expect a call or further instructions from your LGU.',
                  style: TextStyle(fontSize: 15, color: textColor, height: 1.5),
                ),
              ],
              if (status == HelpRequestStatus.rejected) ...[
                const SizedBox(height: 16),
                Text(
                  widget.isTaglish ? 'Tinanggihan' : 'Rejected',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.isTaglish ? 'Dahilan' : 'Reason'}: ${reason.isEmpty ? (widget.isTaglish ? 'Walang dahilan' : 'No reason provided') : reason}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3784DF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.isTaglish ? 'Isara' : 'Close',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
