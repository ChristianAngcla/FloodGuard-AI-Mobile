import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/flood_api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../theme/app_spacing.dart';
import 'floodguard_modal_dialog.dart';

typedef HelpRequestSubmitHook = Future<bool> Function({
  required String location,
  required bool isRaining,
  required bool isSafe,
  required String uid,
  double? floodDepth,
  String? floodLevel,
  String? reporterName,
  String? reporterPhone,
  required double latitude,
  required double longitude,
  String? status,
  String? helpNeeded,
  String? helpType,
  String? helpSubtype,
  String? waterLevel,
  String? evacuationObstacle,
  String? vulnerablePerson,
  String? urgency,
  String? details,
});

class MultistepReportSheet extends StatefulWidget {
  final bool isTaglish;
  final bool isDarkMode;
  final VoidCallback onSuccess;
  final VoidCallback onSafe;
  final VoidCallback onUnsafe;
  final HelpRequestLocationResolver? locationResolver;
  final HelpRequestSubmitHook? submitFloodReport;

  const MultistepReportSheet({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
    required this.onSuccess,
    required this.onSafe,
    required this.onUnsafe,
    this.locationResolver,
    this.submitFloodReport,
  });

  @override
  State<MultistepReportSheet> createState() => _MultistepReportSheetState();
}

