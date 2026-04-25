import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../shared/widgets/custom_sidebar_drawer.dart';
import '../../../shared/widgets/bubble_bottom_bar.dart';
import '../../screens/doctors_list_screen.dart';
import '../../screens/nearby_clinics_screen.dart';
import '../../screens/health_dashboard_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/health_metric_service.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../../core/services/appointment_service.dart';
import '../../services/activity_service.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  int _selectedTab = 0;

  final List<Widget> _pages = const [
    _PatientDashboard(),
    DoctorsListScreen(),
    NearbyClinicsScreen(),
    HealthDashboardScreen(),
    _PatientProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      drawer: CustomSidebarDrawer(
        currentIndex: _selectedTab,
        onTabSelected: (i) => setState(() => _selectedTab = i),
        isProvider: false,
      ),
      body: IndexedStack(index: _selectedTab, children: _pages),
      bottomNavigationBar: BubbleBottomBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        items: [
          BubbleNavItem(icon: Icons.home_outlined, label: 'Home'),
          BubbleNavItem(icon: Icons.search_rounded, label: 'Doctors'),
          BubbleNavItem(icon: Icons.map_outlined, label: 'Map'),
          BubbleNavItem(icon: Icons.favorite_outline_rounded, label: 'Health'),
          BubbleNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}

class _PatientDashboard extends StatefulWidget {
  const _PatientDashboard();

  @override
  State<_PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<_PatientDashboard> {
  String _userName = 'User';
  String _greeting = 'Good Day';
  IconData _greetingIcon = Icons.wb_sunny_rounded;
  List<Map<String, dynamic>> _upcoming = [];
  bool _loadedAppointments = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initStepTracking();
    _loadAppointments();
  }

  Future<void> _initStepTracking() async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final activity = container.read(activityServiceProvider);
      await activity.init();
    } catch (_) {}
  }

  Future<void> _loadAppointments() async {
    try {
      final all = await AppointmentService.getMyAppointments();
      final now = DateTime.now();
      final upcoming = all.where((a) {
        final status = a['status']?.toString() ?? '';
        if (status != 'pending' && status != 'confirmed') return false;
        final dateStr = a['scheduled_at']?.toString();
        if (dateStr == null) return false;
        final date = DateTime.tryParse(dateStr);
        return date != null && date.isAfter(now);
      }).take(3).toList();
      if (mounted) setState(() { _upcoming = upcoming; _loadedAppointments = true; });
    } catch (_) { if (mounted) setState(() => _loadedAppointments = true); }
  }

  Future<void> _loadUserData() async {
    final name = await AuthService.getUserName();
    final hour = DateTime.now().hour;
    
    String greeting;
    IconData icon;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good Morning';
      icon = Icons.wb_twilight_rounded;
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
      icon = Icons.wb_sunny_rounded;
    } else {
      greeting = 'Good Evening';
      icon = Icons.nightlight_round;
    }

    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _userName = name;
        _greeting = greeting;
        _greetingIcon = icon;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final topPad = mq.padding.top;
    final hp = w * 0.06;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF1B4080)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(hp, topPad + 16, hp, w * 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: Container(
                        padding: EdgeInsets.all(w * 0.025),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.menu_rounded, color: Colors.white, size: w * 0.055),
                      ),
                    ),
                    SizedBox(width: w * 0.035),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_greeting, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: Colors.white54)),
                          SizedBox(height: w * 0.005),
                          Text(_userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.052, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Container(
                        padding: EdgeInsets.all(w * 0.025),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: w * 0.055),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: w * 0.055),
                GestureDetector(
                  onTap: () {
                    final state = context.findAncestorStateOfType<_PatientHomePageState>();
                    state?.setState(() => state._selectedTab = 1);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.032),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: Colors.white30, size: w * 0.048),
                        SizedBox(width: w * 0.03),
                        Text('Search doctors, services...', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, color: Colors.white30)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hp, w * 0.05, hp, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Feature Grid 2x2
              Row(
                children: [
                  _FeatureCard(icon: Icons.spa_rounded, title: 'Clinix AI', subtitle: 'Health Assistant', onTap: () => context.push('/ai-consult')),
                  SizedBox(width: w * 0.03),
                  _FeatureCard(icon: Icons.person_search_rounded, title: 'Consult', subtitle: 'Find a Doctor', onTap: () {
                    final state = context.findAncestorStateOfType<_PatientHomePageState>();
                    state?.setState(() => state._selectedTab = 1);
                  }),
                ],
              ),
              SizedBox(height: w * 0.03),
              Row(
                children: [
                  _FeatureCard(icon: Icons.home_rounded, title: 'HomeCare', subtitle: 'Care at Home', onTap: () => context.push('/homecare')),
                  SizedBox(width: w * 0.03),
                  _FeatureCard(icon: Icons.monitor_heart_rounded, title: 'Health', subtitle: 'Track Vitals', onTap: () {
                    final state = context.findAncestorStateOfType<_PatientHomePageState>();
                    state?.setState(() => state._selectedTab = 3);
                  }),
                ],
              ),
              SizedBox(height: w * 0.05),
              if (_loadedAppointments && _upcoming.isNotEmpty)
                _UpcomingList(appointments: _upcoming)
              else
                _BookAppointmentCard(),
              SizedBox(height: w * 0.04),
              Consumer(
                builder: (context, ref, child) {
                  final summaryAsync = ref.watch(healthSummaryProvider);
                  return _AnimatedHealthCard(summaryAsync: summaryAsync);
                },
              ),
              SizedBox(height: w * 0.04),
              // Quick Services row
              _QuickServicesRow(),
              SizedBox(height: mq.padding.bottom + 24),
            ]),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _FeatureCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
                padding: EdgeInsets.all(w * 0.028),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue800.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.darkBlue500, size: w * 0.055),
              ),
              SizedBox(width: w * 0.025),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.035, fontWeight: FontWeight.w700, color: AppColors.darkBlue800)),
                    Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.026, color: AppColors.grey500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedHealthCard extends StatefulWidget {
  final AsyncValue<Map<String, dynamic>> summaryAsync;
  const _AnimatedHealthCard({required this.summaryAsync});
  @override
  State<_AnimatedHealthCard> createState() => _AnimatedHealthCardState();
}

