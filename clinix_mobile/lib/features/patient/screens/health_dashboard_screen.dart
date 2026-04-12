import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/health_metric_service.dart';
import '../services/activity_service.dart';
import 'heart_rate_measure_screen.dart';

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class HealthDashboardScreen extends ConsumerWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(healthSummaryProvider);
    final stepsStream = ref.watch(stepCountProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(healthSummaryProvider);
          await ref.read(healthSummaryProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepSection(stepsStream.value ?? 0),
                    const SizedBox(height: 32),
                    summaryAsync.when(
                      loading: () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          _buildVitalsGrid(context, null),
                          const SizedBox(height: 32),
                          _buildActivityChartSection(null),
                        ],
                      ),
                      error: (e, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              leading: Icon(Icons.cloud_off, color: Colors.orange.shade800),
                              title: const Text('Could not load vitals'),
                              subtitle: Text(
                                'Check that the API is running and api_constants.dart uses your PC\'s LAN IP. Pull down to retry.',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                              trailing: TextButton(
                                onPressed: () => ref.invalidate(healthSummaryProvider),
                                child: const Text('Retry'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildVitalsGrid(context, null),
                          const SizedBox(height: 32),
                          _buildActivityChartSection(null),
                        ],
                      ),
                      data: (data) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVitalsGrid(context, data),
                          const SizedBox(height: 32),
                          _buildActivityChartSection(data),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return const SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Health Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        titlePadding: EdgeInsets.only(left: 24, bottom: 16),
      ),
    );
  }

  Widget _buildStepSection(int steps) {
    const int goal = 10000;
    final double progress = (steps / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Steps', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                Text('$steps', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                const Text('Goal: $goal', style: TextStyle(color: Colors.white60, fontSize: 14)),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const Icon(Icons.directions_walk, color: Colors.white, size: 32),
            ],
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

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildMetricCard(
          context,
          title: 'Heart Rate',
          value: heartRate != null ? '$heartRate' : '--',
          unit: 'BPM',
          icon: Icons.favorite,
          color: Colors.red,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HeartRateMeasureScreen()),
          ),
        ),
        _buildMetricCard(
          context,
          title: 'Distance',
          value: dist.toStringAsFixed(2),
          unit: 'KM',
          icon: Icons.map,
          color: Colors.orange,
          onTap: () {},
        ),
        _buildMetricCard(
          context,
          title: 'Heart Variability',
          value: hrv != null ? _asDouble(hrv).toStringAsFixed(0) : '--',
          unit: 'ms',
          icon: Icons.monitor_heart_rounded,
          color: Colors.blueAccent,
          onTap: () {},
        ),
        _buildMetricCard(
          context,
          title: 'Respiratory Rate',
          value: rr != null ? '$rr' : '--',
          unit: 'bpm',
          icon: Icons.air_rounded,
          color: Colors.greenAccent,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Text(unit, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChartSection(Map<String, dynamic>? summary) {
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
    final maxY = math.max(1000.0, maxSteps * 1.12);
    final spots = List<FlSpot>.generate(7, (i) => FlSpot(i.toDouble(), steps[i]));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Weekly steps', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          summary == null
              ? 'Sign in and sync activity to see your last 7 days.'
              : 'Last 7 days from your synced daily totals.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round().clamp(0, 6);
                      final d = DateTime.now().subtract(Duration(days: 6 - i));
                      final label = DateFormat('E').format(d);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxY > 0 ? maxY / 4 : 1,
                    getTitlesWidget: (v, m) => Text(
                      v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : '${v.toInt()}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final i = spot.x.round().clamp(0, 6);
                      final d = DateTime.now().subtract(Duration(days: 6 - i));
                      return LineTooltipItem(
                        '${DateFormat('EEE MMM d').format(d)}\n${spot.y.toInt()} steps',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                      radius: 4,
                      color: Colors.blueAccent,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blueAccent.withOpacity(0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
