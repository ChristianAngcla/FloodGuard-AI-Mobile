import 'package:flutter/material.dart';
import 'dart:ui';

class FloodLegendCard extends StatelessWidget {
  final bool isDarkMode;
  final bool isTaglish;
  final bool isExpanded;
  final VoidCallback onToggle;

  const FloodLegendCard({
    super.key,
    required this.isDarkMode,
    required this.isTaglish,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isExpanded
          ? 'Flood risk levels legend. Double tap to collapse.'
          : 'Flood risk levels legend. Double tap to expand.',
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              // Colored glowing shadow
              BoxShadow(
                color: isDarkMode
                    ? Colors.black54
                    : const Color(0xFF3784DF).withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              // Inner top highlight glow
              BoxShadow(
                color: Colors.white.withValues(alpha: isDarkMode ? 0.05 : 0.6),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isExpanded ? 340 : 180,
                constraints: const BoxConstraints(minHeight: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1A2B3C).withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: isExpanded ? _buildExpanded() : _buildCollapsed(),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          color: isDarkMode ? Colors.white : const Color(0xFF0D47A1),
          size: 18,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isTaglish ? "Antas ng Panganib" : "Flood Risk Levels",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF0D47A1),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isTaglish ? "Antas ng Panganib sa Baha" : "Flood Risk Levels",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.info_outline,
              size: 16,
              color: isDarkMode ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _legendRiskRow(
          const Color(0xFFDC2626),
          "CRITICAL",
          isTaglish ? "Kritikal na panganib sa baha." : "Critical flood risk predicted.",
          isTaglish
              ? "Unahin ang kaligtasan; sundin ang abiso ng LGU."
              : "Prioritize safety; follow LGU orders.",
        ),
        _legendRiskRow(
          const Color(0xFFEA580C),
          "ALARM",
          isTaglish ? "Mas mataas na panganib sa baha." : "Higher flood risk predicted.",
          isTaglish
              ? "Maghanda sa paglikas kung kinakailangan."
              : "Prepare for worsening conditions.",
        ),
        _legendRiskRow(
          const Color(0xFFD97706),
          "ALERT",
          isTaglish ? "Paunang babala sa pagbaha." : "Early flood warning.",
          isTaglish
              ? "Manatiling alerto at magbantay ng ulat."
              : "Stay aware of changing conditions.",
        ),
        _legendRiskRow(
          const Color(0xFF16A34A),
          "SAFE",
          isTaglish ? "Mababa o walang banta sa ngayon." : "Little to no immediate flood concern.",
          isTaglish
              ? "Ipagpatuloy ang pagsubaybay sa updates."
              : "Continue monitoring updates.",
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isTaglish
                ? "Iba-iba ang alert thresholds ng bawat istasyon (Sto. Niño, Nangka, Tumana). Mag-tap ng barangay para sa tiyak na datos."
                : "Station thresholds vary (Sto. Niño, Nangka, Tumana). Tap any barangay on the map for station-specific thresholds.",
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendRiskRow(Color color, String level, String meaning, String action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDarkMode ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      level,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        meaning,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