class _AnimatedHealthCardState extends State<_AnimatedHealthCard> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _entryCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            children: [
              // Top: heart rate with animated ECG line
              Padding(
                padding: EdgeInsets.fromLTRB(w * 0.045, w * 0.04, w * 0.045, 0),
                child: widget.summaryAsync.when(
                  data: (data) {
                    final bpm = data['latest_heart_rate'] != null ? '${data['latest_heart_rate']['bpm']}' : '--';
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _PulsingIcon(controller: _pulseCtrl, icon: Icons.favorite_rounded, color: const Color(0xFFFF6B6B), size: w * 0.05),
                                SizedBox(width: w * 0.02),
                                Text('Heart Rate', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: AppColors.grey500, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            SizedBox(height: w * 0.01),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: double.tryParse(bpm) ?? 0),
                                  duration: const Duration(milliseconds: 1200),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, val, __) => Text(
                                    bpm == '--' ? '--' : val.toInt().toString(),
                                    style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.09, fontWeight: FontWeight.w800, color: AppColors.darkBlue900, height: 1),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: w * 0.015, bottom: w * 0.01),
                                  child: Text('bpm', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: AppColors.grey400)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: w * 0.35,
                          height: w * 0.12,
                          child: AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, __) => CustomPaint(painter: _HeartbeatPainter(_pulseCtrl.value)),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => SizedBox(height: w * 0.15, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBlue500))),
                  error: (_, __) => SizedBox(
                    height: w * 0.12,
                    child: Row(children: [
                      Icon(Icons.cloud_off_rounded, color: AppColors.grey400, size: w * 0.04),
                      SizedBox(width: w * 0.02),
                      Text('Could not load vitals', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: AppColors.grey400)),
                    ]),
                  ),
                ),
              ),
              SizedBox(height: w * 0.035),
              // Bottom row: steps (live) + resp
              Padding(
                padding: EdgeInsets.fromLTRB(w * 0.03, 0, w * 0.03, w * 0.04),
                child: widget.summaryAsync.when(
                  data: (data) {
                    final backendSteps = data['today_activity']?['steps'] ?? 0;
                    final resp = data['latest_heart_rate']?['respiratory_rate']?.toString() ?? '--';
                    return Row(
                      children: [
                        Consumer(builder: (context, ref, _) {
                          final localSteps = ref.watch(stepCountProvider).value ?? 0;
                          final serverSteps = int.tryParse(backendSteps.toString()) ?? 0;
                          // Server steps are persisted across sessions, local starts from 0 each launch
                          // Show server + local session steps for today's total
                          final steps = serverSteps + localSteps;
                          return _BottomVital(icon: Icons.directions_walk_rounded, value: '$steps', label: 'Steps', iconColor: const Color(0xFF4ECDC4));
                        }),
                        SizedBox(width: w * 0.025),
                        _BottomVital(icon: Icons.air_rounded, value: resp, label: 'Resp. Rate', iconColor: const Color(0xFF45B7D1)),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatelessWidget {
  final AnimationController controller;
  final IconData icon;
  final Color color;
  final double size;
  const _PulsingIcon({required this.controller, required this.icon, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        final scale = 1.0 + 0.12 * math.sin(t * math.pi * 2);
        final opacity = 0.7 + 0.3 * math.sin(t * math.pi * 2);
        return Transform.scale(
          scale: scale,
          child: Icon(icon, color: color.withOpacity(opacity), size: size),
        );
      },
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  final double phase;
  _HeartbeatPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final w = size.width;
    final lineColor = const Color(0xFFFF2D55);

    final bgPaint = Paint()
      ..color = lineColor.withOpacity(0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, midY), Offset(w, midY), bgPaint);

    final path = Path();
    final points = 200;
    for (int i = 0; i <= points; i++) {
      final t = i / points;
      final x = t * w;
      final cycle = (t * 2 + phase) % 1.0;
      double y = midY;

      if (cycle > 0.35 && cycle < 0.38) {
        y = midY - size.height * 0.12 * math.sin((cycle - 0.35) / 0.03 * math.pi);
      } else if (cycle > 0.40 && cycle < 0.46) {
        final p = (cycle - 0.40) / 0.06;
        y = midY - size.height * 0.6 * math.sin(p * math.pi);
      } else if (cycle > 0.46 && cycle < 0.50) {
        final p = (cycle - 0.46) / 0.04;
        y = midY + size.height * 0.25 * math.sin(p * math.pi);
      } else if (cycle > 0.55 && cycle < 0.60) {
        y = midY - size.height * 0.08 * math.sin((cycle - 0.55) / 0.05 * math.pi);
      }

      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    final glow = Paint()
      ..color = lineColor.withOpacity(0.08)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glow);

    final paint = Paint()
      ..color = lineColor.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);

    final metrics = path.computeMetrics().first;
    final dotPos = metrics.getTangentForOffset(metrics.length * 0.7);
    if (dotPos != null) {
      canvas.drawCircle(dotPos.position, 3, Paint()..color = lineColor.withOpacity(0.8));
      canvas.drawCircle(dotPos.position, 6, Paint()..color = lineColor.withOpacity(0.15));
    }
  }

  @override
  bool shouldRepaint(_HeartbeatPainter old) => old.phase != phase;
}

class _BottomVital extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  const _BottomVital({required this.icon, required this.value, required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: w * 0.03, horizontal: w * 0.035),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: w * 0.055),
            SizedBox(width: w * 0.025),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => Text(
                    value == '--' ? '--' : val.toInt().toString(),
                    style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w800, color: AppColors.darkBlue900),
                  ),
                ),
                Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.025, color: AppColors.grey500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookAppointmentCard extends StatelessWidget {
  const _BookAppointmentCard();
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () {
        final state = context.findAncestorStateOfType<_PatientHomePageState>();
        state?.setState(() => state._selectedTab = 1);
      },
      child: Container(
        padding: EdgeInsets.all(w * 0.045),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.darkBlue800, AppColors.darkBlue600],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Book an Appointment', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w700, color: Colors.white)),
                  SizedBox(height: w * 0.015),
                  Text('Connect with verified doctors near you', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: Colors.white60)),
                ],
              ),
            ),
            SizedBox(width: w * 0.03),
            Container(
              padding: EdgeInsets.all(w * 0.03),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.calendar_month_rounded, color: Colors.white, size: w * 0.06),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickServicesRow extends StatelessWidget {
  const _QuickServicesRow();
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Services', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.042, fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
        SizedBox(height: w * 0.03),
        Row(
          children: [
            _QuickServiceTile(icon: Icons.medication_rounded, label: 'Prescriptions', onTap: () => context.push('/patient/prescriptions')),
            SizedBox(width: w * 0.025),
            _QuickServiceTile(icon: Icons.chat_rounded, label: 'Messages', onTap: () => context.push('/patient/messages')),
            SizedBox(width: w * 0.025),
            _QuickServiceTile(icon: Icons.receipt_long_rounded, label: 'Records', onTap: () => context.push('/patient/medical-records')),
          ],
        ),
      ],
    );
  }
}

