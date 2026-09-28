import 'package:flutter/material.dart';
import '../services/flood_api_service.dart';

/// 🌀 Official DOST-PAGASA Tropical Cyclone Status Card
/// Read-only display of official severe weather bulletin data.
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
        isDarkMode ? const Color(0xFF253B50) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode ? Colors.white12 : const Color(0xFFCBD5E1);
    final titleColor =
        isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final subColor = isDarkMode ? Colors.white70 : const Color(0xFF475569);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cyclone_rounded,
                    size: 19,
                    color: status?.hasActiveTyphoon == true
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTaglish ? 'ULAT SA BAGYO' : 'TYPHOON UPDATE',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.04,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
          const SizedBox(height: 10),
          if (status == null || status.isUnavailable)
            Text(
              isTaglish
                  ? 'Pansamantalang hindi available ang impormasyon sa bagyo. Sumangguni sa PAGASA para sa pinakabagong ulat-panahon.'
                  : 'Typhoon information is temporarily unavailable. Check PAGASA for the latest weather updates.',
              style: TextStyle(
                fontSize: 13.5,
                color: subColor,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            )
          else if (status.hasActiveTyphoon) ...[
            _infoRow(
              label: isTaglish ? 'Pangalan:' : 'Typhoon:',
              value:
                  '${status.name ?? 'Tropical Cyclone'}${status.internationalName != null && status.internationalName!.isNotEmpty ? ' (${status.internationalName})' : ''}',
              textColor: textColor,
              subColor: subColor,
              isBold: true,
            ),
            if (status.classification != null) ...[
              const SizedBox(height: 6),
              _infoRow(
                label: isTaglish ? 'Lakas:' : 'Strength:',
                value: status.classification!,
                textColor: const Color(0xFFDC2626),
                subColor: subColor,
                isBold: true,
              ),
            ],
            if (status.location != null) ...[
              const SizedBox(height: 6),
              _infoRow(
                label: isTaglish ? 'Lokasyon:' : 'Location:',
                value: status.location!,
                textColor: textColor,
                subColor: subColor,
              ),
            ],
            if (status.maximumWinds != null) ...[
              const SizedBox(height: 6),
              _infoRow(
                label: isTaglish ? 'Lakas ng Hangin:' : 'Maximum Winds:',
                value: status.maximumWinds!,
                textColor: textColor,
                subColor: subColor,
              ),
            ],
            if (status.movement != null) ...[
              const SizedBox(height: 6),
              _infoRow(
                label: isTaglish ? 'Pagkilos:' : 'Moving:',
                value: status.movement!,
                textColor: textColor,
                subColor: subColor,
              ),
            ],
            if (status.heavyRainInfo != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF451A03)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFFB45309)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  status.heavyRainInfo!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFF92400E),
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (status.updatedAt != null) ...[
              const SizedBox(height: 8),
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
            if (status.updatedAt != null) ...[
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

  Widget _infoRow({
    required String label,
    required String value,
    required Color textColor,
    required Color subColor,
    bool isBold = false,
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
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// ⚠️ Weather / Typhoon Reminder Card
/// Displays concise cautionary reminder even when the flood risk is SAFE.
class StayUpdatedReminderCard extends StatelessWidget {
  final String status;
  final bool hasActiveTyphoon;
  final bool isDarkMode;
  final bool isTaglish;

  const StayUpdatedReminderCard({
    super.key,
    required this.status,
    required this.hasActiveTyphoon,
    required this.isDarkMode,
    required this.isTaglish,
  });

  @override
  Widget build(BuildContext context) {
    final isSafe = status.trim().toUpperCase() == 'SAFE';
    final cardBg = isDarkMode
        ? (isSafe ? const Color(0xFF062E1B) : const Color(0xFF253B50))
        : (isSafe ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC));
    final borderColor = isDarkMode
        ? (isSafe ? const Color(0xFF166534) : Colors.white12)
        : (isSafe ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1));
    final headerColor = isDarkMode
        ? (isSafe ? const Color(0xFF86EFAC) : const Color(0xFF7DD3FC))
        : (isSafe ? const Color(0xFF166534) : const Color(0xFF0369A1));
    final bodyColor = isDarkMode
        ? (isSafe ? const Color(0xFFDCFCE7) : Colors.white)
        : (isSafe ? const Color(0xFF14532D) : const Color(0xFF0F172A));

    final String message;
    if (isTaglish) {
      if (isSafe) {
        message =
            'Mababa ang tinatayang panganib sa baha ng FloodGuard para sa pagtatayang ito, ngunit maaaring magbago ang lagay ng panahon tuwing may bagyo o malakas na ulan. Patuloy na subaybayan ang mga anunsyo mula sa PAGASA at Marikina LGU.';
      } else if (hasActiveTyphoon) {
        message =
            'Kasalukuyang may bagyo sa loob ng Philippine Area of Responsibility. Maaaring magbago ang panganib sa baha habang kumikilos ang panahon. Patuloy na subaybayan ang mga anunsyo mula sa PAGASA at Marikina LGU.';
      } else {
        message =
            'Maaaring magbago ang panganib sa baha, lalo na tuwing may bagyo o malakas na ulan. Patuloy na subaybayan ang mga anunsyo mula sa PAGASA at Marikina LGU.';
      }
    } else {
      if (isSafe) {
        message =
            'FloodGuard predicts a low flood risk for this forecast, but conditions can still change during a typhoon or heavy rain. Keep checking PAGASA and LGU updates and stay prepared.';
      } else if (hasActiveTyphoon) {
        message =
            'A typhoon is currently inside the Philippine Area of Responsibility. Flood conditions may change as weather conditions develop. Keep checking PAGASA and LGU updates and stay prepared.';
      } else {
        message =
            'Flood conditions can change, especially during a typhoon or heavy rain. Keep checking PAGASA and LGU updates and stay prepared.';
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
                size: 17,
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