class _MultistepReportSheetState extends State<MultistepReportSheet> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Level 1: What help do you need?
  String? _helpType; // 'Medical', 'Evacuation', 'Other Emergency'

  // Level 2: Branch Details
  // Medical
  String? _medicalType; // 'Injury', 'Medical emergency', 'Help for another person'
  String? _urgency = 'Immediate / Life-threatening';

  // Evacuation
  String? _evacuationReason; // 'Floodwater is rising', 'I cannot safely leave', 'Need assistance for a vulnerable person', 'Other'
  String? _waterLevel; // 'Below knee', 'Knee to waist', 'Waist to chest', 'Above chest', 'Cannot estimate'
  String? _evacuationObstacle; // 'Floodwater blocking the way', 'No transportation', 'Physical difficulty', 'Other'
  String? _vulnerablePerson; // 'Child', 'Elderly person', 'Person with disability', 'Injured person'

  // Details text for notes / Other
  final TextEditingController _detailsCtrl = TextEditingController();

  // Location
  String? _selectedBarangay;
  final TextEditingController _streetCtrl = TextEditingController();

  // Confirmation & Legal
  bool _agreedToLegal = false;
  bool _isSubmitting = false;
  String? _validationMessage;
  bool _needsOpenSettings = false;
  late final HelpRequestLocationResolver _locationResolver;

  // Theme Colors
  Color get bgColor =>
      widget.isDarkMode ? const Color(0xFF1A2B3C) : Colors.white;
  Color get textColor =>
      widget.isDarkMode ? Colors.white : const Color(0xFF1A2B3C);
  Color get subTextColor =>
      widget.isDarkMode ? Colors.white70 : const Color(0xFF4B5563);
  Color get cardColor =>
      widget.isDarkMode ? const Color(0xFF253B50) : const Color(0xFFF8F9FA);
  Color get accentColor => const Color(0xFF3784DF);
  Color get emergencyColor => const Color(0xFFE53935);

  final List<String> _marikinaBarangays = [
    "Barangka",
    "Calumpang",
    "Concepcion Dos",
    "Concepcion Uno",
    "Fortune",
    "Industrial Valley",
    "Jesus De La Pena",
    "Malanday",
    "Marikina Heights",
    "Nangka",
    "Parang",
    "San Roque",
    "Santa Elena",
    "Santo Nino",
    "Tanong",
    "Tumana"
  ];

  @override
  void initState() {
    super.initState();
    _locationResolver =
        widget.locationResolver ?? HelpRequestLocationResolver.geolocator();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _streetCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Step 0: Help Type validation
    if (_currentStep == 0) {
      if (_helpType == null) {
        _showError(widget.isTaglish
            ? "Pakipili kung anong uri ng tulong ang kailangan mo."
            : "Please select what help you need.");
        return;
      }
    }

    // Step 1: Branch Details validation
    if (_currentStep == 1) {
      if (_helpType == 'Medical') {
        if (_medicalType == null) {
          _showError(widget.isTaglish
              ? "Pakipili ang uri ng medikal na tulong."
              : "Please select the type of medical assistance needed.");
          return;
        }
      } else if (_helpType == 'Evacuation') {
        if (_evacuationReason == null) {
          _showError(widget.isTaglish
              ? "Pakipili ang dahilan kung bakit kailangan ng tulong sa paglikas."
              : "Please select why you need evacuation assistance.");
          return;
        }
        if (_evacuationReason == 'Floodwater is rising') {
          if (_waterLevel == null) {
            _showError(widget.isTaglish
                ? "Pakisaad ang tinatayang taas ng tubig-baha."
                : "Please specify the estimated floodwater level.");
            return;
          }
        } else if (_evacuationReason == 'I cannot safely leave') {
          if (_evacuationObstacle == null) {
            _showError(widget.isTaglish
                ? "Pakipili ang humahadlang sa iyong pag-alis."
                : "Please select what is preventing you from leaving.");
            return;
          }
        } else if (_evacuationReason == 'Need assistance for a vulnerable person') {
          if (_vulnerablePerson == null) {
            _showError(widget.isTaglish
                ? "Pakipili kung sino ang nangangailangan ng tulong."
                : "Please select who needs assistance.");
            return;
          }
        } else if (_evacuationReason == 'Other') {
          if (_detailsCtrl.text.trim().isEmpty) {
            _showError(widget.isTaglish
                ? "Pakisaad ang mga detalye ng iyong paglikas."
                : "Please provide details for the evacuation request.");
            return;
          }
        }
      } else if (_helpType == 'Other Emergency') {
        if (_detailsCtrl.text.trim().isEmpty) {
          _showError(widget.isTaglish
              ? "Pakilarawan ang emergency situation."
              : "Please describe your emergency situation.");
          return;
        }
      }
    }

    // Step 2: Location validation
    if (_currentStep == 2) {
      if (_selectedBarangay == null) {
        _showError(widget.isTaglish
            ? "Pakipili ang iyong barangay upang magpatuloy."
            : "Please select your barangay to continue.");
        return;
      }
    }

    // Step 3: Confirmation handled directly by CONFIRM button

    if (_currentStep < _totalSteps - 1) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() {
        _validationMessage = null;
        _needsOpenSettings = false;
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() {
        _validationMessage = null;
        _needsOpenSettings = false;
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _showError(String msg, {bool needsOpenSettings = false}) {
    setState(() {
      _validationMessage = msg;
      _needsOpenSettings = needsOpenSettings;
    });
  }

  String? _getHelpSubtype() {
    if (_helpType == 'Medical') return _medicalType;
    if (_helpType == 'Evacuation') return _evacuationReason;
    return null;
  }

  double? _getWaterLevelDepth(String? level) {
    switch (level) {
      case 'Below knee':
        return 0.3;
      case 'Knee to waist':
        return 0.7;
      case 'Waist to chest':
        return 1.2;
      case 'Above chest':
        return 1.8;
      default:
        return null;
    }
  }

  String _getWaterLevelLabel(String? level) {
    switch (level) {
      case 'Below knee':
        return 'Ankle to Knee';
      case 'Knee to waist':
        return 'Knee to Waist';
      case 'Waist to chest':
        return 'Waist to Chest';
      case 'Above chest':
        return 'Above Chest';
      default:
        return level ?? 'Unknown';
    }
  }

  String _buildCompositeHelpNeeded() {
    final details = _detailsCtrl.text.trim();
    if (_helpType == 'Medical') {
      final parts = <String>['Medical'];
      if (_medicalType != null) parts.add(_medicalType!);
      if (_urgency != null) parts.add('($_urgency)');
      var res = parts.join(' - ');
      if (details.isNotEmpty) res += ': $details';
      return res;
    }
    if (_helpType == 'Evacuation') {
      var res = 'Evacuation';
      if (_evacuationReason == 'Floodwater is rising') {
        res += ' - Floodwater is rising (${_waterLevel ?? 'Level unspecified'})';
      } else if (_evacuationReason == 'I cannot safely leave') {
        res += ' - Cannot safely leave (${_evacuationObstacle ?? 'Obstacle unspecified'})';
      } else if (_evacuationReason == 'Need assistance for a vulnerable person') {
        res += ' - Vulnerable person (${_vulnerablePerson ?? 'Unspecified'})';
      } else if (_evacuationReason == 'Other') {
        res += ' - Other';
      } else if (_evacuationReason != null) {
        res += ' - $_evacuationReason';
      }
      if (details.isNotEmpty) res += ': $details';
      return res;
    }
    if (_helpType == 'Other Emergency') {
      return details.isNotEmpty ? 'Other Emergency: $details' : 'Other Emergency';
    }
    return 'Emergency Assistance';
  }

  Widget _buildModalSummaryItem(
    String label,
    String value,
    Color labelColor,
    Color valColor, {
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationModalSummary(bool isDark) {
    final detailsText = _detailsCtrl.text.trim();
    final streetText = _streetCtrl.text.trim();
    final locationText = streetText.isNotEmpty && (_selectedBarangay != null)
        ? "$streetText, $_selectedBarangay"
        : (_selectedBarangay ?? "Marikina City");

    final summaryBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final labelColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final valColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: summaryBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModalSummaryItem(
            widget.isTaglish ? "Uri ng Tulong:" : "Help Type:",
            _helpType ?? "Emergency",
            labelColor,
            const Color(0xFFDC2626),
            isBold: true,
          ),
          if (_helpType == 'Medical') ...[
            const SizedBox(height: 6),
            _buildModalSummaryItem(
              widget.isTaglish ? "Medikal:" : "Medical:",
              _medicalType ?? "Not specified",
              labelColor,
              valColor,
            ),
            if (_urgency != null) ...[
              const SizedBox(height: 6),
              _buildModalSummaryItem(
                widget.isTaglish ? "Urgency:" : "Urgency:",
                _urgency!,
                labelColor,
                const Color(0xFFDC2626),
              ),
            ],
          ],
          if (_helpType == 'Evacuation') ...[
            if (_evacuationReason != null) ...[
              const SizedBox(height: 6),
              _buildModalSummaryItem(
                widget.isTaglish ? "Dahilan:" : "Reason:",
                _evacuationReason!,
                labelColor,
                valColor,
              ),
            ],
            if (_evacuationReason == 'I cannot safely leave') ...[
              const SizedBox(height: 6),
              _buildModalSummaryItem(
                widget.isTaglish ? "Kalagayan:" : "Status:",
                widget.isTaglish ? "Hindi makalikas nang ligtas" : "Cannot safely leave",
                labelColor,
                const Color(0xFFDC2626),
              ),
            ],
            if (_evacuationObstacle != null) ...[
              const SizedBox(height: 6),
              _buildModalSummaryItem(
                widget.isTaglish ? "Balakid:" : "Obstacle:",
                _evacuationObstacle!,
                labelColor,
                valColor,
              ),
            ],
            if (_vulnerablePerson != null) ...[
              const SizedBox(height: 6),
              _buildModalSummaryItem(
                widget.isTaglish ? "Vulnerable:" : "Vulnerable:",
                _vulnerablePerson!,
                labelColor,
                valColor,
              ),
            ],
            if (_waterLevel != null) ...[
              const SizedBox(height: 6),
              _buildModalSummaryItem(
                widget.isTaglish ? "Antas ng Tubig:" : "Water Level:",
                _waterLevel!,
                labelColor,
                valColor,
              ),
            ],
          ],
          if (_helpType == 'Other Emergency' && detailsText.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildModalSummaryItem(
              widget.isTaglish ? "Detalye:" : "Details:",
              detailsText,
              labelColor,
              valColor,
            ),
          ],
          const SizedBox(height: 6),
          _buildModalSummaryItem(
            widget.isTaglish ? "Lokasyon:" : "Location:",
            locationText,
            labelColor,
            valColor,
          ),
          if (_urgency != null && _helpType != 'Medical') ...[
            const SizedBox(height: 6),
            _buildModalSummaryItem(
              widget.isTaglish ? "Urgency:" : "Urgency:",
              _urgency!,
              labelColor,
              const Color(0xFFDC2626),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _executeReportSubmission() async {
    final locationOutcome = await _locationResolver.resolveForSubmit();
    if (!mounted) return false;
    if (!locationOutcome.canSubmit) {
      final failure =
          locationOutcome.failure ?? HelpRequestLocationFailure.unavailable;

      final String title;
      final String message;
      if (failure == HelpRequestLocationFailure.outsideMarikina) {
        title = widget.isTaglish ? "Nasa Labas ng Marikina" : "Outside Marikina";
        message = widget.isTaglish
            ? kHelpRequestOutsideMarikinaTl
            : kHelpRequestOutsideMarikinaEn;
      } else {
        title = widget.isTaglish ? "Kailangan ang Lokasyon" : "Location Needed";
        message = widget.isTaglish
            ? kHelpRequestLocationRequiredTl
            : kHelpRequestLocationRequiredEn;
      }

      FloodGuardModalDialog.show(
        context,
        title: title,
        message: message,
        variant: FloodGuardModalVariant.warning,
        confirmLabel: locationOutcome.needsOpenSettings
            ? (widget.isTaglish ? "Buksan ang Settings" : "Open Settings")
            : (widget.isTaglish ? "Naintindihan" : "OK"),
        isDarkMode: widget.isDarkMode,
      ).then((confirmed) {
        if (confirmed == true && locationOutcome.needsOpenSettings) {
          _locationResolver.openAppSettings();
        }
      });
      return false;
    }

    final lat = locationOutcome.coordinates!.latitude;
    final lng = locationOutcome.coordinates!.longitude;

    final uid = await AuthService().getEffectiveUid();
    final userUid = uid ?? "anonymous";
    final streetText = _streetCtrl.text.trim();
    final barangayText = (_selectedBarangay ?? "").trim();
    final location = streetText.isNotEmpty && barangayText.isNotEmpty
        ? "$streetText, $barangayText"
        : (streetText.isNotEmpty
            ? streetText
            : (barangayText.isNotEmpty ? barangayText : "Unknown Location"));

    String reporterName = 'Unknown Reporter';
    String reporterPhone = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        final firstName = userData['firstName'] ?? userData['first_name'] ?? '';
        final lastName = userData['lastName'] ?? userData['last_name'] ?? '';
        reporterName = '$firstName $lastName'.trim();
        if (reporterName.isEmpty) reporterName = 'Unknown Reporter';
        reporterPhone = formatPhMobileNumber(userData['phone'] ?? '');
      }

      // PHONE VERIFICATION CHECK
      if (reporterPhone.isEmpty) {
        _showError(widget.isTaglish
            ? "Kailangan ng verified na numero ng telepono sa profile para makapag-ulat."
            : "A verified phone number in your profile is required to ask for help.");
        return false;
      }
    } catch (e) {
      debugPrint('Could not load user profile for report: $e');
    }

    final detailsText = _detailsCtrl.text.trim();
    final compositeHelp = _buildCompositeHelpNeeded();
    final floodDepth = _getWaterLevelDepth(_waterLevel);
    final floodLevel = _getWaterLevelLabel(_waterLevel);

    final submit = widget.submitFloodReport ??
        ({
          required String location,
          required bool isRaining,
          required bool isSafe,
          required String uid,
          double? floodDepth,
          String? floodLevel,
          String? reporterName,
          String? reporterPhone,
          required double latitude,
          required double longitude,
          String? status,
          String? helpNeeded,
          String? helpType,
          String? helpSubtype,
          String? waterLevel,
          String? evacuationObstacle,
          String? vulnerablePerson,
          String? urgency,
          String? details,
        }) {
          return FloodApiService.submitFloodReport(
            location: location,
            isRaining: isRaining,
            isSafe: isSafe,
            uid: uid,
            floodDepth: floodDepth,
            floodLevel: floodLevel,
            reporterName: reporterName,
            reporterPhone: reporterPhone,
            latitude: latitude,
            longitude: longitude,
            status: status,
            helpNeeded: helpNeeded,
            helpType: helpType,
            helpSubtype: helpSubtype,
            waterLevel: waterLevel,
            evacuationObstacle: evacuationObstacle,
            vulnerablePerson: vulnerablePerson,
            urgency: urgency,
            details: details,
          );
        };

    final success = await submit(
      location: location,
      isRaining: false,
      isSafe: false, // Help requests are inherently emergency requests
      uid: userUid,
      floodDepth: floodDepth,
      floodLevel: floodLevel,
      reporterName: reporterName,
      reporterPhone: reporterPhone,
      latitude: lat,
      longitude: lng,
      status: 'submitted',
      helpNeeded: compositeHelp,
      helpType: _helpType,
      helpSubtype: _getHelpSubtype(),
      waterLevel: _waterLevel,
      evacuationObstacle: _evacuationObstacle,
      vulnerablePerson: _vulnerablePerson,
      urgency: _urgency,
      details: detailsText.isNotEmpty ? detailsText : null,
    );

    if (mounted) {
      if (!success) {
        final apiMessage = widget.submitFloodReport == null
            ? FloodApiService.lastHelpRequestError
            : null;
        _showError(apiMessage ??
            (widget.isTaglish
                ? "Nabigo ang pagpapadala ng ulat. Subukan muli."
                : "Failed to submit report. Please try again."));
      }
    }

    return success;
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    if (!_agreedToLegal) {
      _showError(widget.isTaglish
          ? "Kailangan mong sumang-ayon sa emergency notice upang magpatuloy."
          : "Please agree to the emergency notice to continue.");
      return;
    }

    setState(() {
      _validationMessage = null;
      _needsOpenSettings = false;
    });

    // Check verified phone before opening confirmation dialog
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      String reporterPhone = '';
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        reporterPhone = formatPhMobileNumber(userData['phone'] ?? '');
      }
      if (reporterPhone.isEmpty) {
        _showError(widget.isTaglish
            ? "Kailangan ng verified na numero ng telepono sa profile para makapag-ulat."
            : "A verified phone number in your profile is required to ask for help.");
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    final rootNav = Navigator.of(context, rootNavigator: true);

    await showDialog<bool>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return FloodGuardModalDialog(
              title: widget.isTaglish
                  ? "Ipadala ang Saklolo?"
                  : "Send Help Request?",
              message: widget.isTaglish
                  ? "Pakisuri ang iyong impormasyon bago ito ipadala sa LGU."
                  : "Please review your information before sending this request to the LGU.",
              content: _buildConfirmationModalSummary(widget.isDarkMode),
              variant: FloodGuardModalVariant.warning,
              cancelLabel: widget.isTaglish ? "Bumalik" : "Cancel",
              confirmLabel: widget.isTaglish
                  ? "Kumpirmahin at Ipadala"
                  : "Confirm & Send",
              isDarkMode: widget.isDarkMode,
              isLoading: _isSubmitting,
              onCancel: _isSubmitting
                  ? null
                  : () => Navigator.of(dialogCtx).pop(false),
              onConfirm: _isSubmitting
                  ? null
                  : () async {
                      if (dialogCtx.mounted) {
                        Navigator.of(dialogCtx).pop(false);
                      }
                      setState(() => _isSubmitting = true);

                      final success = await _executeReportSubmission();

                      if (!mounted) return;
                      setState(() => _isSubmitting = false);

                      if (success) {
                        if (mounted && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        SharedPreferences.getInstance().then((p) =>
                            p.setString('last_report_time', DateTime.now().toIso8601String()));
                        widget.onSuccess();
                        widget.onUnsafe();
                        if (rootNav.context.mounted) {
                          FloodGuardModalDialog.show(
                            rootNav.context,
                            title: widget.isTaglish
                                ? "Naipadala na ang Saklolo"
                                : "Help Request Sent",
                            message: widget.isTaglish
                                ? "Ang iyong kahilingan ay naisumite na sa LGU."
                                : "Your request has been submitted to the LGU.",
                            variant: FloodGuardModalVariant.success,
                            confirmLabel: widget.isTaglish ? "Naintindihan" : "OK",
                            isDarkMode: widget.isDarkMode,
                          );
                        }
                      }
                    },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.s6),
                    // Drag Handle
                    Container(
                      width: AppSpacing.s13 + AppSpacing.s4,
                      height: AppSpacing.s2,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),

                    // Progress Indicator (4 Steps)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s11),
                      child: Row(
                        children: List.generate(_totalSteps, (index) {
                          final isActive = _currentStep >= index;
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (_currentStep == _totalSteps - 1
                                        ? emergencyColor
                                        : accentColor)
                                    : (widget.isDarkMode
                                        ? Colors.white24
                                        : Colors.grey[300]),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Page Content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStep0HelpType(),
                          _buildStep1BranchSpecifics(),
                          _buildStep2Location(),
                          _buildStep3Confirmation(),
                        ],
                      ),
                    ),

                    if (_validationMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: Colors.redAccent),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _validationMessage!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_needsOpenSettings)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          _locationResolver.openAppSettings(),
                                      child: Text(
                                        widget.isTaglish
                                            ? 'Buksan ang Settings'
                                            : 'Open Settings',
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Bottom Navigation Bar
                    _buildBottomNavigationBar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final isConfirmStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: widget.isDarkMode ? Colors.white10 : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: isConfirmStep
          ? Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _prevStep,
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: Text(
                      widget.isTaglish ? "I-EDIT" : "EDIT",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: textColor,
                      side: BorderSide(
                        color: widget.isDarkMode ? Colors.white38 : Colors.grey[400]!,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildGradientButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    isSubmit: true,
                    isSubmitting: _isSubmitting,
                    text: widget.isTaglish ? "KUMPIRMAHIN" : "CONFIRM",
                  ),
                ),
              ],
            )
          : Row(
              children: [
                if (_currentStep > 0) ...[
                  TextButton(
                    onPressed: _prevStep,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: Text(
                      widget.isTaglish ? "Bumalik" : "Back",
                      style: TextStyle(
                          color: subTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _buildGradientButton(
                    onPressed: _nextStep,
                    isSubmit: false,
                    isSubmitting: false,
                    text: widget.isTaglish ? "Susunod" : "Next",
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    required bool isSubmit,
    required bool isSubmitting,
    required String text,
  }) {
    final buttonColor = isSubmit ? emergencyColor : accentColor;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [buttonColor.withValues(alpha: 0.85), buttonColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                text,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white),
              ),
      ),
    );
  }

  // --- STEP 0: What Help Do You Need? ---

  Widget _buildStep0HelpType() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isTaglish
                ? "Anong tulong ang kailangan mo?"
                : "What help do you need?",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isTaglish
                ? "Piliin ang pinakaangkop na tulong para mabilis kang maasikaso."
                : "Select the emergency assistance category required.",
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 24),
          _buildHelpTypeCard(
            title: "Medical",
            taglishTitle: "Tulong Medikal",
            subtitle: "Injury, health emergency, or medical aid",
            taglishSubtitle: "Pinsala, medikal na emergency, o saklolo",
            icon: Icons.medical_services_rounded,
            isSelected: _helpType == 'Medical',
            onTap: () {
              setState(() {
                _helpType = 'Medical';
                _validationMessage = null;
              });
            },
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 14),
          _buildHelpTypeCard(
            title: "Evacuation",
            taglishTitle: "Paglikas / Evacuation",
            subtitle: "Rising floodwater, cannot safely leave, or vulnerable person rescue",
            taglishSubtitle: "Tumataas ang baha, naipit, o may kailangang ilikas",
            icon: Icons.directions_run_rounded,
            isSelected: _helpType == 'Evacuation',
            onTap: () {
              setState(() {
                _helpType = 'Evacuation';
                _validationMessage = null;
              });
            },
            color: const Color(0xFFF97316),
          ),
          const SizedBox(height: 14),
          _buildHelpTypeCard(
            title: "Other Emergency",
            taglishTitle: "Ibang Emergency",
            subtitle: "Immediate safety hazard or specific emergency situation",
            taglishSubtitle: "Iba pang kagyat o mapanganib na sitwasyon",
            icon: Icons.warning_amber_rounded,
            isSelected: _helpType == 'Other Emergency',
            onTap: () {
              setState(() {
                _helpType = 'Other Emergency';
                _validationMessage = null;
              });
            },
            color: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpTypeCard({
    required String title,
    required String taglishTitle,
    required String subtitle,
    required String taglishSubtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? color
                : (widget.isDarkMode ? Colors.white12 : Colors.grey[200]!),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isTaglish ? taglishTitle : title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isTaglish ? taglishSubtitle : subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subTextColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  // --- STEP 1: Branch Specifics ---

  Widget _buildStep1BranchSpecifics() {
    if (_helpType == 'Medical') {
      return _buildMedicalBranch();
    }
    if (_helpType == 'Evacuation') {
      return _buildEvacuationBranch();
    }
    return _buildOtherEmergencyBranch();
  }

  Widget _buildMedicalBranch() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isTaglish
                ? "Detalye ng Tulong Medikal"
                : "Medical Assistance Details",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isTaglish
                ? "Anong uri ng medikal na tulong ang kailangan?"
                : "What kind of medical help do you need?",
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 14),
          _buildSelectionCard(
            widget.isTaglish ? "Pinsala / Sugat" : "Injury",
            Icons.healing_rounded,
            _medicalType == 'Injury',
            () => setState(() => _medicalType = 'Injury'),
            activeColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 10),
          _buildSelectionCard(
            widget.isTaglish ? "Medikal na Emergency" : "Medical emergency",
            Icons.local_hospital_rounded,
            _medicalType == 'Medical emergency',
            () => setState(() => _medicalType = 'Medical emergency'),
            activeColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 10),
          _buildSelectionCard(
            widget.isTaglish ? "Tulong para sa Ibang Tao" : "Help for another person",
            Icons.person_add_alt_1_rounded,
            _medicalType == 'Help for another person',
            () => setState(() => _medicalType = 'Help for another person'),
            activeColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isTaglish
                ? "Antas ng Pangangailangan (Urgency)"
                : "Urgency Level",
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          _buildSelectionCard(
            widget.isTaglish
                ? "Agad-agad / Nanganganib ang buhay"
                : "Immediate / Life-threatening",
            Icons.crisis_alert_rounded,
            _urgency == 'Immediate / Life-threatening',
            () => setState(() => _urgency = 'Immediate / Life-threatening'),
            activeColor: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 8),
          _buildSelectionCard(
            widget.isTaglish ? "Kagyat / Malubha" : "Urgent / Serious",
            Icons.priority_high_rounded,
            _urgency == 'Urgent / Serious',
            () => setState(() => _urgency = 'Urgent / Serious'),
            activeColor: const Color(0xFFEA580C),
          ),
          const SizedBox(height: 8),
          _buildSelectionCard(
            widget.isTaglish
                ? "Hindi nanganganib ang buhay"
                : "Non-life threatening",
            Icons.info_outline_rounded,
            _urgency == 'Non-life threatening',
            () => setState(() => _urgency = 'Non-life threatening'),
            activeColor: const Color(0xFF0284C7),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _detailsCtrl,
            maxLines: 2,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: _inputDecoration(
              widget.isTaglish
                  ? "Karagdagang detalye (Opsyonal)"
                  : "Additional details (Optional)",
              Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEvacuationBranch() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isTaglish
                ? "Tulong sa Paglikas (Evacuation)"
                : "Evacuation Assistance",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isTaglish
                ? "Bakit kailangan mo ng tulong sa paglikas?"
                : "Why do you need evacuation assistance?",
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 14),
          _buildSelectionCard(
            widget.isTaglish ? "Tumataas ang baha" : "Floodwater is rising",
            Icons.waves_rounded,
            _evacuationReason == 'Floodwater is rising',
            () => setState(() {
              _evacuationReason = 'Floodwater is rising';
              _validationMessage = null;
            }),
            activeColor: const Color(0xFFF97316),
          ),
          const SizedBox(height: 10),
          _buildSelectionCard(
            widget.isTaglish ? "Hindi ligtas na makaalis" : "I cannot safely leave",
            Icons.sensor_door_outlined,
            _evacuationReason == 'I cannot safely leave',
            () => setState(() {
              _evacuationReason = 'I cannot safely leave';
              _validationMessage = null;
            }),
            activeColor: const Color(0xFFF97316),
          ),
          const SizedBox(height: 10),
          _buildSelectionCard(
            widget.isTaglish
                ? "Kailangan ng tulong para sa mahinang tao"
                : "Need assistance for a vulnerable person",
            Icons.accessible_rounded,
            _evacuationReason == 'Need assistance for a vulnerable person',
            () => setState(() {
              _evacuationReason = 'Need assistance for a vulnerable person';
              _validationMessage = null;
            }),
            activeColor: const Color(0xFFF97316),
          ),
          const SizedBox(height: 10),
          _buildSelectionCard(
            widget.isTaglish ? "Iba pa" : "Other",
            Icons.more_horiz_rounded,
            _evacuationReason == 'Other',
            () => setState(() {
              _evacuationReason = 'Other';
              _validationMessage = null;
            }),
            activeColor: const Color(0xFFF97316),
          ),

          // Sub-branch follow-ups
          if (_evacuationReason == 'Floodwater is rising') ...[
            const SizedBox(height: 24),
            Text(
              widget.isTaglish
                  ? "Gaano kataas ang baha sa inyo?"
                  : "Estimated floodwater level:",
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 12),
            _buildSelectionCard(
              widget.isTaglish ? "Hanggang binti (Mababa sa tuhod)" : "Below knee",
              Icons.waves_rounded,
              _waterLevel == 'Below knee',
              () => setState(() => _waterLevel = 'Below knee'),
              activeColor: const Color(0xFF0284C7),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "Tuhod hanggang baywang" : "Knee to waist",
              Icons.waves_rounded,
              _waterLevel == 'Knee to waist',
              () => setState(() => _waterLevel = 'Knee to waist'),
              activeColor: const Color(0xFFEAB308),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "Baywang hanggang dibdib" : "Waist to chest",
              Icons.warning_amber_rounded,
              _waterLevel == 'Waist to chest',
              () => setState(() => _waterLevel = 'Waist to chest'),
              activeColor: const Color(0xFFF97316),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "Lagpas dibdib" : "Above chest",
              Icons.warning_rounded,
              _waterLevel == 'Above chest',
              () => setState(() => _waterLevel = 'Above chest'),
              activeColor: const Color(0xFFDC2626),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "Hindi matantiya" : "Cannot estimate",
              Icons.help_outline_rounded,
              _waterLevel == 'Cannot estimate',
              () => setState(() => _waterLevel = 'Cannot estimate'),
              activeColor: Colors.grey,
            ),
          ],

          if (_evacuationReason == 'I cannot safely leave') ...[
            const SizedBox(height: 24),
            Text(
              widget.isTaglish
                  ? "Ano ang humahadlang sa iyong pag-alis?"
                  : "What is preventing you from leaving?",
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 12),
            _buildSelectionCard(
              widget.isTaglish
                  ? "Nakaharang ang baha sa daanan"
                  : "Floodwater blocking the way",
              Icons.block_rounded,
              _evacuationObstacle == 'Floodwater blocking the way',
              () => setState(() => _evacuationObstacle = 'Floodwater blocking the way'),
              activeColor: const Color(0xFFF97316),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "Walang masasakyan" : "No transportation",
              Icons.directions_car_filled_outlined,
              _evacuationObstacle == 'No transportation',
              () => setState(() => _evacuationObstacle = 'No transportation'),
              activeColor: const Color(0xFFF97316),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish
                  ? "Pisikal na kahirapan"
                  : "Physical difficulty",
              Icons.accessibility_new_rounded,
              _evacuationObstacle == 'Physical difficulty',
              () => setState(() => _evacuationObstacle = 'Physical difficulty'),
              activeColor: const Color(0xFFF97316),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "Iba pang hadlang" : "Other",
              Icons.more_horiz_rounded,
              _evacuationObstacle == 'Other',
              () => setState(() => _evacuationObstacle = 'Other'),
              activeColor: const Color(0xFFF97316),
            ),
          ],

          if (_evacuationReason == 'Need assistance for a vulnerable person') ...[
            const SizedBox(height: 24),
            Text(
              widget.isTaglish
                  ? "Sino ang nangangailangan ng tulong?"
                  : "Who needs assistance?",
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 12),
            _buildSelectionCard(
              widget.isTaglish ? "Bata" : "Child",
              Icons.child_care_rounded,
              _vulnerablePerson == 'Child',
              () => setState(() => _vulnerablePerson = 'Child'),
              activeColor: const Color(0xFFF97316),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "Matanda / Senior Citizen" : "Elderly person",
              Icons.elderly_rounded,
              _vulnerablePerson == 'Elderly person',
              () => setState(() => _vulnerablePerson = 'Elderly person'),
              activeColor: const Color(0xFFF97316),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "May Kapansanan (PWD)" : "Person with disability",
              Icons.accessible_rounded,
              _vulnerablePerson == 'Person with disability',
              () => setState(() => _vulnerablePerson = 'Person with disability'),
              activeColor: const Color(0xFFF97316),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              widget.isTaglish ? "May pinsala / sugatan" : "Injured person",
              Icons.healing_rounded,
              _vulnerablePerson == 'Injured person',
              () => setState(() => _vulnerablePerson = 'Injured person'),
              activeColor: const Color(0xFFF97316),
            ),
          ],

          const SizedBox(height: 20),
          TextField(
            controller: _detailsCtrl,
            maxLines: 2,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: _inputDecoration(
              _evacuationReason == 'Other'
                  ? (widget.isTaglish
                      ? "Pakisaad ang mga detalye (Kailangan)"
                      : "Specific details (Required)")
                  : (widget.isTaglish
                      ? "Karagdagang detalye (Opsyonal)"
                      : "Additional details (Optional)"),
              Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOtherEmergencyBranch() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isTaglish
                ? "Ilarawan ang Sitwasyon"
                : "Describe Emergency Situation",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isTaglish
                ? "Pakilarawan nang detalyado ang emergency upang makapaghanda ang rescue team."
                : "Please describe the emergency in detail so the responders can prepare.",
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _detailsCtrl,
            maxLines: 4,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: _inputDecoration(
              widget.isTaglish
                  ? "Ilarawan ang emergency (Hal. live wire, bumagsak na pader)"
                  : "Describe emergency (e.g. fallen tree, live electrical wire)",
              Icons.emergency_rounded,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- STEP 2: Incident Location ---

  Widget _buildStep2Location() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isTaglish ? "Lokasyon ng Insidente" : "Incident Location",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isTaglish
                ? "Saan kailangan ipadala ang tulong o rescue?"
                : "Where does the emergency assistance need to be sent?",
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 28),
          DropdownButtonFormField<String>(
            initialValue: _selectedBarangay,
            dropdownColor: bgColor,
            style: TextStyle(color: textColor, fontSize: 15),
            decoration: _inputDecoration(
              widget.isTaglish ? "Pumili ng Barangay" : "Select Barangay",
              Icons.map_outlined,
            ),
            items: _marikinaBarangays
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() {
              _selectedBarangay = val;
              _validationMessage = null;
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _streetCtrl,
            style: TextStyle(color: textColor, fontSize: 15),
            decoration: _inputDecoration(
              widget.isTaglish
                  ? "Kalye o Landmark (Opsyonal)"
                  : "Street or Landmark (Optional)",
              Icons.streetview_rounded,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.gps_fixed_rounded, color: accentColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isTaglish
                        ? "Ang iyong GPS coordinates ay awtomatikong susuriin sa pag-kumpirma upang magabayan ang rescue team."
                        : "Your live GPS coordinates will be verified upon confirmation to guide the rescue team directly to you.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3: Confirmation Summary ---

  Widget _buildStep3Confirmation() {
    final detailsText = _detailsCtrl.text.trim();
    final streetText = _streetCtrl.text.trim();
    final locationText = streetText.isNotEmpty && (_selectedBarangay != null)
        ? "$streetText, $_selectedBarangay"
        : (_selectedBarangay ?? "Marikina City");

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isTaglish
                ? "Suriin at Kumpirmahin ang Ulat"
                : "Review & Confirm Help Request",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isTaglish
                ? "Pakisuri nang mabuti ang mga detalye bago ipadala ang kahilingan sa LGU."
                : "Please review your details carefully before sending this request to the LGU.",
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 20),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isDarkMode ? Colors.white12 : Colors.grey[200]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.medical_services_outlined,
                  widget.isTaglish ? "Uri ng Tulong" : "Help Type",
                  _helpType ?? "Emergency",
                  valueColor: emergencyColor,
                ),

                if (_helpType == 'Medical') ...[
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1)),
                  _buildSummaryRow(
                    Icons.healing_rounded,
                    widget.isTaglish ? "Kategorya" : "Category",
                    _medicalType ?? "Not specified",
                  ),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1)),
                  _buildSummaryRow(
                    Icons.crisis_alert_rounded,
                    widget.isTaglish ? "Urgency" : "Urgency",
                    _urgency ?? "Immediate",
                    valueColor: const Color(0xFFDC2626),
                  ),
                ],

                if (_helpType == 'Evacuation') ...[
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1)),
                  _buildSummaryRow(
                    Icons.directions_run_rounded,
                    widget.isTaglish ? "Dahilan" : "Reason",
                    _evacuationReason ?? "Evacuation",
                  ),
                  if (_waterLevel != null) ...[
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1)),
                    _buildSummaryRow(
                      Icons.waves_rounded,
                      widget.isTaglish ? "Antas ng Tubig" : "Water Level",
                      _waterLevel!,
                    ),
                  ],
                  if (_evacuationObstacle != null) ...[
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1)),
                    _buildSummaryRow(
                      Icons.block_rounded,
                      widget.isTaglish ? "Hadlang" : "Obstacle",
                      _evacuationObstacle!,
                    ),
                  ],
                  if (_vulnerablePerson != null) ...[
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1)),
                    _buildSummaryRow(
                      Icons.accessible_rounded,
                      widget.isTaglish ? "Nangangailangan" : "Vulnerable Person",
                      _vulnerablePerson!,
                    ),
                  ],
                ],

                if (detailsText.isNotEmpty) ...[
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1)),
                  _buildSummaryRow(
                    Icons.notes_rounded,
                    widget.isTaglish ? "Mga Detalye" : "Details",
                    detailsText,
                  ),
                ],

                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1)),
                _buildSummaryRow(
                  Icons.location_on_outlined,
                  widget.isTaglish ? "Lokasyon" : "Location",
                  locationText,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Legal Notice & Confirmation Checkbox
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreedToLegal,
                  activeColor: Colors.red,
                  onChanged: (val) => setState(() {
                    _agreedToLegal = val ?? false;
                    _validationMessage = null;
                  }),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.isTaglish
                          ? "Kinukumpirma ko na ito ay totoong emergency. Ang mga maling ulat ay mapaparusahan sa ilalim ng batas."
                          : "I confirm this is a genuine emergency. False reports delay rescue operations and are punishable under Philippine Law.",
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.red.shade300
                            : Colors.red.shade900,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelText: label,
      labelStyle: TextStyle(
        color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, color: accentColor, size: 22),
      ),
      filled: true,
      fillColor: cardColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: widget.isDarkMode ? Colors.white10 : Colors.transparent,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
    );
  }

  Widget _buildSelectionCard(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap, {
    Color? activeColor,
  }) {
    final color = activeColor ?? accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (widget.isDarkMode ? Colors.white10 : Colors.transparent),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : subTextColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : textColor,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: subTextColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: subTextColor, fontSize: 13.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}
