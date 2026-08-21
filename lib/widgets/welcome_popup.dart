import 'package:flutter/material.dart';

class WelcomePopup extends StatelessWidget {
  final bool isTaglish;
  final bool isDarkMode;
  final VoidCallback onOpenFloodMap;
  final String? warningTitle;
  final String? warningBody;

  const WelcomePopup({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
    required this.onOpenFloodMap,
    this.warningTitle,
    this.warningBody,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF1A2B3C) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A2B3C);
    // Informational copy must remain readable on the white welcome card.
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color:
                    isDarkMode ? Colors.black54 : Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              // Inner highlight glow
              BoxShadow(
                color: Colors.white.withValues(alpha: isDarkMode ? 0.05 : 0.6),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Logo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF3784DF).withValues(alpha: 0.15)
                    : Colors.blue.shade50,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3784DF).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/new_logo_nobg.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              isTaglish ? "Maligayang Pagdating!" : "Welcome to FloodGuard",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3784DF),
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 12),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isTaglish
                          ? "Ang sistema ay nagpo-forecast at nagvi-visualize ng flood hazards sa Marikina City gamit ang Ordinary Least Squares (OLS) Multiple Linear Regression batay sa PAGASA-reported telemetry: telemetered rainfall mula sa upstream stations at antas ng tubig ng ilog. Ipinapakita ito bilang color-coded risk map (Safe, Alert, Warning, Critical) para sa preparedness at mitigation."
                          : "The system forecasts and visualizes flood hazards in Marikina City using Ordinary Least Squares (OLS) Multiple Linear Regression based on PAGASA-reported telemetry: telemetered upstream rainfall and river water levels. It displays a color-coded risk map (Safe, Alert, Warning, Critical) to support disaster preparedness and mitigation.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: subTextColor,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Warning Section
                    if (warningTitle != null && warningBody != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.orange.withValues(alpha: 0.15)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isDarkMode
                                  ? Colors.orange.withValues(alpha: 0.5)
                                  : const Color(0xFFFFCC80),
                              width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    warningTitle!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isDarkMode
                                          ? Colors.orangeAccent
                                          : Colors.orange.shade900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              warningBody!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.orange.shade200
                                    : Colors.orange.shade900,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Legend Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isTaglish
                                ? "Antas ng Baha (Legend)"
                                : "Flood Levels Legend",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLegendItem(
                            const Color(0xFFD32F2F),
                            isTaglish
                                ? "3rd Alarm (FORCE EVACUATION)"
                                : "3rd ALARM (FORCE EVACUATION)",
                            "≥ 18m",
                            isDarkMode,
                          ),
                          _buildLegendItem(
                            const Color(0xFFFF9800),
                            isTaglish
                                ? "2nd Alarm (PREPARE TO EVACUATE)"
                                : "2nd ALARM (PREPARE TO EVACUATE)",
                            "≥ 16m",
                            isDarkMode,
                          ),
                          _buildLegendItem(
                            const Color(0xFFFBC02D),
                            isTaglish
                                ? "1st Alarm (ALERT)"
                                : "1st ALARM (ALERT)",
                            "≥ 15m",
                            isDarkMode,
                          ),
                          _buildLegendItem(
                            const Color(0xFF4CAF50),
                            isTaglish ? "Normal (SAFE)" : "NORMAL (SAFE)",
                            "< 15m",
                            isDarkMode,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // FLOOD MAP BUTTON (Glowing)
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3784DF), Color(0xFF2BA7A0)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3784DF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onOpenFloodMap,
                icon: const Icon(Icons.explore_rounded, color: Colors.white),
                label: Text(
                  isTaglish ? "Tingnan ang Flood Map" : "Explore Flood Map",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildLegendItem(
      Color color, String label, String value, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
