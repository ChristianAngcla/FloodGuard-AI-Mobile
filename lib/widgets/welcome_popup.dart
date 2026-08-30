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
    // Informational copy must remain readable for older users in both themes.
    final subTextColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);
    final brandColor =
        isDarkMode ? const Color(0xFF7DD3FC) : const Color(0xFF3784DF);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(16),
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
            Image.asset(
              'assets/new_logo_nobg.png',
              width: 72,
              height: 72,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 12),

            Text(
              isTaglish ? "Maligayang Pagdating!" : "Welcome to FloodGuard",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: brandColor,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isTaglish
                          ? "Gumagamit ang FloodGuard ng PAGASA rainfall at river-level readings, kasama ang OLS forecasting, upang ipakita ang panganib sa baha sa Marikina: Safe, Alert, Warning, o Critical."
                          : "FloodGuard uses PAGASA rainfall and river-level readings, with OLS forecasting, to show Marikina flood risk: Safe, Alert, Warning, or Critical.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: subTextColor,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Warning Section
                    if (warningTitle != null && warningBody != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
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
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    warningTitle!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isDarkMode
                                          ? const Color(0xFFFDBA74)
                                          : Colors.orange.shade900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              warningBody!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF7C2D12),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Legend Section
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDarkMode ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isTaglish
                                ? "Antas ng Baha (Legend)"
                                : "Flood Levels Legend",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildCompactLegendItem(
                            const Color(0xFFD32F2F),
                            isTaglish
                                ? "3RD ALARM — LUMIKAS"
                                : "3RD ALARM — EVACUATE",
                            "≥ 18m",
                            isDarkMode,
                          ),
                          _buildCompactLegendItem(
                            const Color(0xFFFF9800),
                            isTaglish
                                ? "2ND ALARM — MAGHANDA"
                                : "2ND ALARM — PREPARE",
                            "≥ 16m",
                            isDarkMode,
                          ),
                          _buildCompactLegendItem(
                            const Color(0xFFFBC02D),
                            isTaglish
                                ? "1ST ALARM — ALERTO"
                                : "1ST ALARM — ALERT",
                            "≥ 15m",
                            isDarkMode,
                          ),
                          _buildCompactLegendItem(
                            const Color(0xFF4CAF50),
                            isTaglish ? "NORMAL — LIGTAS" : "NORMAL — SAFE",
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

            const SizedBox(height: 12),

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
                    fontSize: 17,
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

  Widget _buildCompactLegendItem(
      Color color, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
