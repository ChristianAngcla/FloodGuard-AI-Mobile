import 'package:flutter/material.dart';
import '../services/flood_api_service.dart';

class _BadgeColor {
  final Color bg;
  final Color text;
  const _BadgeColor(this.bg, this.text);
}

_BadgeColor _classificationColors(String? classification, bool isDarkMode) {
  final c = (classification ?? '').toLowerCase();
  if (isDarkMode) {
    if (c.contains('super typhoon')) {
      return const _BadgeColor(Color(0xFF581C87), Color(0xFFF3E8FF));
    }
    if (c.contains('typhoon')) {
      return const _BadgeColor(Color(0xFF7F1D1D), Color(0xFFFEE2E2));
    }
    if (c.contains('severe tropical storm')) {
      return const _BadgeColor(Color(0xFF78350F), Color(0xFFFEF3C7));
    }
    if (c.contains('tropical storm')) {
      return const _BadgeColor(Color(0xFF0C4A6E), Color(0xFFE0F2FE));
    }
    if (c.contains('depression')) {
      return const _BadgeColor(Color(0xFF134E4A), Color(0xFFCCFBF1));
    }
    return const _BadgeColor(Color(0xFF0C4A6E), Color(0xFFE0F2FE));
  } else {
    if (c.contains('super typhoon')) {
      return const _BadgeColor(Color(0xFFFCE7F3), Color(0xFF9D174D));
    }
    if (c.contains('typhoon')) {
      return const _BadgeColor(Color(0xFFFEE2E2), Color(0xFFB91C1C));
    }
    if (c.contains('severe tropical storm')) {
      return const _BadgeColor(Color(0xFFFEF3C7), Color(0xFFB45309));
    }
    if (c.contains('tropical storm')) {
      return const _BadgeColor(Color(0xFFE0F2FE), Color(0xFF0369A1));
    }
    if (c.contains('depression')) {
      return const _BadgeColor(Color(0xFFCCFBF1), Color(0xFF0F766E));
    }
    return const _BadgeColor(Color(0xFFE0F2FE), Color(0xFF0369A1));
  }
}

/// 🌀 Official DOST-PAGASA Tropical Cyclone Status Card
/// Read-only display of official severe weather bulletin data matching visual mockup.
class TyphoonUpdateCard extends StatelessWidget {
  final TyphoonStatus? typhoonStatus;
  final bool isDarkMode;
  final bool isTaglish;

  const TyphoonUpdateCard({
    super.key,
    required this.typhoonStatus,
    required this.isDarkMode,
    required this.isTaglish,
  });

  @override
  Widget build(BuildContext context) {
    final status = typhoonStatus;
    final cardBg =
        isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor =
        isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0);
    final titleColor =
        isDarkMode ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
    final subColor =
        isDarkMode ? Colors.white70 : const Color(0xFF64748B);
    final textColor =
        isDarkMode ? Colors.white : const Color(0xFF0F172A);

