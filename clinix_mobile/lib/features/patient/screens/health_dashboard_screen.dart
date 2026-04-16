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
    final summaryAsync = ref.watch(healthSummaryProvider);
    final stepsStream = ref.watch(stepCountProvider);
    final steps = stepsStream.value ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.sky500,
        onRefresh: () async {
          ref.invalidate(healthSummaryProvider);
          await ref.read(healthSummaryProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App Bar with back button
            SliverAppBar(
              expandedHeight: 100,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_rounded, color: AppColors.grey500, size: 22),
                  onPressed: () => _showGoalSettings(context),
                  tooltip: 'Set Goals',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text('Health Dashboard', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.darkBlue900, fontSize: 18)),
                centerTitle: false,
                titlePadding: EdgeInsets.only(left: Navigator.of(context).canPop() ? 56 : 20, bottom: 14),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepCard(steps),
                    const SizedBox(height: 20),
                    summaryAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator(color: AppColors.sky500)),
                      ),
                      error: (e, _) => _buildErrorCard(),
                      data: (data) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVitalsGrid(context, data),
                          const SizedBox(height: 24),
                          _buildActivityChart(data),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(int steps) {
    final goal = _goalLoaded ? _stepGoal : 10000;
    final double progress = (steps / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkBlue800, AppColors.sky600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.sky500.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Steps', style: AppTextStyles.caption.copyWith(color: AppColors.sky200, fontSize: 13, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text('$steps', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'Inter')),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showGoalSettings(context),
                  child: Row(
                    children: [
                      Text('Goal: $goal', style: AppTextStyles.caption.copyWith(color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, color: Colors.white38, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Inter')),
            ],
          ),
        ],
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
    final dist = data?['today_activity'] != null ? _asDouble(data!['today_activity']['distance_km']) : 0.0;
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
  final VoidCallback? onTap;

  const _VitalCard({required this.title, required this.value, required this.unit, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null) Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.grey400),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 12)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.darkBlue900, fontFamily: 'Inter')),
                    const SizedBox(width: 4),
                    Text(unit, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
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
