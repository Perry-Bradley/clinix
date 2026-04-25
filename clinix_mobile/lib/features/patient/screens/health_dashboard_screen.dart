import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/health_metric_service.dart';
import '../services/activity_service.dart';
import 'heart_rate_measure_screen.dart';
import 'package:pedometer/pedometer.dart';

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

const _storage = FlutterSecureStorage();

class HealthDashboardScreen extends ConsumerStatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  ConsumerState<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends ConsumerState<HealthDashboardScreen> {
  int _stepGoal = 10000;
  bool _goalLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final savedGoal = await _storage.read(key: 'step_goal');
    if (mounted) {
      setState(() {
        _stepGoal = int.tryParse(savedGoal ?? '') ?? 10000;
        _goalLoaded = true;
      });
    }
  }

  Future<void> _saveGoal(int goal) async {
    setState(() => _stepGoal = goal);
    await _storage.write(key: 'step_goal', value: '$goal');
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final topPad = MediaQuery.of(context).padding.top;
    final summaryAsync = ref.watch(healthSummaryProvider);
    final goal = _goalLoaded ? _stepGoal : 10000;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.splashSlate900,
        onRefresh: () async {
          ref.invalidate(healthSummaryProvider);
          await ref.read(healthSummaryProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Simple header
            Padding(
              padding: EdgeInsets.fromLTRB(w * 0.06, topPad + w * 0.03, w * 0.06, w * 0.02),
              child: Row(children: [
                if (Navigator.of(context).canPop())
                  GestureDetector(
                    onTap: () { if (Navigator.of(context).canPop()) Navigator.pop(context); },
                    child: Container(
                      padding: EdgeInsets.all(w * 0.02),
                      margin: EdgeInsets.only(right: w * 0.03),
                      decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.splashSlate900, size: w * 0.045),
                    ),
                  ),
                Text('Health', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.055, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showGoalSettings(context),
                  child: Icon(Icons.tune_rounded, color: AppColors.grey400, size: w * 0.05),
                ),
              ]),
            ),

            // Steps row — live from pedometer
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: w * 0.03),
              child: StreamBuilder<StepCount>(
                stream: Pedometer.stepCountStream.handleError((_) {}),
                builder: (context, snapshot) {
                  final steps = snapshot.hasData ? snapshot.data!.steps : 0;
                  final progress = (steps / goal).clamp(0.0, 1.0);
                  return Container(
                    padding: EdgeInsets.all(w * 0.04),
                    decoration: BoxDecoration(
                      color: AppColors.splashSlate900,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: w * 0.14,
                          height: w * 0.14,
                          child: Stack(alignment: Alignment.center, children: [
                            SizedBox(
                              width: w * 0.13,
                              height: w * 0.13,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: w * 0.012,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            Icon(Icons.directions_walk_rounded, color: Colors.white, size: w * 0.05),
                          ]),
                        ),
                        SizedBox(width: w * 0.035),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$steps steps', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w800, color: Colors.white)),
                            Text('of $goal goal · ${(progress * 100).toInt()}%', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: Colors.white54)),
                          ]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: w * 0.05),

            // Measure heart rate CTA
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeartRateMeasureScreen())),
                child: Container(
                  padding: EdgeInsets.all(w * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(w * 0.03),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.favorite_rounded, color: const Color(0xFFEF4444), size: w * 0.06),
                      ),
                      SizedBox(width: w * 0.035),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Measure Heart Rate', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                            Text('Use your camera to scan vitals', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: AppColors.grey400)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.grey400, size: w * 0.04),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: w * 0.05),

            // Vitals + chart
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06),
              child: summaryAsync.when(
                loading: () => SizedBox(height: w * 0.3, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.splashSlate900))),
                error: (e, _) => _buildErrorCard(),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVitalsGrid(context, data),
                    SizedBox(height: w * 0.05),
                    _buildActivityChart(data),
                  ],
                ),
              ),
            ),
            SizedBox(height: w * 0.15),
          ],
        ),
      ),
    );
  }


  void _showGoalSettings(BuildContext context) {
    int tempStepGoal = _stepGoal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(100)))),
                  const SizedBox(height: 20),
                  Text('Set Daily Step Goal', style: AppTextStyles.headlineSmall.copyWith(fontSize: 18)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      IconButton(
                        onPressed: tempStepGoal > 1000 ? () => setLocal(() => tempStepGoal -= 1000) : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: AppColors.sky500,
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14)),
                          child: Center(child: Text('$tempStepGoal steps', style: AppTextStyles.headlineSmall.copyWith(fontSize: 18, color: AppColors.darkBlue900))),
                        ),
                      ),
                      IconButton(
                        onPressed: tempStepGoal < 50000 ? () => setLocal(() => tempStepGoal += 1000) : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        color: AppColors.sky500,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        _saveGoal(tempStepGoal);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Step goal saved'), backgroundColor: AppColors.accentGreen),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sky500,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Save', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.cloud_off_rounded, color: AppColors.accentOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Could not load vitals', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Pull down to retry', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(healthSummaryProvider),
            child: Text('Retry', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsGrid(BuildContext context, Map<String, dynamic>? data) {
    final heartRate = data?['latest_heart_rate']?['bpm'];
    // Distance: server steps + local session steps
    final backendDist = data?['today_activity'] != null ? _asDouble(data!['today_activity']['distance_km']) : 0.0;
    final backendSteps = _asDouble(data?['today_activity']?['steps']);
    final liveSteps = ref.watch(stepCountProvider).value?.toDouble() ?? 0;
    final totalSteps = backendSteps + liveSteps;
    final dist = backendDist > 0 ? backendDist : totalSteps * 0.0008;
    final hrv = data?['latest_heart_rate']?['hrv_ms'];
    final rr = data?['latest_heart_rate']?['respiratory_rate'];

    final lastMeasured = data?['latest_heart_rate']?['measured_at'];
    final timeLabel = lastMeasured != null
        ? 'Last: ${DateFormat('HH:mm').format(DateTime.parse(lastMeasured))}'
        : 'No data yet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Vitals', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
            Text(timeLabel, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _VitalCard(
              title: 'Heart Rate',
              value: heartRate != null ? '$heartRate' : '--',
              unit: 'BPM',
              icon: Icons.favorite_rounded,
              color: const Color(0xFFEF4444),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeartRateMeasureScreen())),
            ),
            _VitalCard(
              title: 'Distance',
              value: dist.toStringAsFixed(2),
              unit: 'KM',
              icon: Icons.route_rounded,
              color: AppColors.accentOrange,
            ),
            _VitalCard(
              title: 'HRV',
              value: hrv != null ? _asDouble(hrv).toStringAsFixed(0) : '--',
              unit: 'ms',
              icon: Icons.monitor_heart_rounded,
              color: AppColors.sky500,
            ),
            _VitalCard(
              title: 'Resp. Rate',
              value: rr != null ? '$rr' : '--',
              unit: 'bpm',
              icon: Icons.air_rounded,
              color: AppColors.accentGreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityChart(Map<String, dynamic>? summary) {
    final weekly = summary?['weekly_activity'];
    final steps = List<double>.filled(7, 0);
    if (weekly is List) {
      for (var i = 0; i < weekly.length && i < 7; i++) {
        final item = weekly[i];
        if (item is Map && item['steps'] != null) {
          steps[i] = _asDouble(item['steps']);
        }
      }
    }
    final maxSteps = steps.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = math.max(1000.0, maxSteps * 1.15);
    final spots = List<FlSpot>.generate(7, (i) => FlSpot(i.toDouble(), steps[i]));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly Activity', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          summary == null ? 'Sync activity to see your week' : 'Last 7 days',
          style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.grey200),
          ),
          child: LineChart(
            LineChartData(
              minX: 0, maxX: 6, minY: 0, maxY: maxY,
              gridData: FlGridData(
                show: true, drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (v) => FlLine(color: AppColors.grey200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 28, interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round().clamp(0, 6);
                    final d = DateTime.now().subtract(Duration(days: 6 - i));
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat('E').format(d), style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 10, fontWeight: FontWeight.w600)),
                    );
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 38,
                  interval: maxY > 0 ? maxY / 4 : 1,
                  getTitlesWidget: (v, m) => Text(
                    v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : '${v.toInt()}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 9),
                  ),
                )),
              ),
              lineTouchData: LineTouchData(
                enabled: true, handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                    final i = spot.x.round().clamp(0, 6);
                    final d = DateTime.now().subtract(Duration(days: 6 - i));
                    return LineTooltipItem('${DateFormat('EEE, MMM d').format(d)}\n${spot.y.toInt()} steps', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12));
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots, isCurved: true, color: AppColors.sky500, barWidth: 3,
                  dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 4, color: AppColors.sky500, strokeWidth: 2, strokeColor: Colors.white)),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.sky500.withValues(alpha: 0.15), AppColors.sky500.withValues(alpha: 0.0)])),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VitalCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const _VitalCard({required this.title, required this.value, required this.unit, required this.icon, required this.color, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isEmpty = value == '--' || value == '0' || value == '0.00';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(w * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(w * 0.02),
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: w * 0.05),
                ),
                if (onTap != null) Icon(Icons.arrow_forward_ios_rounded, size: w * 0.03, color: AppColors.grey400),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Inter', color: AppColors.grey500, fontSize: w * 0.03)),
                SizedBox(height: w * 0.005),
                if (isEmpty)
                  Text(onTap != null ? 'Tap to measure' : 'No data yet', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: AppColors.grey400))
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(child: Text(value, style: TextStyle(fontSize: w * 0.058, fontWeight: FontWeight.w800, color: AppColors.splashSlate900, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      SizedBox(width: w * 0.01),
                      Text(unit, style: TextStyle(color: color, fontSize: w * 0.028, fontWeight: FontWeight.w700)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

