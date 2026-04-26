import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../shared/widgets/custom_sidebar_drawer.dart';
import '../../../shared/widgets/bubble_bottom_bar.dart';
import '../../../appointments/screens/video_consultation_screen.dart';

class _ProviderApi {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ))..interceptors.add(InterceptorsWrapper(
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          try {
            final retryResponse = await Dio().fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (e) {
            return handler.next(error);
          }
        }
      }
      return handler.next(error);
    },
  ));

  static Future<Options> _authOptions() async {
    var token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      token = await AuthService.refreshAccessToken();
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  static Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _dio.get(
      '${ApiConstants.providers}profile/',
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch(
      '${ApiConstants.providers}profile/',
      data: data,
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<String> uploadProfilePhoto(XFile file) async {
    final storageRef = FirebaseStorage.instance.ref().child(
      'provider_photos/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
    );
    await storageRef.putFile(File(file.path));
    final url = await storageRef.getDownloadURL();
    await updateProfile({'profile_photo': url});
    return url;
  }

  static Future<Map<String, dynamic>> fetchEarnings() async {
    final response = await _dio.get(
      '${ApiConstants.providers}earnings/',
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<void> requestWithdrawal({
    required String amount,
    required String method,
    required String details,
  }) async {
    await _dio.post(
      '${ApiConstants.providers}withdraw/',
      data: {
        'amount': amount,
        'method': method,
        'details': details,
      },
      options: await _authOptions(),
    );
  }

  static Future<List<Map<String, dynamic>>> fetchCredentials() async {
    final response = await _dio.get(
      '${ApiConstants.providers}credentials/',
      options: await _authOptions(),
    );
    final data = response.data;
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<void> uploadCredential({
    required String documentType,
    required XFile file,
  }) async {
    final formData = FormData.fromMap({
      'document_type': documentType,
      'document': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    final authOpts = await _authOptions();
    await _dio.post(
      '${ApiConstants.providers}credentials/',
      data: formData,
      options: authOpts.copyWith(contentType: 'multipart/form-data'),
    );
  }
}

class ProviderHomePage extends StatefulWidget {
  const ProviderHomePage({super.key});

  @override
  State<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  int _selectedTab = 0;

  final List<Widget> _pages = const [
    _ProviderDashboard(),
    _ProviderScheduleTab(),
    _ProviderEarningsTab(),
    _ProviderProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      drawer: CustomSidebarDrawer(
        currentIndex: _selectedTab,
        onTabSelected: (i) => setState(() => _selectedTab = i),
        isProvider: true,
      ),
      body: IndexedStack(index: _selectedTab, children: _pages),
      bottomNavigationBar: BubbleBottomBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        items: [
          BubbleNavItem(icon: Icons.dashboard_rounded, label: 'Dash'),
          BubbleNavItem(icon: Icons.calendar_month_rounded, label: 'Sched'),
          BubbleNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Wallet'),
          BubbleNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}

class _ProviderBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _ProviderBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.dashboard_rounded, label: 'Dash', isSelected: currentIndex == 0, onTap: () => onTap(0)),
              _NavItem(icon: Icons.calendar_month_rounded, label: 'Sched', isSelected: currentIndex == 1, onTap: () => onTap(1)),
              _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Earn', isSelected: currentIndex == 2, onTap: () => onTap(2)),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', isSelected: currentIndex == 3, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool isSelected; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20.0 : 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C2C2C) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
            ]
          ],
        ),
      ),
    );
  }
}

class _ProviderDashboard extends StatefulWidget {
  const _ProviderDashboard();

  @override
  State<_ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<_ProviderDashboard> {
  String _providerName = 'Doctor';
  String _greeting = 'Good Day';
  IconData _greetingIcon = Icons.wb_sunny_rounded;
  int _todayAppointments = 0;
  int _pendingRequests = 0;
  double _rating = 0.0;
  List<Map<String, dynamic>> _appointments = [];
  bool _loadingDashboard = true;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadProviderName();
    _loadDashboard();
    _loadAppointments();
    _resolveGreeting();
  }

