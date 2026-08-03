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
    return GestureDetector(
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
                width: isExpanded ? 320 : 180,
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
    );
  }

  Widget _buildCollapsed() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.water, color: Colors.blue, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isTaglish ? "Antas ng Baha" : "Flood Level",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
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
      children: [
        Text(
          isTaglish ? "Antas ng Baha" : "Flood Levels",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        // Four-category legend matching new metrics
        _legendRow(
          const Color(0xFFD32F2F),
          isTaglish
              ? "3rd Alarm (FORCE EVACUATION)"
              : "3rd ALARM (FORCE EVACUATION)",
          "≥ 18m",
        ),
        _legendRow(
          const Color(0xFFFF9800),
          isTaglish
              ? "2nd Alarm (PREPARE TO EVACUATE)"
              : "2nd ALARM (PREPARE TO EVACUATE)",
          "≥ 16m",
        ),
        _legendRow(
          const Color(0xFFFBC02D),
          isTaglish ? "1st Alarm (ALERT)" : "1st ALARM (ALERT)",
          "≥ 15m",
        ),
        _legendRow(
          const Color(0xFF4CAF50),
          isTaglish ? "Normal (SAFE)" : "NORMAL (SAFE)",
          "< 15m",
        ),
      ],
    );
  }

  Widget _legendRow(Color color, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
