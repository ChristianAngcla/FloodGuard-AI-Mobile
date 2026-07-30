import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/flood_api_service.dart';
import '../services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MultistepReportSheet extends StatefulWidget {
  final bool isTaglish;
  final bool isDarkMode;
  final VoidCallback onSuccess;
  final VoidCallback onSafe;
  final VoidCallback onUnsafe;

  const MultistepReportSheet({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
    required this.onSuccess,
    required this.onSafe,
    required this.onUnsafe,
  });

  @override
  State<MultistepReportSheet> createState() => _MultistepReportSheetState();
}

class _MultistepReportSheetState extends State<MultistepReportSheet> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Form Data
  String? _selectedBarangay;
  final TextEditingController _streetCtrl = TextEditingController();
  bool? _isRaining;
  String? _floodLevel;
  bool? _isSafe;
  String? _helpNeeded;
  bool _agreedToLegal = false;
  bool _isSubmitting = false;

  // Theme Colors
  Color get bgColor =>
      widget.isDarkMode ? const Color(0xFF1A2B3C) : Colors.white;
  Color get textColor =>
      widget.isDarkMode ? Colors.white : const Color(0xFF1A2B3C);
  Color get subTextColor =>
      widget.isDarkMode ? Colors.white70 : Colors.grey[600]!;
  Color get cardColor =>
      widget.isDarkMode ? const Color(0xFF253B50) : const Color(0xFFF8F9FA);
  Color get accentColor => const Color(0xFF3784DF);

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
  void dispose() {
    _pageController.dispose();
    _streetCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Validation
    if (_currentStep == 0 && _selectedBarangay == null) {
      _showError(widget.isTaglish
          ? "Pakipili ang iyong Barangay"
          : "Please select a Barangay");
      return;
    }
    if (_currentStep == 1 && (_isRaining == null || _floodLevel == null)) {
      _showError(widget.isTaglish
          ? "Pakisagot ang lahat ng tanong"
          : "Please answer all questions");
      return;
    }
    if (_currentStep == 2 && _isSafe == null) {
      _showError(widget.isTaglish
          ? "Pakisabi kung ikaw ay ligtas"
          : "Please indicate if you are safe");
      return;
    }
    if (_currentStep == 3) {
      if (!_agreedToLegal) {
        _showError(widget.isTaglish ? "Kailangan mong sumang-ayon sa legal na babala" : "You must agree to the legal warning");
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    final uid = await AuthService().getEffectiveUid();
    final userUid = uid ?? "anonymous";
    final location = "${_streetCtrl.text.trim()}, $_selectedBarangay";

    // Load user profile to get name and phone
    String reporterName = 'Unknown Reporter';
    String reporterPhone = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // RATE LIMITING CHECK
      final lastReportStr = prefs.getString('last_report_time');
      if (lastReportStr != null) {
        final lastReport = DateTime.parse(lastReportStr);
        if (DateTime.now().difference(lastReport).inMinutes < 30) {
          setState(() => _isSubmitting = false);
          _showError(widget.isTaglish ? "Maaari ka lamang mag-submit ng isang ulat bawat 30 minuto." : "You can only submit one report every 30 minutes to prevent spam.");
          return;
        }
      }

      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        final firstName = userData['firstName'] ?? userData['first_name'] ?? '';
        final lastName = userData['lastName'] ?? userData['last_name'] ?? '';
        reporterName = '$firstName $lastName'.trim();
        if (reporterName.isEmpty) reporterName = 'Unknown Reporter';
        reporterPhone = userData['phone'] ?? '';
      }
      
      // PHONE VERIFICATION CHECK
      if (reporterPhone.isEmpty) {
        setState(() => _isSubmitting = false);
        _showError(widget.isTaglish ? "Kailangan ng verified na numero ng telepono sa profile para makapag-ulat." : "A verified phone number in your profile is required to ask for help.");
        return;
      }

    } catch (e) {
      debugPrint('Could not load user profile for report: $e');
    }

    // SENSOR CROSS-CHECKING (LOCALIZED)
    String reportStatus = 'pending';
    if (_selectedBarangay != null) {
      final floodData = await FloodApiService.getBarangayFloodData(_selectedBarangay!);
      if (floodData != null && floodData.riskLevel >= 40) {
        reportStatus = 'verified'; // Auto-verify if AI risk >= 40%
      }
    }

    double? lat;
    double? lng;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          lat = position.latitude;
          lng = position.longitude;
        }
      }
    } catch (e) {
      debugPrint("Could not fetch location for report: $e");
    }

    final success = await FloodApiService.submitFloodReport(
      location: location,
      isRaining: _isRaining ?? false,
      isSafe: _isSafe ?? true,
      uid: userUid,
      floodDepth: _getFloodDepthInMeters(_floodLevel),
      floodLevel: _floodLevel ?? 'Unknown',
      reporterName: reporterName,
      reporterPhone: reporterPhone,
      latitude: lat,
      longitude: lng,
      status: reportStatus,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context); // Close the sheet
      if (success) {
        SharedPreferences.getInstance().then((p) => p.setString('last_report_time', DateTime.now().toIso8601String()));
        widget.onSuccess();
        if (_isSafe == false) {
          widget.onUnsafe();
        } else {
          widget.onSafe();
        }
      } else {
        _showError(widget.isTaglish
            ? "Nabigo ang pagpapadala ng ulat. Subukan muli."
            : "Failed to submit report. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                ? accentColor
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
                const SizedBox(height: 24),

                // Page Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable swipe
                    children: [
                      _buildStep0Location(),
                      _buildStep1Situation(),
                      _buildStep2Safety(),
                      _buildStep3Evidence(),
                      _buildStep4Summary(),
                    ],
                  ),
                ),

                // Bottom Controls
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: bgColor.withValues(alpha: 0.0), // Transparent here
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0) ...[
                        TextButton(
                          onPressed: _prevStep,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          child: Text(
                            widget.isTaglish ? "Bumalik" : "Back",
                            style: TextStyle(
                                color: subTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: _buildGradientButton(
                          onPressed: _isSubmitting
                              ? null
                              : (_currentStep == _totalSteps - 1
                                  ? _submitReport
                                  : _nextStep),
                          isSubmit: _currentStep == _totalSteps - 1,
                          isSubmitting: _isSubmitting,
                          text: _currentStep == _totalSteps - 1
                              ? (widget.isTaglish
                                  ? "I-submit"
                                  : "Submit Report")
                              : (widget.isTaglish ? "Susunod" : "Next"),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    required bool isSubmit,
    required bool isSubmitting,
    required String text,
  }) {
    final buttonColor = isSubmit ? const Color(0xFFE53935) : accentColor;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [buttonColor.withValues(alpha: 0.8), buttonColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withValues(alpha: 0.4),
            blurRadius: 12,
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
                width: 24,
                height: 24,
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

  // --- STEPS ---

  Widget _buildStep0Location() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isTaglish ? "Lokasyon ng Insidente" : "Incident Location",
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(
              widget.isTaglish
                  ? "Saan nagaganap ang pagbaha?"
                  : "Where is the incident happening?",
              style: TextStyle(fontSize: 14, color: subTextColor)),
          const SizedBox(height: 32),
          DropdownButtonFormField<String>(
            initialValue: _selectedBarangay,
            dropdownColor: bgColor,
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: _inputDecoration(
                widget.isTaglish ? "Pumili ng Barangay" : "Select Barangay",
                Icons.map_outlined),
            items: _marikinaBarangays
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _selectedBarangay = val),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _streetCtrl,
            style: TextStyle(color: textColor),
            decoration: _inputDecoration(
                widget.isTaglish
                    ? "Kalye o Landmark (Opsyonal)"
                    : "Street or Landmark (Optional)",
                Icons.streetview_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Situation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              widget.isTaglish ? "Kasalukuyang Sitwasyon" : "Current Situation",
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 32),
          Text(
              widget.isTaglish
                  ? "Umuulan ba ngayon?"
                  : "Is it currently raining?",
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildSelectionCard(
                      widget.isTaglish ? "Oo" : "Yes",
                      Icons.water_drop_outlined,
                      _isRaining == true,
                      () => setState(() => _isRaining = true))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildSelectionCard(
                      widget.isTaglish ? "Hindi" : "No",
                      Icons.cloud_off_rounded,
                      _isRaining == false,
                      () => setState(() => _isRaining = false))),
            ],
          ),
          const SizedBox(height: 32),
          Text(
              widget.isTaglish
                  ? "Gaano kataas ang baha?"
                  : "Estimated Flood Level",
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          _buildSelectionCard(
              widget.isTaglish ? "Walang Baha" : "No Flood",
              Icons.do_not_disturb_alt_rounded,
              _floodLevel == "None",
              () => setState(() => _floodLevel = "None")),
          const SizedBox(height: 8),
          _buildSelectionCard(
              widget.isTaglish
                  ? "Hanggang Binti (<= 0.45m)"
                  : "Below Knee (<= 0.45m)",
              Icons.waves_rounded,
              _floodLevel == "Below Knee",
              () => setState(() => _floodLevel = "Below Knee")),
          const SizedBox(height: 8),
          _buildSelectionCard(
              widget.isTaglish
                  ? "Hanggang Tuhod (0.45m - 0.60m)"
                  : "Knee Level (0.45m - 0.60m)",
              Icons.waves_rounded,
              _floodLevel == "Knee Level",
              () => setState(() => _floodLevel = "Knee Level")),
          const SizedBox(height: 8),
          _buildSelectionCard(
              widget.isTaglish
                  ? "Hanggang Baywang (0.60m - 1.10m)"
                  : "Waist Level (0.60m - 1.10m)",
              Icons.waves_rounded,
              _floodLevel == "Waist Level",
              () => setState(() => _floodLevel = "Waist Level")),
          const SizedBox(height: 8),
          _buildSelectionCard(
              widget.isTaglish
                  ? "Hanggang Ulo (1.10m - 1.75m)"
                  : "Head Level (1.10m - 1.75m)",
              Icons.warning_amber_rounded,
              _floodLevel == "Head Level",
              () => setState(() => _floodLevel = "Head Level"),
              activeColor: Colors.orange),
          const SizedBox(height: 8),
          _buildSelectionCard(
              widget.isTaglish
                  ? "Lagpas Ulo (> 1.75m)"
                  : "Above Head (> 1.75m)",
              Icons.warning_rounded,
              _floodLevel == "Above Head",
              () => setState(() => _floodLevel = "Above Head"),
              activeColor: Colors.red),
        ],
      ),
    );
  }

  Widget _buildStep2Safety() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isTaglish ? "Iyong Kaligtasan" : "Your Safety",
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(
              widget.isTaglish
                  ? "Kailangan namin malaman kung ligtas ka."
                  : "Help us ensure you're out of danger.",
              style: TextStyle(fontSize: 14, color: subTextColor)),
          const SizedBox(height: 32),
          Text(
              widget.isTaglish
                  ? "Nasa ligtas ka bang lugar ngayon?"
                  : "Are you currently in a safe location?",
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 16),
          _buildSelectionCard(
              widget.isTaglish ? "Oo, ligtas ako" : "Yes, I am safe",
              Icons.health_and_safety_rounded,
              _isSafe == true,
              () => setState(() => _isSafe = true),
              activeColor: Colors.green),
          const SizedBox(height: 12),
          _buildSelectionCard(
              widget.isTaglish
                  ? "Hindi, kailangan ko ng tulong"
                  : "No, I need assistance",
              Icons.emergency_share_rounded,
              _isSafe == false,
              () => setState(() => _isSafe = false),
              activeColor: const Color(0xFFE53935)),
        ],
      ),
    );
  }

  Widget _buildStep3Evidence() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isTaglish ? "Uri ng Tulong (Opsyonal)" : "Kind of Help Needed",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(widget.isTaglish ? "Anong klaseng tulong ang kailangan ninyo?" : "What kind of assistance do you require?",
              style: TextStyle(fontSize: 14, color: subTextColor)),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _helpNeeded,
            dropdownColor: bgColor,
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: _inputDecoration(
                widget.isTaglish ? "Pumili ng tulong" : "Select help needed",
                Icons.medical_services_outlined),
            items: [
              "Immediate Rescue / Evacuation",
              "Medical Assistance",
              "Food and Water",
              "Relief Goods"
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => _helpNeeded = val),
          ),
          const SizedBox(height: 32),
          // Legal Warning
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5))
              ),
              child: Row(
                  children: [
                      Checkbox(
                          value: _agreedToLegal,
                          activeColor: Colors.red,
                          onChanged: (val) => setState(() => _agreedToLegal = val ?? false)
                      ),
                      Expanded(
                          child: Text(
                              widget.isTaglish ? "Kinukumpirma ko na ito ay totoong emergency. Ang mga maling ulat ay mapaparusahan sa ilalim ng batas." : "I confirm this is a real emergency. False reports delay rescue operations and are punishable under Philippine Law.",
                              style: TextStyle(color: widget.isDarkMode ? Colors.red.shade300 : Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.w600)
                          )
                      )
                  ]
              )
          )
        ],
      )
    );
  }

  Widget _buildStep4Summary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isTaglish ? "Buod ng Request" : "Request Summary",
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(
              widget.isTaglish
                  ? "Paki-check kung tama ang mga detalye."
                  : "Please review your report before submitting.",
              style: TextStyle(fontSize: 14, color: subTextColor)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      widget.isDarkMode ? Colors.white10 : Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                    Icons.location_on_outlined,
                    widget.isTaglish ? "Lokasyon" : "Location",
                    "${_streetCtrl.text.isNotEmpty ? '${_streetCtrl.text}, ' : ''}${_selectedBarangay ?? ''}"),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1)),
                _buildSummaryRow(
                    Icons.water_drop_outlined,
                    widget.isTaglish ? "Umuulan" : "Raining",
                    _isRaining == true ? "Yes" : "No"),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1)),
                _buildSummaryRow(
                    Icons.waves_rounded,
                    widget.isTaglish ? "Baha" : "Flood Level",
                    _getFloodLevelDisplay()),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1)),
                _buildSummaryRow(
                    Icons.health_and_safety_outlined,
                    widget.isTaglish ? "Ligtas" : "Safety",
                    _isSafe == true ? "Safe" : "Needs Assistance",
                    valueColor: _isSafe == true ? Colors.green : Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      widget.isTaglish
                          ? "Sigurado ka bang gusto mo ipasa ang ulat na ito?"
                          : "Are you sure you want to submit this report?",
                      style: TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600))),
            ],
          )
        ],
      ),
    );
  }

  // --- UTILS ---

  double _getFloodDepthInMeters(String? selectedLevel) {
    switch (selectedLevel) {
      case 'Below Knee':
        return 0.45;
      case 'Knee Level':
        return 0.60;
      case 'Waist Level':
        return 1.10;
      case 'Head Level':
        return 1.75;
      case 'Above Head':
        return 2.50; // Representing > 1.75m
      default:
        return 0.0;
    }
  }

  String _getFloodLevelDisplay() {
    if (_floodLevel == null) return "";
    if (!widget.isTaglish) return _floodLevel!;
    switch (_floodLevel) {
      case 'None':
        return 'Walang Baha';
      case 'Below Knee':
        return 'Hanggang Binti';
      case 'Knee Level':
        return 'Hanggang Tuhod';
      case 'Waist Level':
        return 'Hanggang Baywang';
      case 'Head Level':
        return 'Hanggang Ulo';
      case 'Above Head':
        return 'Lagpas Ulo';
      default:
        return _floodLevel!;
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: subTextColor),
      prefixIcon: Icon(icon, color: accentColor),
      filled: true,
      fillColor: cardColor,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: widget.isDarkMode ? Colors.white10 : Colors.transparent)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentColor, width: 2)),
    );
  }

  Widget _buildSelectionCard(
      String label, IconData icon, bool isSelected, VoidCallback onTap,
      {Color? activeColor}) {
    final color = activeColor ?? accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? color
                  : (widget.isDarkMode ? Colors.white10 : Colors.transparent),
              width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : subTextColor),
            const SizedBox(width: 16),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : textColor,
                        fontSize: 15))),
            if (isSelected) Icon(Icons.check_circle_rounded, color: color)
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: subTextColor),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: subTextColor, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: valueColor ?? textColor,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ],
    );
  }
}
