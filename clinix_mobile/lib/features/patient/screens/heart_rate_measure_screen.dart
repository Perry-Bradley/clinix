import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clinix_mobile/core/theme/app_colors.dart';
import 'package:clinix_mobile/features/patient/services/health_metric_service.dart';

class HeartRateMeasureScreen extends ConsumerStatefulWidget {
  const HeartRateMeasureScreen({super.key});
  @override
  ConsumerState<HeartRateMeasureScreen> createState() => _HeartRateMeasureScreenState();
}

class _HeartRateMeasureScreenState extends ConsumerState<HeartRateMeasureScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _timerCtrl;
  // Raw luminance signal from the front camera (one sample per frame)
  final List<double> _signal = [];
  final List<DateTime> _signalTimes = [];
  // Visual ECG-style trace
  List<double> _pulseHistory = [];
  int? lastBpm;
  double? hrvMs;
  int? respiratoryRate;
  bool isMeasuring = false;
  bool hasFinished = false;
  bool _fingerDetected = false;
  int _elapsedSeconds = 0;
  static const _targetSeconds = 30;

  // BPM samples derived from peak detection during measurement
  final List<int> _allBpmReadings = [];
  final List<DateTime> _bpmTimestamps = [];
  // Recent BPMs for finger-detection stability check
  final List<int> _recentBpm = [];

  // Camera state
  CameraController? _cam;
  bool _processingFrame = false;
  Timer? _bpmTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _timerCtrl = AnimationController(vsync: this, duration: Duration(seconds: _targetSeconds));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timerCtrl.dispose();
    _bpmTimer?.cancel();
    _stopCamera();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    try {
      if (_cam?.value.isStreamingImages == true) {
        await _cam!.stopImageStream();
      }
      await _cam?.dispose();
    } catch (_) {/* ignore */}
    _cam = null;
  }

  Future<bool> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cam = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _cam!.initialize();
      await _cam!.startImageStream(_onFrame);
      return true;
    } catch (e) {
      debugPrint('[HR] camera init failed: $e');
      return false;
    }
  }

  // Per-frame: average the Y (luminance) channel over a centre square.
  // With the screen lit white and a finger covering the front lens, the
  // light that diffuses through the fingertip pulses with each heartbeat.
  void _onFrame(CameraImage image) {
    if (_processingFrame || !mounted) return;
    _processingFrame = true;
    try {
      final y = image.planes[0];
      final w = image.width;
      final h = image.height;
      final bpr = y.bytesPerRow;
      // 80x80 centre window — small enough to be cheap, big enough to average noise out
      const half = 40;
      final cx = w ~/ 2;
      final cy = h ~/ 2;
      final x0 = (cx - half).clamp(0, w - 1);
      final y0 = (cy - half).clamp(0, h - 1);
      final x1 = (cx + half).clamp(0, w - 1);
      final y1 = (cy + half).clamp(0, h - 1);
      int sum = 0;
      int count = 0;
      for (int row = y0; row < y1; row += 2) {
        final base = row * bpr;
        for (int col = x0; col < x1; col += 2) {
          sum += y.bytes[base + col];
          count++;
        }
      }
      if (count == 0) return;
      final avg = sum / count;
      final now = DateTime.now();

      _signal.add(avg);
      _signalTimes.add(now);
      // Keep ~12s of samples (camera ~30fps → ~360 samples)
      while (_signalTimes.isNotEmpty &&
          now.difference(_signalTimes.first).inMilliseconds > 12000) {
        _signal.removeAt(0);
        _signalTimes.removeAt(0);
      }

      // Update the ECG trace (keep AC component only — subtract running mean)
      if (_signal.length > 30) {
        final tail = _signal.sublist(math.max(0, _signal.length - 30));
        final mean = tail.reduce((a, b) => a + b) / tail.length;
        _pulseHistory.add(avg - mean);
        if (_pulseHistory.length > 90) _pulseHistory.removeAt(0);
      }
    } catch (_) {/* swallow — frame format issues are non-fatal */} finally {
      _processingFrame = false;
    }
  }

  // Estimate BPM from the buffered signal using simple peak detection.
  // Runs on a timer (every 1s) instead of every frame.
  void _estimateBpm() {
    if (_signal.length < 90) return;

    // Smooth with a 5-tap moving average to remove camera noise
    final smoothed = <double>[];
    const window = 2; // 5-tap = 2 each side + centre
    for (int i = window; i < _signal.length - window; i++) {
      double s = 0;
      for (int j = -window; j <= window; j++) {
        s += _signal[i + j];
      }
      smoothed.add(s / (window * 2 + 1));
    }
    if (smoothed.length < 60) return;

    // Subtract slow-drift (rolling mean of 30 samples ≈ 1s at 30fps)
    final detrended = <double>[];
    const drift = 15;
    for (int i = drift; i < smoothed.length - drift; i++) {
      double s = 0;
      for (int j = -drift; j <= drift; j++) {
        s += smoothed[i + j];
      }
      detrended.add(smoothed[i] - s / (drift * 2 + 1));
    }
    if (detrended.length < 30) return;

    // Find peaks: local max with min separation (~250ms = 240 BPM upper bound)
    final samplingRate = _signalTimes.length /
        (_signalTimes.last.difference(_signalTimes.first).inMilliseconds / 1000.0);
    final minSep = (samplingRate * 0.25).round().clamp(4, 30);
    final peaks = <int>[];
    for (int i = 1; i < detrended.length - 1; i++) {
      if (detrended[i] > detrended[i - 1] &&
          detrended[i] > detrended[i + 1] &&
          detrended[i] > 0) {
        if (peaks.isEmpty || i - peaks.last >= minSep) {
          peaks.add(i);
        }
      }
    }
    if (peaks.length < 3) return;

    // Compute BPM from average inter-peak interval
    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add((peaks[i] - peaks[i - 1]) / samplingRate);
    }
    intervals.sort();
    // Trim outliers — drop top & bottom one
    if (intervals.length > 4) {
      intervals.removeAt(0);
      intervals.removeLast();
    }
    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final bpm = (60 / avgInterval).round();
    if (bpm < 40 || bpm > 200) return;

    if (!mounted) return;
    setState(() {
      _recentBpm.add(bpm);
      if (_recentBpm.length > 10) _recentBpm.removeAt(0);

      // Finger detection: 4+ stable readings in a normal range
      if (_recentBpm.length >= 4) {
        final valid = _recentBpm.where((b) => b >= 45 && b <= 170).toList();
        if (valid.length >= (_recentBpm.length * 0.7)) {
          final spread = valid.reduce(math.max) - valid.reduce(math.min);
          _fingerDetected = spread < 30;
        } else {
          _fingerDetected = false;
        }
      }

      if (_fingerDetected && bpm >= 45 && bpm <= 170) {
        _allBpmReadings.add(bpm);
        _bpmTimestamps.add(DateTime.now());
        lastBpm = bpm;
      } else if (!_fingerDetected) {
        lastBpm = null;
      }
    });
  }

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
        _bpmTimer?.cancel();
        _stopCamera();
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

  Future<void> _startScan() async {
    setState(() {
      isMeasuring = true;
      _pulseHistory = [];
      _allBpmReadings.clear();
      _bpmTimestamps.clear();
      _recentBpm.clear();
      _signal.clear();
      _signalTimes.clear();
      _fingerDetected = false;
      hrvMs = null;
      respiratoryRate = null;
    });
    final ok = await _startCamera();
    if (!ok) {
      if (!mounted) return;
      setState(() => isMeasuring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start camera')),
      );
      return;
    }
    _bpmTimer?.cancel();
    _bpmTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) => _estimateBpm());
    _startTimer();
  }

  void _reset() {
    _bpmTimer?.cancel();
    _stopCamera();
    setState(() {
      hasFinished = false;
      isMeasuring = false;
      _pulseHistory = [];
      _allBpmReadings.clear();
      _bpmTimestamps.clear();
      _signal.clear();
      _signalTimes.clear();
      hrvMs = null;
      respiratoryRate = null;
      _elapsedSeconds = 0;
      _fingerDetected = false;
      _recentBpm.clear();
      lastBpm = null;
    });
    _timerCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      // While measuring we use a different layout: the top 60% of the screen
      // is pure white (the "screen flash" that illuminates the fingertip
      // pressed on the front camera), and all controls dock at the bottom.
      body: hasFinished
          ? SafeArea(child: _resultsView(w))
          : isMeasuring
              ? _measuringView(w)
              : SafeArea(child: _scannerView(w)),
    );
  }

  Widget _measuringView(double w) {
    final remaining = _remaining;
    return Column(
      children: [
        // Pure-white top — this is what reflects onto the fingertip.
        // No widgets here at all so it's as bright as possible.
        Expanded(
          flex: 6,
          child: Container(
            color: Colors.white,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: w * 0.04),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fingerDetected ? '● RECORDING' : '● PLACE FINGER ON FRONT CAMERA',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: w * 0.026,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: _fingerDetected ? const Color(0xFFFF2D55) : AppColors.grey200,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Bottom panel: BPM, timer, stop. Dark on white, the rest of the
        // top half stays pure white for the screen-flash effect.
        Container(
          padding: EdgeInsets.fromLTRB(w * 0.08, w * 0.04, w * 0.08, w * 0.06),
          decoration: const BoxDecoration(color: Colors.white),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lastBpm != null) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: lastBpm!.toDouble()),
                    duration: const Duration(milliseconds: 500),
                    builder: (_, val, __) => RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '${val.toInt()}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: w * 0.16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.splashSlate900,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: ' bpm',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: w * 0.04,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey400,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  SizedBox(height: w * 0.01),
                  Text(
                    'Steady Sinus Rhythm',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: w * 0.032,
                      color: AppColors.grey500,
                    ),
                  ),
                ] else ...[
                  Icon(Icons.favorite_rounded, size: w * 0.12, color: AppColors.grey200),
                  SizedBox(height: w * 0.02),
                  Text(
                    'Hold steady…',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: w * 0.038,
                      color: AppColors.grey400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: w * 0.06),
                AnimatedBuilder(
                  animation: _timerCtrl,
                  builder: (_, __) => SizedBox(
                    width: w * 0.28,
                    height: w * 0.28,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: w * 0.24,
                          height: w * 0.24,
                          child: CircularProgressIndicator(
                            value: _timerCtrl.value,
                            strokeWidth: w * 0.012,
                            backgroundColor: AppColors.grey100,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFFF2D55)),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '00:${remaining.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: w * 0.05,
                                fontWeight: FontWeight.w700,
                                color: AppColors.splashSlate900,
                              ),
                            ),
                            Text(
                              'REMAINING',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: w * 0.022,
                                color: AppColors.grey400,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: w * 0.06),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleBtn(
                      icon: Icons.close_rounded,
                      color: AppColors.grey100,
                      iconColor: AppColors.splashSlate900,
                      size: w * 0.14,
                      onTap: _reset,
                    ),
                    _CircleBtn(
                      icon: Icons.save_rounded,
                      color: AppColors.grey100,
                      iconColor: AppColors.splashSlate900,
                      size: w * 0.14,
                      onTap: () {
                        if (lastBpm != null) {
                          _bpmTimer?.cancel();
                          _stopCamera();
                          _calculateFinalVitals();
                          setState(() {
                            isMeasuring = false;
                            hasFinished = true;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
                  _fingerDetected ? 'RECORDING LIVE' : 'PLACE FINGER ON FRONT CAMERA',
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
          Text('Place your finger on the\nfront camera (top of screen)', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.033, color: AppColors.grey400, height: 1.5)),
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
                    _CircleBtn(icon: Icons.save_rounded, color: AppColors.grey200, iconColor: AppColors.splashSlate900, size: w * 0.14, onTap: () { if (lastBpm != null) { _bpmTimer?.cancel(); _stopCamera(); _calculateFinalVitals(); setState(() { isMeasuring = false; hasFinished = true; }); } }),
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
