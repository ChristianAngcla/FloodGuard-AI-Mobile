import 'package:flutter/material.dart';
import '../services/flood_api_service.dart';
import '../utils/station_thresholds.dart';
import '../widgets/flood_warning_scale.dart';

/// Bottom sheet showing FloodGuard DailyForecast for the selected barangay,
/// structured to clearly communicate:
/// PREDICTED BARANGAY FLOOD RISK
/// → WHAT THE RISK MEANS
/// → ACTIONABLE FLOOD INFORMATION
/// → SUPPORTING PREDICTED WATER LEVEL / STATION INFORMATION
class BarangayDetailsSheet extends StatefulWidget {
  final String barangayName;
  final bool isTaglish;
  final bool isDarkMode;

  const BarangayDetailsSheet({
    super.key,
    required this.barangayName,
    required this.isTaglish,
    required this.isDarkMode,
  });

  @override
  State<BarangayDetailsSheet> createState() => _BarangayDetailsSheetState();
}

class _BarangayDetailsSheetState extends State<BarangayDetailsSheet> {
  late String _selectedBarangay;

  String get _sensorKey =>
      FloodApiService.barangayToSensor[_selectedBarangay] ?? 'sto_nino';

  String get _sensorDisplayName =>
      FloodApiService.sensorDisplayNames[_sensorKey] ?? 'Unknown River';