    final subCardBg =
        isDarkMode ? const Color(0xFF253B50) : Colors.white;
    final subCardBorder =
        isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: Icon + TYPHOON UPDATE | DOST-PAGASA badge pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.cyclone_rounded,
                    size: 20,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTaglish ? 'ULAT SA BAGYO' : 'TYPHOON UPDATE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.04,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DOST-PAGASA',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.03,
                    color:
                        isDarkMode ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Body: Unavailable, Active (1 or multiple), or No Active
          if (status == null || status.isUnavailable) ...[
            Text(
              isTaglish
                  ? 'Pansamantalang hindi available ang impormasyon sa bagyo. Sumangguni sa PAGASA para sa pinakabagong ulat-panahon.'
                  : 'Typhoon information is temporarily unavailable. Check PAGASA for the latest weather updates.',
              style: TextStyle(
                fontSize: 13.5,
                color: subColor,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ] else if (status.hasActiveTyphoon) ...[
            // Active storms summary count
            Builder(builder: (context) {
              final count = status.activeCount > 0
                  ? status.activeCount
                  : (status.typhoons.isNotEmpty ? status.typhoons.length : 1);
              final summaryText = isTaglish
                  ? (count > 1
                      ? '$count aktibong bagyo sa loob ng Philippine Area of Responsibility.'
                      : '1 aktibong bagyo sa loob ng Philippine Area of Responsibility.')
                  : (count > 1
                      ? '$count active weather systems inside the Philippine Area of Responsibility.'
                      : '1 active weather system inside the Philippine Area of Responsibility.');

              return Text(
                summaryText,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.35,
                ),
              );
            }),
            const SizedBox(height: 12),

            // Sub-cards for each active storm
            Builder(builder: (context) {
              final storms = status.typhoons.isNotEmpty
                  ? status.typhoons
                  : [
                      TyphoonItem(
                        name: status.name ?? 'Tropical Cyclone',
                        displayName: status.name ?? 'Tropical Cyclone',
                        internationalName: status.internationalName,
                        classification: status.classification,
                        location: status.location,
                        movement: status.movement,
                        maximumWinds: status.maximumWinds,
                        gustiness: status.gustiness,
                        heavyRainInfo: status.heavyRainInfo,
                        updatedAt: status.updatedAt,
                      )
                    ];

              return Column(
                children: storms.map((storm) {
                  final badgeColors =
                      _classificationColors(storm.classification, isDarkMode);
                  final displayName = storm.displayName.isNotEmpty
                      ? storm.displayName
                      : (storm.name.isNotEmpty
                          ? storm.name
                          : 'Tropical Cyclone');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: subCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: subCardBorder, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sub-card top row: Storm Name & Classification badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                storm.internationalName != null &&
                                        storm.internationalName!.isNotEmpty
                                    ? '$displayName (${storm.internationalName})'
                                    : displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (storm.classification != null &&
                                storm.classification!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColors.bg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  storm.classification!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColors.text,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Divider(
                          height: 16,
                          thickness: 0.8,
                          color: isDarkMode
                              ? Colors.white10
                              : const Color(0xFFF1F5F9),
                        ),

                        // Key-Value rows (hidden if null/unavailable)
                        if (storm.maximumWinds != null &&
                            storm.maximumWinds!.isNotEmpty)
                          _detailRow(
                            label: isTaglish
                                ? 'Lakas ng Hangin:'
                                : 'Maximum Winds:',
                            value: storm.maximumWinds!,
                            textColor: textColor,
                            subColor: subColor,
                          ),
                        if (storm.gustiness != null &&
                            storm.gustiness!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _detailRow(
                            label:
                                isTaglish ? 'Bugso:' : 'Gustiness:',
                            value: storm.gustiness!,
                            textColor: textColor,
                            subColor: subColor,
                          ),
                        ],
                        if (storm.movement != null &&
                            storm.movement!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _detailRow(
                            label: isTaglish ? 'Pagkilos:' : 'Moving:',
                            value: storm.movement!,
                            textColor: textColor,
                            subColor: subColor,
                          ),
                        ],
                        if (storm.heavyRainInfo != null &&
                            storm.heavyRainInfo!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _detailRow(
                            label: isTaglish
                                ? 'Ulat sa Ulan:'
                                : 'Rain Information:',
                            value: storm.heavyRainInfo!,
                            textColor: textColor,
                            subColor: subColor,
                          ),
                        ],
                        if (storm.location != null &&
                            storm.location!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _detailRow(
                            label: isTaglish ? 'Lokasyon:' : 'Location:',
                            value: storm.location!,
                            textColor: textColor,
                            subColor: subColor,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            }),

            // Bottom timestamp
            if (status.updatedAt != null && status.updatedAt!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '${isTaglish ? 'Na-update' : 'Updated'}: ${status.updatedAt}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
            ],
          ] else ...[
            // No active typhoon
            Text(
              isTaglish
                  ? 'Walang aktibong bagyo sa loob ng Philippine Area of Responsibility sa kasalukuyan.'
                  : 'No active typhoon inside the Philippine Area of Responsibility at this time.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.45,
              ),
            ),
            if (status.updatedAt != null && status.updatedAt!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${isTaglish ? 'Na-update' : 'Updated'}: ${status.updatedAt}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    required Color textColor,
    required Color subColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: subColor,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// ⚠️ Weather / Typhoon Reminder Card (STAY UPDATED)
/// Displays cautionary reminder even when the flood risk is SAFE.
class StayUpdatedReminderCard extends StatelessWidget {
  final String status;
  final bool hasActiveTyphoon;
  final int activeCount;
  final bool isDarkMode;
  final bool isTaglish;

  const StayUpdatedReminderCard({
    super.key,
    required this.status,
    required this.hasActiveTyphoon,
    this.activeCount = 0,
    required this.isDarkMode,
    required this.isTaglish,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDarkMode
        ? const Color(0xFF062E1B)
        : const Color(0xFFF0FDF4);
    final borderColor = isDarkMode
        ? const Color(0xFF166534)
        : const Color(0xFFBBF7D0);
    final headerColor = isDarkMode
        ? const Color(0xFF7DD3FC)
        : const Color(0xFF0369A1);
    final bodyColor = isDarkMode
        ? const Color(0xFFDCFCE7)
        : const Color(0xFF14532D);

    final String message;
    if (isTaglish) {
      if (hasActiveTyphoon) {
        if (activeCount > 1) {
          message =
              'Araw-araw na flood forecast ang binibigay ng FloodGuard. May mga aktibong bagyo sa loob ng PAR ngayon, at ang ulan at antas ng ilog ay maaaring mabilis magbago. Patuloy na subaybayan ang mga anunsyo ng PAGASA at Marikina LGU at manatiling handa.';
        } else {
          message =
              'Araw-araw na flood forecast ang binibigay ng FloodGuard. May aktibong bagyo sa loob ng PAR ngayon, at ang ulan at antas ng ilog ay maaaring mabilis magbago. Patuloy na subaybayan ang mga anunsyo ng PAGASA at Marikina LGU at manatiling handa.';
        }
      } else {
        message =
            'Araw-araw na flood forecast ang binibigay ng FloodGuard. Ang biglaang malakas na ulan, flash flood, at lagay ng bagyo ay mabilis magbago. Kahit SAFE ang kasalukuyang forecast, patuloy na subaybayan ang mga anunsyo ng PAGASA at Marikina LGU at manatiling handa.';
      }
    } else {
      if (hasActiveTyphoon) {
        if (activeCount > 1) {
          message =
              'FloodGuard provides a day-to-day flood forecast. Active tropical cyclones are currently inside PAR, and rain and river conditions can change quickly. Keep checking PAGASA and Marikina LGU updates and stay prepared.';
        } else {
          message =
              'FloodGuard provides a day-to-day flood forecast. A tropical cyclone is currently inside PAR, and rain and river conditions can change quickly. Keep checking PAGASA and Marikina LGU updates and stay prepared.';
        }
      } else {
        message =
            'FloodGuard provides a day-to-day flood forecast. Sudden heavy rain, flash-flood conditions, and typhoon weather can change quickly. Even when the current forecast is SAFE, keep checking PAGASA and Marikina LGU updates and stay prepared.';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: headerColor,
              ),
              const SizedBox(width: 8),
              Text(
                isTaglish ? 'MANATILING LIGTAS AT ALERTO' : 'STAY UPDATED',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.04,
                  color: headerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: bodyColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