  void _resolveGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      _greeting = 'Good Morning';
      _greetingIcon = Icons.wb_twilight_rounded;
    } else if (hour >= 12 && hour < 17) {
      _greeting = 'Good Afternoon';
      _greetingIcon = Icons.wb_sunny_rounded;
    } else {
      _greeting = 'Good Evening';
      _greetingIcon = Icons.nightlight_round;
    }
  }

  Future<void> _loadProviderName() async {
    final name = await AuthService.getUserName();
    if (!mounted) return;
    setState(() {
      _providerName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Doctor';
    });
  }

  Future<void> _loadDashboard() async {
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.providers}dashboard/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!mounted) return;
      final d = res.data as Map?;
      if (d != null) {
        setState(() {
          _todayAppointments = (d['today_appointments'] as num?)?.toInt() ?? 0;
          _pendingRequests = (d['pending_requests'] as num?)?.toInt() ?? 0;
          _rating = double.tryParse(d['rating']?.toString() ?? '') ?? 0.0;
          _loadingDashboard = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDashboard = false);
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.appointments}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!mounted) return;
      final data = res.data;
      List raw = data is List ? data : [];
      // Filter to today's appointments
      final today = DateTime.now();
      final todayAppts = raw.where((a) {
        final dt = DateTime.tryParse(a['scheduled_at']?.toString() ?? '');
        return dt != null && dt.year == today.year && dt.month == today.month && dt.day == today.day;
      }).map((a) => Map<String, dynamic>.from(a as Map)).toList();

      // If none today, fall back to 3 most recent
      List<Map<String, dynamic>> toShow = todayAppts;
      if (toShow.isEmpty) {
        toShow = raw.take(3).map((a) => Map<String, dynamic>.from(a as Map)).toList();
      }
      setState(() => _appointments = toShow);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final hp = w * 0.05;
    final initial = _providerName.isNotEmpty ? _providerName[0].toUpperCase() : 'D';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.grey50,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          toolbarHeight: 80,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 50, height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.darkBlue500,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.darkBlue500.withOpacity(0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2, bottom: -2,
                        child: Container(
                          width: 18, height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.grey200),
                          ),
                          child: const Icon(Icons.menu_rounded, color: AppColors.darkBlue900, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(_greetingIcon, size: 14, color: AppColors.darkBlue500),
                          const SizedBox(width: 6),
                          Text(
                            'Dr. $_greeting',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.grey500,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkBlue900,
                          height: 1.1,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 48, height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: AppColors.darkBlue900, size: 22),
                  ),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: GestureDetector(
                onTap: () => setState(() => _isAvailable = !_isAvailable),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (_isAvailable ? AppColors.accentGreen : AppColors.grey400).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _isAvailable ? AppColors.accentGreen : AppColors.grey400,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isAvailable ? 'Online · accepting consults' : 'Offline · paused',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _isAvailable ? AppColors.darkBlue900 : AppColors.grey500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Tap to toggle',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.grey500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36, height: 22,
                        decoration: BoxDecoration(
                          color: _isAvailable ? AppColors.darkBlue500 : AppColors.grey200,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          alignment: _isAvailable ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Container(
                              width: 18, height: 18,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hp, w * 0.05, hp, mq.padding.bottom + 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Stats — three chunky white cards (matches patient feature cards)
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Today', value: '$_todayAppointments', icon: Icons.today_rounded)),
                  SizedBox(width: w * 0.03),
                  Expanded(child: _StatCard(label: 'Pending', value: '$_pendingRequests', icon: Icons.pending_actions_rounded)),
                  SizedBox(width: w * 0.03),
                  Expanded(child: _StatCard(label: 'Rating', value: _rating > 0 ? _rating.toStringAsFixed(1) : '—', icon: Icons.star_rounded)),
                ],
              ),
              SizedBox(height: w * 0.06),

              // Today's Appointments
              Text(
                "Today's Appointments",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: w * 0.042,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBlue900,
                ),
              ),
              SizedBox(height: w * 0.03),
              if (_loadingDashboard)
                Container(
                  padding: EdgeInsets.all(w * 0.06),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: const Center(child: CircularProgressIndicator(color: AppColors.darkBlue500, strokeWidth: 2)),
                )
              else if (_appointments.isEmpty)
                Container(
                  padding: EdgeInsets.all(w * 0.06),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_available_rounded, size: 36, color: AppColors.grey400),
                      SizedBox(height: w * 0.02),
                      Text(
                        'No appointments today',
                        style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, color: AppColors.grey500, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                ..._appointments.map((a) => _ProviderApptCard(appointment: a)),
              SizedBox(height: w * 0.05),
              Row(
                children: [
                  Expanded(
                    child: _ProviderQuickCard(
                      icon: Icons.description_outlined,
                      label: 'Prescription',
                      onTap: () => context.push('/provider/prescription/new'),
                    ),
                  ),
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: _ProviderQuickCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Patient Chats',
                      onTap: () => context.push('/provider/messages'),
                    ),
                  ),
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: _ProviderQuickCard(
                      icon: Icons.bar_chart_rounded,
                      label: 'View Earnings',
                      onTap: () {
                        final state = context.findAncestorStateOfType<_ProviderHomePageState>();
                        state?.setState(() => state._selectedTab = 2);
                      },
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.symmetric(vertical: w * 0.04, horizontal: w * 0.025),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(w * 0.022),
            decoration: BoxDecoration(
              color: AppColors.darkBlue500.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.darkBlue500, size: w * 0.045),
          ),
          SizedBox(height: w * 0.025),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: w * 0.058,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue900,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: w * 0.008),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: w * 0.028,
              fontWeight: FontWeight.w600,
              color: AppColors.grey500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderApptCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  const _ProviderApptCard({required this.appointment});

  String _patientName() {
    final p = appointment['patient'];
    if (p is Map) {
      return p['user']?['full_name']?.toString()
          ?? p['full_name']?.toString()
          ?? 'Patient';
    }
    return 'Patient';
  }

  @override
  Widget build(BuildContext context) {
    final status = appointment['status']?.toString() ?? 'pending';
    final type = appointment['appointment_type']?.toString() ?? 'virtual';
    final isVideo = type == 'virtual';
    final isLabTest = type == 'lab_test';
    final isHomeTreatment = type == 'home_treatment';
    final isService = isLabTest || isHomeTreatment;
    final dateStr = appointment['scheduled_at']?.toString();
    final date = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;
    final time = date != null ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}' : '--:--';
    final apptId = appointment['appointment_id']?.toString() ?? '';
    final consultationId = appointment['consultation_id']?.toString() ?? apptId;
    final name = _patientName();
    final address = appointment['address']?.toString() ?? '';
    final serviceName = appointment['service_name']?.toString() ?? '';

    String typeLabel() {
      if (isLabTest) return serviceName.isNotEmpty ? 'Lab Test · $serviceName' : 'Lab Test';
      if (isHomeTreatment) return serviceName.isNotEmpty ? serviceName : 'Home Treatment';
      if (isVideo) return 'Video';
      return 'In-Person';
    }

    IconData typeIcon() {
      if (isLabTest) return Icons.biotech_rounded;
      if (isHomeTreatment) return Icons.home_filled;
      if (isVideo) return Icons.videocam_rounded;
      return Icons.local_hospital_rounded;
    }

    final isPending = status == 'pending';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';

    Color statusColor;
    if (isPending) {
      statusColor = AppColors.accentOrange;
    } else if (isCancelled) {
      statusColor = AppColors.error;
    } else if (isCompleted) {
      statusColor = AppColors.grey500;
    } else {
      statusColor = AppColors.accentGreen;
    }

    final initials = _initialsFromName(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.darkBlue500, shape: BoxShape.circle),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkBlue900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(typeIcon(), color: AppColors.darkBlue500, size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${typeLabel()} · $time',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.grey500, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (isService && address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.grey400, size: 12),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.grey500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (!isCompleted && !isCancelled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => apptId.isEmpty ? null : context.push('/appointments/$apptId'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      side: const BorderSide(color: AppColors.grey200),
                      foregroundColor: AppColors.darkBlue900,
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (isVideo) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoConsultationScreen(
                              consultationId: consultationId,
                              doctorName: name,
                              audioOnly: false,
                            ),
                          ),
                        );
                      } else {
                        context.push('/provider/messages');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkBlue500,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    child: Text(
                      isVideo ? 'Start Call' : (isService ? 'Message' : 'Open Chat'),
                      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _initialsFromName(String fullName) {
    final cleaned = fullName
        .replaceAll(RegExp(r'^(Dr\.?|Doctor|Mr\.?|Mrs\.?|Ms\.?)\s+', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class _ProviderQuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ProviderQuickCard({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: w * 0.045, horizontal: w * 0.025),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(w * 0.022),
              decoration: BoxDecoration(
                color: AppColors.darkBlue500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.darkBlue500, size: w * 0.05),
            ),
            SizedBox(height: w * 0.025),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: w * 0.032,
                fontWeight: FontWeight.w800,
                color: AppColors.darkBlue900,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderScheduleTab extends StatefulWidget {
  const _ProviderScheduleTab();

  @override
  State<_ProviderScheduleTab> createState() => _ProviderScheduleTabState();
}

class _ProviderScheduleTabState extends State<_ProviderScheduleTab> {
  static const _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _hours = ['06:00','07:00','08:00','09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00','19:00','20:00','21:00'];

  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      final token = await AuthService.getAccessToken();
      final response = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.providers}schedule/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      final List raw = data['schedules'] ?? [];
      setState(() {
        _schedules = _days.map((day) {
          final match = raw.firstWhere((s) => s['day'] == day, orElse: () => null);
          return {
            'day': day,
            'is_working': match?['is_working'] ?? false,
            'start_time': match?['start_time'] ?? '08:00',
            'end_time': match?['end_time'] ?? '17:00',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    try {
      final token = await AuthService.getAccessToken();
      await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.providers}schedule/',
        data: {'schedules': _schedules},
        options: Options(headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule saved'), backgroundColor: AppColors.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save schedule'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _applyToAllWorkingDays(int sourceIndex) {
    final src = _schedules[sourceIndex];
    setState(() {
      for (var i = 0; i < _schedules.length; i++) {
        if (i == sourceIndex) continue;
        if (_schedules[i]['is_working'] == true) {
          _schedules[i]['start_time'] = src['start_time'];
          _schedules[i]['end_time'] = src['end_time'];
        }
      }
    });
  }

  int get _workingDayCount => _schedules.where((s) => s['is_working'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.darkBlue900,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 150,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Text('My Schedule',
                  style: AppTextStyles.headlineMedium.copyWith(color: Colors.white, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 50),
                alignment: Alignment.bottomLeft,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.event_available_rounded, color: AppColors.sky200, size: 16),
                        const SizedBox(width: 6),
                        Text('$_workingDayCount working days',
                            style: AppTextStyles.caption.copyWith(color: AppColors.sky200, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveSchedule,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sky500,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Save', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.sky500)))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.sky100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.sky600, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Set your working hours. Patients can only book slots inside these windows.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.darkBlue900, height: 1.4),
                              ),
                            ),
                          ]),
                        ),
                      );
                    }
                    final s = _schedules[index - 1];
                    return _ScheduleRow(
                      day: s['day'] as String,
                      dayLabel: _dayLabels[_days.indexOf(s['day'] as String)],
                      isWorking: s['is_working'] == true,
                      startTime: s['start_time']?.toString() ?? '08:00',
                      endTime: s['end_time']?.toString() ?? '17:00',
                      hours: _hours,
                      onToggle: (v) => setState(() => _schedules[index - 1]['is_working'] = v),
                      onStartChanged: (v) => setState(() => _schedules[index - 1]['start_time'] = v),
                      onEndChanged: (v) => setState(() => _schedules[index - 1]['end_time'] = v),
                      onCopyToAll: () => _applyToAllWorkingDays(index - 1),
                    );
                  },
                  childCount: _schedules.length + 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String day;
  final String dayLabel;
  final bool isWorking;
  final String startTime;
  final String endTime;
  final List<String> hours;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;
  final VoidCallback onCopyToAll;

  const _ScheduleRow({
    required this.day,
    required this.dayLabel,
    required this.isWorking,
    required this.startTime,
    required this.endTime,
    required this.hours,
    required this.onToggle,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onCopyToAll,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isWorking ? AppColors.sky200 : AppColors.grey200),
        boxShadow: isWorking
            ? [BoxShadow(color: AppColors.sky500.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: isWorking ? AppColors.sky500 : AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    dayLabel,
                    style: TextStyle(
                      color: isWorking ? Colors.white : AppColors.grey500,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fullDayName(day),
                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
                    Text(
                      isWorking ? '$startTime – $endTime' : 'Not available',
                      style: AppTextStyles.caption.copyWith(
                        color: isWorking ? AppColors.sky600 : AppColors.grey400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isWorking,
                activeColor: AppColors.sky500,
                onChanged: onToggle,
              ),
            ],
          ),
          if (isWorking) ...[
            const Divider(height: 24, color: AppColors.grey100),
            Row(
              children: [
                Expanded(
                  child: _TimeDropdown(
                    label: 'From',
                    value: startTime,
                    options: hours,
                    onChanged: onStartChanged,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, color: AppColors.grey400, size: 18),
                ),
                Expanded(
                  child: _TimeDropdown(
                    label: 'To',
                    value: endTime,
                    options: hours,
                    onChanged: onEndChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCopyToAll,
                icon: const Icon(Icons.content_copy_rounded, size: 14),
                label: const Text('Apply to all working days'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sky600,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fullDayName(String day) {
    switch (day) {
      case 'monday': return 'Monday';
      case 'tuesday': return 'Tuesday';
      case 'wednesday': return 'Wednesday';
      case 'thursday': return 'Thursday';
      case 'friday': return 'Friday';
      case 'saturday': return 'Saturday';
      case 'sunday': return 'Sunday';
      default: return day;
    }
  }
}

class _TimeDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _TimeDropdown({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : options.first,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.grey400),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkBlue900, fontSize: 14, fontWeight: FontWeight.w600),
              items: options.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderEarningsTab extends StatefulWidget {
  const _ProviderEarningsTab();

  @override
  State<_ProviderEarningsTab> createState() => _ProviderEarningsTabState();
}

class _ProviderEarningsTabState extends State<_ProviderEarningsTab> {
  Map<String, dynamic>? _earnings;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      final data = await _ProviderApi.fetchEarnings();
      if (!mounted) return;
      setState(() {
        _earnings = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Wallet] Load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load wallet data.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: AppTextStyles.bodyMedium));
    }

    final balance = (_earnings?['balance'] ?? 0).toString();
    final pendingWithdrawals = (_earnings?['pending_withdrawals'] ?? 0).toString();
    final verificationStatus = (_earnings?['verification_status'] ?? 'pending').toString();
    final transactions = (_earnings?['recent_transactions'] as List?) ?? const [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text("Revenue & Wallet", style: AppTextStyles.displayLarge.copyWith(color: AppColors.darkBlue900, fontSize: 26)),
          const SizedBox(height: 24),
          
          // Premium Glass Wallet Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.darkBlue900, AppColors.sky600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: AppColors.sky500.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 15)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Available to Withdraw", style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky100, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text("$balance XAF", style: AppTextStyles.displayLarge.copyWith(fontSize: 32, letterSpacing: -0.5)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    _EarningStat(label: 'Pending', value: '$pendingWithdrawals XAF'),
                    _EarningStat(label: 'KYC', value: verificationStatus.toUpperCase()),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.darkBlue900,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _showPayoutModal(context, onSubmitted: _loadEarnings),
                        child: const Text("Request Payout", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 35),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recent Transactions", style: AppTextStyles.headlineMedium),
              Text("View All", style: AppTextStyles.caption.copyWith(color: AppColors.sky600, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.grey200)),
              child: Text('No transactions yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
            )
          else
            ...transactions.map((tx) => _buildTxItem(
              (tx['type']?.toString() == 'credit') ? 'Consultation Payout' : 'Withdrawal',
              tx['date']?.toString() ?? '',
              tx['amount']?.toString() ?? '0',
              tx['type']?.toString() == 'credit',
            )),
          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildTxItem(String title, String time, String amount, bool isCredit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit ? AppColors.accentGreen.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? AppColors.accentGreen : AppColors.error, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                Text(time, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            "${isCredit ? '+' : '-'}$amount XAF",
            style: AppTextStyles.headlineSmall.copyWith(
              color: isCredit ? AppColors.accentGreen : AppColors.darkBlue900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningStat extends StatelessWidget {
  final String label, value;
  const _EarningStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.sky200, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.headlineSmall.copyWith(color: AppColors.white, fontSize: 13)),
      ],
    ));
  }
}

class _ProviderProfileTab extends StatefulWidget {
  const _ProviderProfileTab();

  @override
  State<_ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends State<_ProviderProfileTab> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _credentials = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _ProviderApi.fetchProfile();
      List<Map<String, dynamic>> credentials = [];
      try {
        credentials = await _ProviderApi.fetchCredentials();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _credentials = credentials;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ProviderProfile] Load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile. Check connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (image == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading photo...'), duration: Duration(seconds: 2)));
    }

    try {
      await _ProviderApi.uploadProfilePhoto(image);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated!'), backgroundColor: AppColors.accentGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo upload failed'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: AppTextStyles.bodyMedium));
    }

    final providerName = _profile?['full_name']?.toString() ?? 'Provider';
    final profilePhoto = _profile?['user_photo']?.toString() ?? '';
    final verificationStatus = (_profile?['verification_status'] ?? 'pending').toString();
    final specialty = (_profile?['other_specialty']?.toString().trim().isNotEmpty ?? false)
        ? _profile!['other_specialty'].toString()
        : (_profile?['specialty']?.toString() ?? 'Healthcare Provider');
    final feeText = (_profile?['consultation_fee'] ?? 0).toString();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 40),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _pickAndUploadProfilePhoto(),
                  child: Stack(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          image: profilePhoto.isNotEmpty
                              ? DecorationImage(image: NetworkImage(profilePhoto), fit: BoxFit.cover)
                              : null,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                        ),
                        child: profilePhoto.isEmpty
                            ? const Icon(Icons.person_rounded, color: AppColors.sky600, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppColors.sky500, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.camera_alt_rounded, color: AppColors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(providerName, style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white)),
                Text(specialty, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Consultation Fee', style: AppTextStyles.headlineSmall.copyWith(fontSize: 15)),
                          const SizedBox(height: 6),
                          Text('$feeText XAF', style: AppTextStyles.displayLarge.copyWith(fontSize: 24, color: AppColors.darkBlue900)),
                          const SizedBox(height: 4),
                          Text('This is the amount patients pay for your consultation.', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showEditFeeModal(context, _profile!, onSaved: _loadProfile),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Bio preview so the provider sees live updates
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Biography', style: AppTextStyles.headlineSmall.copyWith(fontSize: 15)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _showEditBioModal(context, _profile!, onSaved: _loadProfile),
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (_profile?['bio']?.toString().trim().isNotEmpty ?? false)
                          ? _profile!['bio'].toString()
                          : 'Add a short professional bio so patients know who you are.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Show verify CTA only if the doctor hasn't uploaded anything yet
              // (once credentials are submitted, everything verification-related disappears).
              if (_credentials.isEmpty && verificationStatus != 'approved') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316)),
                          const SizedBox(width: 12),
                          Text('Verify Profile',
                              style: AppTextStyles.headlineSmall.copyWith(color: const Color(0xFFC2410C), fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Submit National ID front, National ID back, and your medical license for admin KYC approval.',
                          style: AppTextStyles.caption.copyWith(color: const Color(0xFF9A3412))),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showVerifyProfileModal(context, onUploaded: _loadProfile),
                          child: const Text('Verify Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                _ProfileMenuItem(
                  icon: Icons.verified_user_outlined,
                  label: 'Verify Profile',
                  onTap: () => _showVerifyProfileModal(context, onUploaded: _loadProfile),
                ),
              ],
              _ProfileMenuItem(
                icon: Icons.edit_note_rounded,
                label: 'Edit Profile & Bio',
                onTap: () => _showEditBioModal(context, _profile!, onSaved: _loadProfile),
              ),
              _ProfileMenuItem(
                icon: Icons.schedule_rounded,
                label: 'My Schedule',
                onTap: () {
                  final state = context.findAncestorStateOfType<_ProviderHomePageState>();
                  state?.setState(() => state._selectedTab = 1);
                },
              ),
              _ProfileMenuItem(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () => context.push('/notifications'),
              ),
              _ProfileMenuItem(
                icon: Icons.info_outline_rounded,
                label: 'About Clinix',
                onTap: () => context.push('/about'),
              ),
              _ProfileMenuItem(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                color: AppColors.error,
                onTap: () async {
                  await AuthService.logoutAndClear(context);
                  if (context.mounted) context.go('/login');
                },
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ProfileMenuItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.darkBlue800;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: c, size: 20)),
        title: Text(label, style: AppTextStyles.headlineSmall.copyWith(fontSize: 14, color: c)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 20),
      ),
    );
  }
}

void _showPayoutModal(BuildContext context, {required Future<void> Function() onSubmitted}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PayoutModal(onSubmitted: onSubmitted),
  );
}

class _PayoutModal extends StatefulWidget {
  final Future<void> Function() onSubmitted;
  const _PayoutModal({required this.onSubmitted});
  @override
  State<_PayoutModal> createState() => _PayoutModalState();
}

class _PayoutModalState extends State<_PayoutModal> {
  String _payoutMethod = 'mtn_momo';
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(25, 25, 25, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 24),
          Text('Withdraw Earnings', style: AppTextStyles.headlineLarge.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text('Withdrawals are processed via Mobile Money once approved by Clinix administrators. Allow 24–48 hours.',
              style: AppTextStyles.caption.copyWith(color: AppColors.grey500, height: 1.4)),
          const SizedBox(height: 24),

          Text('Mobile Money Network', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _MethodChip(label: 'MTN MoMo', selected: _payoutMethod == 'mtn_momo', onTap: () => setState(() => _payoutMethod = 'mtn_momo')),
              const SizedBox(width: 12),
              _MethodChip(label: 'Orange Money', selected: _payoutMethod == 'orange_money', onTap: () => setState(() => _payoutMethod = 'orange_money')),
            ],
          ),
          const SizedBox(height: 20),

          Text('Amount', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'XAF',
              prefixIcon: const Icon(Icons.payments_rounded, color: AppColors.sky500, size: 20),
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Text('Mobile Money Number', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+237 6XX XXX XXX',
              prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.sky500, size: 20),
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.sky100.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.sky600, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Admin reviews and approves payouts. Funds are sent via CamPay to your selected number.', style: AppTextStyles.caption.copyWith(color: AppColors.darkBlue900, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : () async {
                final phone = _numberController.text.trim();
                final amount = _amountController.text.trim();
                if (amount.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter both amount and phone number')));
                  return;
                }
                setState(() => _submitting = true);
                try {
                  await _ProviderApi.requestWithdrawal(
                    amount: amount,
                    method: _payoutMethod,
                    details: phone,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await widget.onSubmitted();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout request submitted for admin approval.'), backgroundColor: AppColors.accentGreen));
                } on DioException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.response?.data?.toString() ?? 'Could not submit payout request.')));
                } finally {
                  if (mounted) setState(() => _submitting = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sky500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit for Approval', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _MethodChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.sky500 : AppColors.grey50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.sky500 : AppColors.grey200),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.grey700, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

void _showEditFeeModal(
  BuildContext context,
  Map<String, dynamic> profile, {
  required Future<void> Function() onSaved,
}) {
  final controller = TextEditingController(text: (profile['consultation_fee'] ?? '').toString());
  bool saving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Consultation Fee', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text('Set the amount patients pay for each consultation.', style: AppTextStyles.caption),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter amount in XAF',
                    filled: true,
                    fillColor: AppColors.grey50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setModalState(() => saving = true);
                            try {
                              await _ProviderApi.updateProfile({
                                'consultation_fee': controller.text.trim(),
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                                await onSaved();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Consultation fee updated successfully.')),
                                );
                              }
                            } on DioException catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.response?.data?.toString() ?? 'Could not update consultation fee.')),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setModalState(() => saving = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sky600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Fee'),
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

void _showVerifyProfileModal(
  BuildContext context, {
  required Future<void> Function() onUploaded,
}) {
  final picker = ImagePicker();
  XFile? idFront;
  XFile? idBack;
  XFile? license;
  bool saving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickFile(String type) async {
            final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (file == null) return;
            setModalState(() {
              if (type == 'front') idFront = file;
              if (type == 'back') idBack = file;
              if (type == 'license') license = file;
            });
          }

          Widget fileTile(String title, XFile? file, VoidCallback onTap) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.file_present_rounded, color: AppColors.sky500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                        Text(file?.name ?? 'No file selected', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  TextButton(onPressed: onTap, child: const Text('Choose')),
                ],
              ),
            );
          }

          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verify Profile', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text('Upload the required KYC files for admin approval before you are listed.', style: AppTextStyles.caption),
                const SizedBox(height: 16),
                fileTile('National ID Front', idFront, () => pickFile('front')),
                fileTile('National ID Back', idBack, () => pickFile('back')),
                fileTile('Medical License', license, () => pickFile('license')),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving || idFront == null || idBack == null || license == null
                        ? null
                        : () async {
                            setModalState(() => saving = true);
                            try {
                              await _ProviderApi.uploadCredential(documentType: 'national_id_front', file: idFront!);
                              await _ProviderApi.uploadCredential(documentType: 'national_id_back', file: idBack!);
                              await _ProviderApi.uploadCredential(documentType: 'medical_license', file: license!);
                              if (context.mounted) {
                                Navigator.pop(context);
                                await onUploaded();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('KYC submitted. Awaiting admin verification.')),
                                );
                              }
                            } on DioException catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.response?.data?.toString() ?? 'Could not upload KYC documents.')),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setModalState(() => saving = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sky600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit for Verification'),
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

String _credentialLabel(String type) {
  switch (type) {
    case 'national_id_front':
      return 'National ID Front';
    case 'national_id_back':
      return 'National ID Back';
    case 'medical_license':
      return 'Medical License';
    default:
      return type.replaceAll('_', ' ');
  }
}

void _showEditBioModal(
  BuildContext context,
  Map<String, dynamic> profile, {
  required Future<void> Function() onSaved,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _EditBioModal(profile: profile, onSaved: onSaved),
  );
}

class _EditBioModal extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Future<void> Function() onSaved;

  const _EditBioModal({required this.profile, required this.onSaved});
  @override
  State<_EditBioModal> createState() => _EditBioModalState();
}

class _EditBioModalState extends State<_EditBioModal> {
  late final TextEditingController _bioController;
  late final TextEditingController _yearsController;
  late final TextEditingController _feeController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: (widget.profile['bio'] ?? '').toString());
    _yearsController = TextEditingController(text: (widget.profile['years_experience'] ?? '').toString());
    _feeController = TextEditingController(text: (widget.profile['consultation_fee'] ?? '').toString());
  }

  @override
  void dispose() {
    _bioController.dispose();
    _yearsController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.grey50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(25, 25, 25, MediaQuery.of(context).viewInsets.bottom + 32),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Text('Edit Profile', style: AppTextStyles.headlineLarge.copyWith(fontSize: 22)),
            const SizedBox(height: 6),
            Text('Patients see this info. Ratings and reviews are generated by the system based on patient feedback.', style: AppTextStyles.caption),
            const SizedBox(height: 20),

            Text('Biography', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            TextField(controller: _bioController, maxLines: 4, decoration: _decoration('Tell patients about your practice...')),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Years of Experience', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(controller: _yearsController, keyboardType: TextInputType.number, decoration: _decoration('e.g. 5')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Consultation Fee (XAF)', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(controller: _feeController, keyboardType: TextInputType.number, decoration: _decoration('e.g. 5000')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : () async {
                setState(() => _saving = true);
                try {
                  final payload = <String, dynamic>{
                    'bio': _bioController.text.trim(),
                  };
                  final years = int.tryParse(_yearsController.text.trim());
                  if (years != null) payload['years_experience'] = years;
                  final fee = double.tryParse(_feeController.text.trim());
                  if (fee != null) payload['consultation_fee'] = fee;
                  await _ProviderApi.updateProfile(payload);
                  if (!mounted) return;
                  Navigator.pop(context);
                  await widget.onSaved();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.accentGreen),
                  );
                } on DioException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.response?.data?.toString() ?? 'Could not update profile.')),
                  );
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sky600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