  @override
  void initState() {
    super.initState();
    _selectedBarangay = widget.barangayName;
    FloodApiService.fetchDailyForecasts().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subColor = widget.isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final barangays = FloodApiService.barangayToSensor.keys.toList()..sort();

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 550,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Material(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    Text(
                      widget.isTaglish
                          ? 'Pagsusuri ng Panganib sa Baha'
                          : 'Flood Risk Assessment',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Barangay Selector Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? const Color(0xFF253B50)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isDarkMode
                              ? Colors.white12
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedBarangay,
                          dropdownColor: widget.isDarkMode
                              ? const Color(0xFF253B50)
                              : Colors.white,
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: subColor),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          items: barangays
                              .map((name) => DropdownMenuItem(
                                  value: name, child: Text(name)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedBarangay = value);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Monitoring Station Indicator
                    Row(
                      children: [
                        Icon(
                          Icons.sensors_rounded,
                          size: 16,
                          color: widget.isDarkMode
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFF0369A1),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${widget.isTaglish ? 'Sensor' : 'Station'}: $_sensorDisplayName',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: subColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Risk-First Content Card
                    _buildForecastAssessmentCard(textColor, subColor),

                    if (FloodApiService.getDailyForecastForBarangay(_selectedBarangay)?.predictedWaterLevel != null) ...[
                      const SizedBox(height: 14),
                      _buildScopeDisclaimer(),
                    ],

                    const SizedBox(height: 16),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isDarkMode
                              ? const Color(0xFF3784DF)
                              : const Color(0xFFF1F5F9),
                          foregroundColor: widget.isDarkMode
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          widget.isTaglish ? 'Isara' : 'Close',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForecastAssessmentCard(Color textColor, Color subColor) {
    final daily =
        FloodApiService.getDailyForecastForBarangay(_selectedBarangay);

    if (daily == null ||
        daily.isUnavailable ||
        daily.predictedWaterLevel == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF253B50) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDarkMode ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isTaglish
                        ? 'Hindi available ang pagtataya'
                        : 'Forecast unavailable',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            if (daily?.fallbackReason != null &&
                daily!.fallbackReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                daily.fallbackReason!,
                style: TextStyle(
                  fontSize: 13,
                  color: subColor,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final status = daily.statusBand.trim().toUpperCase();
    final riskInfo = _resolveRiskInfo(status);
    final waterLevel = daily.predictedWaterLevel!;
    final thr = StationThresholds.forSensor(_sensorKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. PREDICTED BARANGAY FLOOD RISK BANNER
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: riskInfo.color.withValues(alpha: widget.isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: riskInfo.color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(riskInfo.icon, color: riskInfo.color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isTaglish ? 'ANTAS NG PANGANIB' : 'PREDICTED FLOOD RISK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.05,
                            color: riskInfo.color,
                          ),
                        ),
                        Text(
                          riskInfo.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. WHAT THIS MEANS CARD
        _contentCard(
          title: widget.isTaglish ? 'ANO ANG IBIG SABIHIN NITO' : 'WHAT THIS MEANS',
          icon: Icons.lightbulb_outline_rounded,
          iconColor: const Color(0xFF0284C7),
          child: Text(
            riskInfo.meaning,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 1.45,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 3. RECOMMENDED ACTION CARD
        _contentCard(
          title: widget.isTaglish ? 'INIREREKOMENDANG AKSYON' : 'RECOMMENDED ACTION',
          icon: Icons.campaign_outlined,
          iconColor: riskInfo.color,
          child: Text(
            riskInfo.action,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
              height: 1.45,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 4. FLOOD PREDICTION DETAILS
        _contentCard(
          title: widget.isTaglish ? 'MGA DETALYE NG PAGTATAYA NG BAHA' : 'FLOOD PREDICTION DETAILS',
          icon: Icons.water_drop_outlined,
          iconColor: const Color(0xFF0284C7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Predicted Flood Risk (prominent visual priority)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isTaglish
                        ? 'Pagtatayang Panganib sa Baha:'
                        : 'Predicted Flood Risk:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: subColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskInfo.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: riskInfo.color, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: riskInfo.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: riskInfo.color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Predicted Water Level (24px bold)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.isTaglish
                        ? 'Tinatayang Lebel ng Tubig:'
                        : 'Predicted Water Level:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: subColor,
                    ),
                  ),
                  Text(
                    '${waterLevel.toStringAsFixed(2)} m',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: riskInfo.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 3. Monitoring Station (clearly shown)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isTaglish
                        ? 'Istasyon ng Pagsubaybay:'
                        : 'Monitoring Station:',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                    ),
                  ),
                  Text(
                    _sensorDisplayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 4. Forecast Date
              if (daily.forecastTargetDate.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isTaglish
                          ? 'Petsa ng Pagtataya:'
                          : 'Forecast Date:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                    Text(
                      daily.forecastTargetDate,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // 5. Secondary details: Calculation Mode & observations
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isTaglish ? 'Paraan ng Pagkalkula:' : 'Calculation Mode:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: subColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: daily.calculationMode == 'primary_model'
                          ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                          : const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      daily.calculationMode == 'primary_model'
                          ? 'PRIMARY MODEL'
                          : (daily.calculationMode == 'persistence_fallback'
                              ? 'PERSISTENCE'
                              : 'ESTIMATED'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: daily.calculationMode == 'primary_model'
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
              if (daily.sourceDataDate != null && daily.sourceDataDate!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.isTaglish
                      ? 'Batay sa datos ng: ${daily.sourceDataDate}'
                      : 'Based on observations from: ${daily.sourceDataDate}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subColor),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 5. WHY IS THIS THE FLOOD RISK? (FLOOD WARNING SCALE)
        _contentCard(
          title: widget.isTaglish ? 'BAKIT ITO ANG ANTAS NG PANGANIB?' : 'WHY IS THIS THE FLOOD RISK?',
          icon: Icons.stacked_bar_chart_rounded,
          iconColor: const Color(0xFF0284C7),
          child: FloodWarningScale(
            predictedLevel: waterLevel,
            thresholds: thr,
            status: status,
            stationName: _sensorDisplayName,
            isDarkMode: widget.isDarkMode,
            isTaglish: widget.isTaglish,
          ),
        ),
      ],
    );
  }

  Widget _buildScopeDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: widget.isDarkMode ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isTaglish
                  ? 'Ipinapakita ng FloodGuard ang inaasahang panganib sa baha para sa barangay. Hindi nito ipinapakita kung aling mga kalye o bahay ang tiyak na babahain o kung gaano kalalim ang tubig-baha.'
                  : 'FloodGuard shows the predicted flood risk for the barangay. It does not show exactly which streets or houses will flood or how deep the floodwater will be.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: widget.isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF253B50)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white12 : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.04,
                  color: widget.isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  _RiskLevelInfo _resolveRiskInfo(String status) {
    if (widget.isTaglish) {
      switch (status) {
        case 'CRITICAL':
          return _RiskLevelInfo(
            title: 'CRITICAL (Kritikal na Panganib)',
            color: const Color(0xFFDC2626),
            icon: Icons.report_problem_rounded,
            meaning: 'Napakataas at mapanganib na antas ng tubig sa ilog. Matinding banta ng malawakang pagbaha sa mga apektadong lugar.',
            action: 'Unahin ang kaligtasan. Lumikas agad sa evacuation center kung inatasan ng Marikina LGU / DRRMO.',
          );
        case 'ALARM':
        case 'WARNING':
          return _RiskLevelInfo(
            title: 'ALARM (Mataas na Panganib)',
            color: const Color(0xFFEA580C),
            icon: Icons.warning_amber_rounded,
            meaning: 'Inaasahan ang mabilis na pagtaas ng tubig sa ilog. Posible ang pagbaha sa mabababang lugar at malapit sa ilog.',
            action: 'Ihanda ang emergency grab bag, i-charge ang cellphone, at maging handa sa paglikas kung iutos ng pamahalaan.',
          );
        case 'ALERT':
          return _RiskLevelInfo(
            title: 'ALERT (Paunang Babala sa Baha)',
            color: const Color(0xFFD97706),
            icon: Icons.info_outline,
            meaning: 'Lumalapit na ang tubig sa alert level. Maaaring magsimula ang pag-ipon ng tubig sa mabababang lugar.',
            action: 'Maging alerto, itaas ang mahahalagang gamit, at alamin ang ligtas na daan patungong evacuation center.',
          );
        default:
          return _RiskLevelInfo(
            title: 'SAFE (Mababang Panganib)',
            color: const Color(0xFF16A34A),
            icon: Icons.check_circle_outline,
            meaning: 'Ligtas ang antas ng tubig sa ilog sa barangay na ito sa kasalukuyan.',
            action: 'Patuloy na subaybayan ang mga anunsyo at balita sa lagay ng panahon.',
          );
      }
    } else {
      switch (status) {
        case 'CRITICAL':
          return _RiskLevelInfo(
            title: 'CRITICAL: Dangerous Flood Risk',
            color: const Color(0xFFDC2626),
            icon: Icons.report_problem_rounded,
            meaning: 'Dangerous river levels predicted. High risk of severe flooding in vulnerable areas.',
            action: 'Prioritize safety and follow emergency or evacuation instructions from local authorities.',
          );
        case 'ALARM':
        case 'WARNING':
          return _RiskLevelInfo(
            title: 'ALARM: Higher Flood Risk',
            color: const Color(0xFFEA580C),
            icon: Icons.warning_amber_rounded,
            meaning: 'River water is rising fast. Flooding in low-lying and riverside areas is likely.',
            action: 'Prepare emergency grab bags, charge your devices, and be ready to evacuate if advised.',
          );
        case 'ALERT':
          return _RiskLevelInfo(
            title: 'ALERT: Early Flood Warning',
            color: const Color(0xFFD97706),
            icon: Icons.info_outline,
            meaning: 'River levels are rising toward warning levels. Water may start pooling in low-lying areas.',
            action: 'Stay alert, secure important belongings, and monitor official updates.',
          );
        default:
          return _RiskLevelInfo(
            title: 'SAFE: Low Flood Risk',
            color: const Color(0xFF16A34A),
            icon: Icons.check_circle_outline,
            meaning: 'River levels are currently safe. Flooding is not expected in this barangay at this time.',
            action: 'Stay updated with regular weather and river advisories.',
          );
      }
    }
  }
}

class _RiskLevelInfo {
  final String title;
  final Color color;
  final IconData icon;
  final String meaning;
  final String action;

  _RiskLevelInfo({
    required this.title,
    required this.color,
    required this.icon,
    required this.meaning,
    required this.action,
  });
}
