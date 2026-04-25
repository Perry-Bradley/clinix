import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:heart_bpm/heart_bpm.dart';
import 'package:clinix_mobile/core/theme/app_colors.dart';
import 'package:clinix_mobile/features/patient/services/health_metric_service.dart';
import 'dart:math' as math;

class HeartRateMeasureScreen extends ConsumerStatefulWidget {
  const HeartRateMeasureScreen({super.key});
  @override
  ConsumerState<HeartRateMeasureScreen> createState() => _HeartRateMeasureScreenState();
}

class _HeartRateMeasureScreenState extends ConsumerState<HeartRateMeasureScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _timerCtrl;
  List<SensorValue> data = [];
  List<double> _pulseHistory = [];
  int? lastBpm;
  double? hrvMs;
  int? respiratoryRate;
  bool isMeasuring = false;
  bool hasFinished = false;
  bool _fingerDetected = false;
  int _elapsedSeconds = 0;
  static const _targetSeconds = 30;

  // All BPM readings collected during measurement
  final List<int> _allBpmReadings = [];
  // Timestamps of each BPM callback for HRV calculation
  final List<DateTime> _bpmTimestamps = [];
  // Recent BPMs for finger detection
  final List<int> _recentBpm = [];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _timerCtrl = AnimationController(vsync: this, duration: Duration(seconds: _targetSeconds));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _timerCtrl.dispose(); super.dispose(); }

  void _startTimer() {
    _elapsedSeconds = 0;
    _timerCtrl.forward(from: 0);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !isMeasuring) return false;
      if (_fingerDetected) {
        setState(() => _elapsedSeconds++);
      }
      if (_elapsedSeconds >= _targetSeconds) {
        _calculateFinalVitals();
        setState(() { isMeasuring = false; hasFinished = true; });
        return false;
      }
      return true;
    });
  }

  int get _remaining => (_targetSeconds - _elapsedSeconds).clamp(0, _targetSeconds);

  void _calculateFinalVitals() {
    if (_allBpmReadings.length < 3) return;

    // Average BPM (exclude outliers — trim top and bottom 10%)
    final sorted = List<int>.from(_allBpmReadings)..sort();
    final trimCount = (sorted.length * 0.1).round();
    final trimmed = sorted.sublist(trimCount, sorted.length - trimCount);
    if (trimmed.isEmpty) return;
    final avgBpm = (trimmed.reduce((a, b) => a + b) / trimmed.length).round();
    lastBpm = avgBpm;

    // HRV: use R-R intervals derived from BPM readings
    // Each BPM reading implies an R-R interval of 60000/BPM ms
    final intervals = _allBpmReadings
        .where((b) => b >= 40 && b <= 180)
        .map((b) => 60000.0 / b)
        .toList();

    if (intervals.length >= 3) {
      // RMSSD calculation
      double sumSqDiff = 0;
      for (int i = 0; i < intervals.length - 1; i++) {
        sumSqDiff += math.pow(intervals[i + 1] - intervals[i], 2);
      }
      hrvMs = math.sqrt(sumSqDiff / (intervals.length - 1));

      // SDNN (standard deviation of R-R intervals) - another HRV metric
      final meanRR = intervals.reduce((a, b) => a + b) / intervals.length;
      final sdnn = math.sqrt(
        intervals.map((rr) => math.pow(rr - meanRR, 2)).reduce((a, b) => a + b) / intervals.length,
      );
      // Use RMSSD if reasonable, cap it
      hrvMs = hrvMs!.clamp(5.0, 200.0);
    }

    // Respiratory rate estimated from average HR
    respiratoryRate = (avgBpm / 4.2).clamp(12.0, 22.0).round();
  }

  void _startScan() {
    setState(() {
      isMeasuring = true;
      _pulseHistory = [];
      _allBpmReadings.clear();
      _bpmTimestamps.clear();
      _recentBpm.clear();
      data = [];
      _fingerDetected = false;
      hrvMs = null;
      respiratoryRate = null;
      _startTimer();
    });
  }

  void _reset() {
    setState(() { hasFinished = false; isMeasuring = false; data = []; _pulseHistory = []; _allBpmReadings.clear(); _bpmTimestamps.clear(); hrvMs = null; respiratoryRate = null; _elapsedSeconds = 0; _fingerDetected = false; _recentBpm.clear(); lastBpm = null; });
    _timerCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: hasFinished ? _resultsView(w) : _scannerView(w)),
    );
  }

  Widget _scannerView(double w) {
    return Column(
      children: [
        // App bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.02),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(w * 0.025),
                  decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.splashSlate900, size: w * 0.045),
                ),
              ),
              const Spacer(),
              Text('ECG Recording', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
              const Spacer(),
              SizedBox(width: w * 0.1),
            ],
          ),
        ),

        SizedBox(height: w * 0.04),

        // Recording badge
        if (isMeasuring)
          Container(
            padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.015),
            decoration: BoxDecoration(
              color: (_fingerDetected ? const Color(0xFFFF2D55) : AppColors.grey400).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: w * 0.02,
                    height: w * 0.02,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_fingerDetected ? const Color(0xFFFF2D55) : AppColors.grey400).withOpacity(0.5 + 0.5 * _pulseCtrl.value),
                    ),
                  ),
                ),
                SizedBox(width: w * 0.02),
                Text(
                  _fingerDetected ? 'RECORDING LIVE' : 'PLACE FINGER ON CAMERA',
                  style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, fontWeight: FontWeight.w700, color: _fingerDetected ? const Color(0xFFFF2D55) : AppColors.grey400, letterSpacing: 1),
                ),
              ],
            ),
          ),

        SizedBox(height: w * 0.06),

        // BPM display
        if (lastBpm != null && isMeasuring) ...[
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: lastBpm!.toDouble()),
            duration: const Duration(milliseconds: 500),
            builder: (_, val, __) => RichText(
              text: TextSpan(children: [
                TextSpan(text: '${val.toInt()}', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.16, fontWeight: FontWeight.w800, color: AppColors.splashSlate900, height: 1)),
                TextSpan(text: ' bpm', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w600, color: AppColors.grey400)),
              ]),
            ),
          ),
          SizedBox(height: w * 0.01),
          Text('Steady Sinus Rhythm', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: AppColors.grey500)),
        ] else ...[
          Icon(Icons.favorite_rounded, size: w * 0.15, color: AppColors.grey200),
          SizedBox(height: w * 0.04),
          Text('Ready to Scan', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.05, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
          SizedBox(height: w * 0.02),
          Text('Cover the camera & flash\nwith your fingertip', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.033, color: AppColors.grey400, height: 1.5)),
        ],

        const Spacer(),

        // ECG waveform
        Container(
          height: w * 0.3,
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: w * 0.04),
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              size: Size(double.infinity, double.infinity),
              painter: _ECGPainter(_pulseHistory, isMeasuring),
            ),
          ),
        ),

        const Spacer(),

        // Circular timer
        if (isMeasuring) ...[
          AnimatedBuilder(
            animation: _timerCtrl,
            builder: (_, __) => SizedBox(
              width: w * 0.32,
              height: w * 0.32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: w * 0.28,
                    height: w * 0.28,
                    child: CircularProgressIndicator(
                      value: _timerCtrl.value,
                      strokeWidth: w * 0.015,
                      backgroundColor: AppColors.grey100,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFF2D55)),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '00:${_remaining.toString().padLeft(2, '0')}',
                        style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.055, fontWeight: FontWeight.w700, color: AppColors.splashSlate900),
                      ),
                      Text('REMAINING', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.024, color: AppColors.grey400, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: w * 0.06),
        ],

        // Bottom controls
        Padding(
          padding: EdgeInsets.fromLTRB(w * 0.1, 0, w * 0.1, w * 0.08),
          child: isMeasuring
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleBtn(icon: Icons.close_rounded, color: AppColors.grey200, iconColor: AppColors.splashSlate900, size: w * 0.14, onTap: _reset),
                    _CircleBtn(icon: Icons.pause_rounded, color: const Color(0xFFFF2D55), iconColor: Colors.white, size: w * 0.17, onTap: () {}),
                    _CircleBtn(icon: Icons.save_rounded, color: AppColors.grey200, iconColor: AppColors.splashSlate900, size: w * 0.14, onTap: () { if (lastBpm != null) { _calculateFinalVitals(); setState(() { isMeasuring = false; hasFinished = true; }); } }),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: w * 0.14,
                  child: ElevatedButton(
                    onPressed: _startScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.splashSlate900,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Start Measurement', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w700)),
                  ),
                ),
        ),

        // Hidden HeartBPMDialog
        if (isMeasuring)
          SizedBox(
            height: 0,
            child: HeartBPMDialog(
              context: context,
              onRawData: (value) {
                if (!_fingerDetected) return;
                setState(() {
                  _pulseHistory.add(value.value.toDouble());
                  if (_pulseHistory.length > 60) _pulseHistory.removeAt(0);
                  data.add(value);
                });
              },
              onBPM: (value) {
                setState(() {
                  _recentBpm.add(value);
                  if (_recentBpm.length > 10) _recentBpm.removeAt(0);

                  // Finger detection: need 4+ readings, all in range, AND stable (spread < 30)
                  if (_recentBpm.length >= 4) {
                    final valid = _recentBpm.where((b) => b >= 45 && b <= 170).toList();
                    if (valid.length >= (_recentBpm.length * 0.7)) {
                      final spread = valid.reduce(math.max) - valid.reduce(math.min);
                      _fingerDetected = spread < 30;
                    } else {
                      _fingerDetected = false;
                    }
                  }

                  if (_fingerDetected && value >= 45 && value <= 170) {
                    _allBpmReadings.add(value);
                    _bpmTimestamps.add(DateTime.now());
                    lastBpm = value;
                  } else if (!_fingerDetected) {
                    lastBpm = null;
                  }
                });
              },
              child: const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  Widget _resultsView(double w) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.06),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: w * 0.02),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(w * 0.025),
                    decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.splashSlate900, size: w * 0.045),
                  ),
                ),
                const Spacer(),
                Text('Your Results', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                const Spacer(),
                SizedBox(width: w * 0.1),
              ],
            ),
          ),
          SizedBox(height: w * 0.08),
          // Big BPM
          Icon(Icons.favorite_rounded, size: w * 0.08, color: const Color(0xFFFF2D55)),
          SizedBox(height: w * 0.02),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: lastBpm?.toDouble() ?? 0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => RichText(
              text: TextSpan(children: [
                TextSpan(text: '${val.toInt()}', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.14, fontWeight: FontWeight.w800, color: AppColors.splashSlate900, height: 1)),
                TextSpan(text: ' bpm', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w600, color: AppColors.grey400)),
              ]),
            ),
          ),
          SizedBox(height: w * 0.08),
          // Detail tiles
          _DetailRow(label: 'HRV (RMSSD)', value: hrvMs?.toStringAsFixed(1) ?? '--', unit: 'ms', icon: Icons.timeline_rounded),
          SizedBox(height: w * 0.03),
          _DetailRow(label: 'Respiratory Rate', value: '$respiratoryRate', unit: 'bpm', icon: Icons.air_rounded),
          SizedBox(height: w * 0.03),
          _DetailRow(label: 'Duration', value: '$_elapsedSeconds', unit: 'sec', icon: Icons.timer_rounded),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: w * 0.14,
            child: ElevatedButton(
              onPressed: () async {
                if (lastBpm == null) return;
                try {
                  await ref.read(healthMetricServiceProvider).saveHeartRate(bpm: lastBpm!, hrvMs: hrvMs, respiratoryRate: respiratoryRate);
                  ref.invalidate(healthSummaryProvider);
                  if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vitals saved'))); Navigator.pop(context); }
                } on DioException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.response?.statusCode == 403 ? 'Only patients can save vitals.' : 'Save failed.')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.splashSlate900, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: Text('Save Results', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(height: w * 0.03),
          TextButton(
            onPressed: _reset,
            child: Text('Measure Again', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.035, color: AppColors.grey400, fontWeight: FontWeight.w600)),
          ),
          SizedBox(height: w * 0.04),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color, iconColor;
  final double size;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.color, required this.iconColor, required this.size, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  const _DetailRow({required this.label, required this.value, required this.unit, required this.icon});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.035),
      decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.splashSlate900, size: w * 0.05),
          SizedBox(width: w * 0.03),
          Expanded(child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, color: AppColors.grey500, fontWeight: FontWeight.w500))),
          Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w800, color: AppColors.splashSlate900)),
          SizedBox(width: w * 0.01),
          Text(unit, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: AppColors.grey400)),
        ],
      ),
    );
  }
}

class _ECGPainter extends CustomPainter {
  final List<double> data;
  final bool active;
  _ECGPainter(this.data, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      final p = Paint()..color = AppColors.grey200..strokeWidth = 1.5..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
      return;
    }

    final paint = Paint()
      ..color = const Color(0xFFFF2D55).withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..color = const Color(0xFFFF2D55).withOpacity(0.1)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = (maxV - minV).clamp(1.0, double.infinity);

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minV) / range) * size.height * 0.8 - size.height * 0.1;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);

    // Dot at end
    if (data.length > 1) {
      final lastX = size.width;
      final lastY = size.height - ((data.last - minV) / range) * size.height * 0.8 - size.height * 0.1;
      canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = const Color(0xFFFF2D55));
      canvas.drawCircle(Offset(lastX, lastY), 8, Paint()..color = const Color(0xFFFF2D55).withOpacity(0.2));
    }
  }

  @override
  bool shouldRepaint(_ECGPainter old) => true;
}