class _QuickServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickServiceTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: w * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(w * 0.025),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue800.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.darkBlue500, size: w * 0.05),
              ),
              SizedBox(height: w * 0.015),
              Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, fontWeight: FontWeight.w600, color: AppColors.darkBlue900), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  final List<Map<String, dynamic>> appointments;
  const _UpcomingList({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.042, fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
            GestureDetector(
              onTap: () => context.push('/patient/appointments'),
              child: Text('See all', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: AppColors.darkBlue900, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        SizedBox(height: w * 0.03),
        ...appointments.map((a) {
          final providerName = a['provider_name']?.toString() ?? a['provider']?['full_name']?.toString() ?? 'Doctor';
          final dateStr = a['scheduled_at']?.toString() ?? '';
          final date = DateTime.tryParse(dateStr);
          final formattedDate = date != null ? DateFormat('EEE, MMM d').format(date.toLocal()) : '';
          final formattedTime = date != null ? DateFormat('HH:mm').format(date.toLocal()) : '';
          final status = a['status']?.toString() ?? 'pending';
          final type = a['appointment_type']?.toString() ?? 'virtual';
          final isPending = status == 'pending';

          return GestureDetector(
            onTap: () => context.push('/appointments/${a['appointment_id']}'),
            child: Container(
              margin: EdgeInsets.only(bottom: w * 0.025),
              padding: EdgeInsets.all(w * 0.035),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Row(
                children: [
                  Container(
                    width: w * 0.11, height: w * 0.11,
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue900.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      type == 'virtual' ? Icons.video_call_rounded : Icons.local_hospital_rounded,
                      color: AppColors.darkBlue900,
                      size: w * 0.055,
                    ),
                  ),
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(providerName, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: w * 0.035, color: AppColors.darkBlue900), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: w * 0.005),
                      Text('$formattedDate at $formattedTime', style: TextStyle(fontFamily: 'Inter', color: AppColors.grey500, fontSize: w * 0.03)),
                    ]),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.02, vertical: w * 0.01),
                    decoration: BoxDecoration(
                      color: (isPending ? AppColors.darkBlue900 : AppColors.accentGreen).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPending ? 'Pending' : 'Confirmed',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: isPending ? AppColors.darkBlue900 : AppColors.accentGreen,
                        fontWeight: FontWeight.w600, fontSize: w * 0.026,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PatientDoctorsTab extends StatelessWidget {
  const _PatientDoctorsTab();

  static const List<Map<String, String>> _mockDoctors = [
    {'name': 'Dr. Marie Nkomo', 'spec': 'Cardiologist', 'rating': '4.9', 'id': '1'},
    {'name': 'Dr. Jean Paul', 'spec': 'Neurologist', 'rating': '4.8', 'id': '2'},
    {'name': 'Dr. Sarah Smith', 'spec': 'Pediatrician', 'rating': '4.7', 'id': '3'},
    {'name': 'Dr. Robert King', 'spec': 'Dermatologist', 'rating': '4.9', 'id': '4'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.darkBlue900,
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Find Doctors', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white, fontSize: 16)),
              background: Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _DoctorListTile(doctor: _mockDoctors[i % _mockDoctors.length]),
                childCount: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorListTile extends StatelessWidget {
  final Map<String, String> doctor;
  const _DoctorListTile({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [BoxShadow(color: AppColors.darkBlue900.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.darkBlue700, AppColors.sky500]), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor['name']!, style: AppTextStyles.headlineSmall),
                const SizedBox(height: 2),
                Text(doctor['spec']!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                    const SizedBox(width: 4),
                    Text(doctor['rating']!, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    const Icon(Icons.circle, color: AppColors.accentGreen, size: 8),
                    const SizedBox(width: 4),
                    Text('Available', style: AppTextStyles.caption.copyWith(color: AppColors.accentGreen)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/appointments/book?providerId=mock'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.sky600, AppColors.sky400]), borderRadius: BorderRadius.circular(12)),
              child: Text('Book', style: AppTextStyles.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => context.push('/chat/mock_chat_${doctor['id']}?doctorName=${Uri.encodeComponent(doctor['name']!)}'),
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.sky500),
          ),
        ],
      ),
    );
  }
}

class _PatientAppointmentsTab extends StatelessWidget {
  const _PatientAppointmentsTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.darkBlue900,
          pinned: true,
          title: Text('My Appointments', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white, fontSize: 16)),
          automaticallyImplyLeading: false,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  children: [
                    Container(width: 4, height: 60, decoration: BoxDecoration(color: i % 2 == 0 ? AppColors.sky500 : AppColors.accentGreen, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i % 2 == 0 ? 'Dr. Jean Paul' : 'Dr. Marie Nkomo', style: AppTextStyles.headlineSmall.copyWith(fontSize: 15)),
                          Text(i % 2 == 0 ? 'Neurology' : 'Cardiology', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500)),
                          const SizedBox(height: 6),
                          Text(i % 2 == 0 ? 'Apr 12, 2026 • 09:30 AM' : 'Apr 08, 2026 • 14:00 PM', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: i % 2 == 0 ? AppColors.sky100 : AppColors.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            i % 2 == 0 ? 'Confirmed' : 'Completed',
                            style: AppTextStyles.caption.copyWith(color: i % 2 == 0 ? AppColors.sky600 : AppColors.accentGreen, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (i % 2 != 0) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showRatingPrompt(context, 'Dr. Marie Nkomo'),
                            child: Text('Rate Visit', style: TextStyle(color: AppColors.sky600, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}

class _PatientProfileTab extends StatefulWidget {
  const _PatientProfileTab();

  @override
  State<_PatientProfileTab> createState() => _PatientProfileTabState();
}

class _PatientProfileTabState extends State<_PatientProfileTab> {
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await AuthService.getUserName();
    if (mounted && name != null) setState(() => _userName = name);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final topPad = MediaQuery.of(context).padding.top;
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';

    return Container(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Profile header
          Container(
            padding: EdgeInsets.fromLTRB(w * 0.06, topPad + w * 0.05, w * 0.06, w * 0.06),
            decoration: const BoxDecoration(
              gradient: AppColors.splashBackgroundGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Column(
              children: [
                SizedBox(height: w * 0.02),
                Container(
                  width: w * 0.2, height: w * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  ),
                  child: Center(child: Text(initial, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.08, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
                SizedBox(height: w * 0.035),
                Text(_userName, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.055, fontWeight: FontWeight.w700, color: Colors.white)),
                SizedBox(height: w * 0.01),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.035, vertical: w * 0.012),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('Patient', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: Colors.white70, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),

          SizedBox(height: w * 0.04),

          // Menu sections
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Health', w),
                _ProfileTile(icon: Icons.medical_information_rounded, label: 'Medical Records', onTap: () => context.push('/patient/medical-records')),
                _ProfileTile(icon: Icons.receipt_long_rounded, label: 'Prescriptions', onTap: () => context.push('/patient/prescriptions')),
                _ProfileTile(icon: Icons.science_rounded, label: 'Lab Tests', onTap: () => context.push('/homecare/lab-tests')),

                SizedBox(height: w * 0.02),
                _sectionLabel('Account', w),
                _ProfileTile(icon: Icons.payment_rounded, label: 'Payment History', onTap: () => context.push('/patient/payment-history')),
                _ProfileTile(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => context.push('/notifications')),
                _ProfileTile(icon: Icons.info_outline_rounded, label: 'About Clinix', onTap: () => context.push('/about')),

                SizedBox(height: w * 0.02),
                Divider(color: AppColors.grey100),
                _ProfileTile(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  isDestructive: true,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Log Out'),
                        content: const Text('Are you sure you want to log out?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Logout', style: TextStyle(color: AppColors.error))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await AuthService.logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                ),
                SizedBox(height: w * 0.15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, double w) => Padding(
    padding: EdgeInsets.only(top: w * 0.03, bottom: w * 0.015, left: w * 0.01),
    child: Text(text.toUpperCase(), style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, fontWeight: FontWeight.w700, color: AppColors.grey400, letterSpacing: 1.2)),
  );
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _ProfileTile({required this.icon, required this.label, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final c = isDestructive ? AppColors.error : AppColors.splashSlate900;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: w * 0.035, horizontal: w * 0.01),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(w * 0.025),
              decoration: BoxDecoration(
                color: (isDestructive ? AppColors.error : AppColors.splashSlate900).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: w * 0.05),
            ),
            SizedBox(width: w * 0.035),
            Expanded(child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w500, color: c))),
            if (!isDestructive) Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: w * 0.05),
          ],
        ),
      ),
    );
  }
}

void _showRatingPrompt(BuildContext context, String doctorName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RatingModal(doctorName: doctorName),
  );
}

class _RatingModal extends StatefulWidget {
  final String doctorName;
  const _RatingModal({super.key, required this.doctorName});
  @override
  State<_RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<_RatingModal> {
  int _rating = 0;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text('How was your visit with ${widget.doctorName}?', textAlign: TextAlign.center, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Text('Your feedback helps us improve our healthcare services.', textAlign: TextAlign.center, style: AppTextStyles.caption),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(Icons.star_rounded, size: 44, color: i < _rating ? const Color(0xFFFBBF24) : AppColors.grey200),
              onPressed: () => setState(() => _rating = i + 1),
            )),
          ),
          const SizedBox(height: 24),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any specific feedback? (Optional)',
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.sky500)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: AppColors.accentGreen),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sky600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Submit Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
