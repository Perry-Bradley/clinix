import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/appointment_service.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/patient/presentation/pages/patient_home_page.dart';
import '../../features/provider/presentation/pages/provider_home_page.dart';
import '../../features/provider/presentation/pages/write_prescription_page.dart';
import '../../features/patient/screens/book_appointment_screen.dart';
import '../../features/appointments/presentation/pages/appointment_detail_page.dart';
import '../../features/patient/screens/ai_symptom_checker_screen.dart';
import '../../features/patient/screens/nearby_clinics_screen.dart';
import '../../features/patient/screens/chat_screen.dart';
import '../../features/patient/screens/payment_screen.dart';
import '../../features/patient/screens/clinic_profile_screen.dart';
import '../../features/auth/presentation/pages/provider_enrollment_screen.dart';
import '../../features/auth/presentation/pages/role_selection_page.dart';
import '../../features/patient/screens/health_dashboard_screen.dart';
import '../../features/patient/screens/heart_rate_measure_screen.dart';
import '../../features/patient/screens/doctor_profile_screen.dart';
import '../../features/patient/screens/messages_inbox_screen.dart';
import '../../features/patient/screens/notifications_screen.dart';
import '../../features/patient/screens/about_screen.dart';
import '../../features/patient/screens/prescriptions_screen.dart';
import '../../features/patient/screens/medical_records_screen.dart';
import '../../features/patient/screens/payment_history_screen.dart';
import '../../features/patient/screens/direct_chat_screen.dart';
import '../../features/patient/screens/direct_chat_launcher.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const SplashPage()),
    GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),
    GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (c, s) => const RegisterPage(),
      routes: [
        GoRoute(
          path: 'otp',
          builder: (c, s) => OtpPage(
            email: Uri.decodeComponent(s.uri.queryParameters['email'] ?? ''),
          ),
        ),
      ],
    ),
    GoRoute(path: '/patient/home', builder: (c, s) => const PatientHomePage()),
    GoRoute(path: '/provider/home', builder: (c, s) => const ProviderHomePage()),
    GoRoute(path: '/provider/prescription/new', builder: (c, s) => const WritePrescriptionPage()),
    GoRoute(
      path: '/patient/book-appointment',
      builder: (c, s) => BookAppointmentScreen(
        doctor: s.extra ?? {},
      ),
    ),
    GoRoute(
      path: '/patient/payment',
      builder: (c, s) {
        final extra = s.extra as Map<String, dynamic>? ?? {};
        int asInt(dynamic v, int d) {
          if (v is int) return v;
          if (v is num) return v.round();
          return int.tryParse('$v') ?? d;
        }

        return PaymentScreen(
          appointmentId: extra['appointmentId']?.toString() ?? '',
          consultationFee: asInt(extra['consultationFee'], 15000),
        );
      },
    ),
    GoRoute(
      path: '/appointments/:id',
      builder: (c, s) => AppointmentDetailPage(
        appointmentId: s.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(path: '/ai-consult', builder: (c, s) => const AiConsultScreen()),
    GoRoute(path: '/nearby-clinics', builder: (c, s) => const NearbyClinicsScreen()),
    GoRoute(
      path: '/patient/clinic-profile/:placeId',
      builder: (c, s) => ClinicProfileScreen(
        placeId: s.pathParameters['placeId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/patient/doctor-profile/:providerId',
      builder: (c, s) => DoctorProfileScreen(
        providerId: s.pathParameters['providerId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/register/provider-enrollment',
      builder: (c, s) => const ProviderEnrollmentScreen(),
    ),
    GoRoute(path: '/role-selection', builder: (c, s) => const RoleSelectionPage()),
    GoRoute(
      path: '/chat/:cid', 
      builder: (c, s) => ChatScreen(
        consultationId: s.pathParameters['cid'] ?? 'default',
        doctorName: s.uri.queryParameters['doctorName'],
      ),
    ),
    GoRoute(path: '/patient/health', builder: (c, s) => const HealthDashboardScreen()),
    GoRoute(path: '/patient/heart-rate', builder: (c, s) => const HeartRateMeasureScreen()),
    GoRoute(path: '/patient/messages', builder: (c, s) => const MessagesInboxScreen(isProvider: false)),
    GoRoute(path: '/provider/messages', builder: (c, s) => const MessagesInboxScreen(isProvider: true)),
    GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
    GoRoute(path: '/about', builder: (c, s) => const AboutScreen()),
    GoRoute(path: '/patient/prescriptions', builder: (c, s) => const PrescriptionsScreen()),
    GoRoute(path: '/patient/medical-records', builder: (c, s) => const MedicalRecordsScreen()),
    GoRoute(path: '/patient/payment-history', builder: (c, s) => const PaymentHistoryScreen()),
    // Direct messaging (open-to-any-doctor)
    GoRoute(
      path: '/dchat/launch/:providerId',
      builder: (c, s) => DirectChatLauncher(
        providerId: s.pathParameters['providerId'] ?? '',
        doctorName: s.uri.queryParameters['name'],
        doctorPhoto: s.uri.queryParameters['photo'],
      ),
    ),
    GoRoute(
      path: '/dchat/:conversationId',
      builder: (c, s) => DirectChatScreen(
        conversationId: s.pathParameters['conversationId'] ?? '',
        peerName: s.uri.queryParameters['name'],
        peerPhoto: s.uri.queryParameters['photo'],
      ),
    ),
    GoRoute(
      path: '/patient/appointments',
      builder: (c, s) => const _PatientAppointmentsPlaceholder(),
    ),
    GoRoute(
      path: '/provider/appointments',
      builder: (c, s) => const _ProviderAppointmentsPlaceholder(),
    ),
  ],
);

/// Full-screen list of the patient’s appointments (opens from the drawer).
class _PatientAppointmentsPlaceholder extends StatefulWidget {
  const _PatientAppointmentsPlaceholder();

  @override
  State<_PatientAppointmentsPlaceholder> createState() => _PatientAppointmentsPlaceholderState();
}

class _PatientAppointmentsPlaceholderState extends State<_PatientAppointmentsPlaceholder> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AppointmentService.getMyAppointments();
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed': return const Color(0xFF0EA5E9);
      case 'completed': return const Color(0xFF10B981);
      case 'cancelled': return const Color(0xFFEF4444);
      case 'no_show': return const Color(0xFF64748B);
      default: return const Color(0xFFF97316);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('My Appointments', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0A1628))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0A1628), size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : _items.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_rounded, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No appointments yet', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                ]))
              : RefreshIndicator(
                  color: const Color(0xFF0EA5E9),
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final a = _items[i];
                      final id = a['appointment_id']?.toString() ?? '';
                      final status = a['status']?.toString() ?? 'pending';
                      final type = a['appointment_type']?.toString() ?? 'virtual';
                      final dateStr = a['scheduled_at']?.toString() ?? '';
                      final date = DateTime.tryParse(dateStr);
                      final formattedDate = date != null ? '${_dayName(date.weekday)}, ${date.day} ${_monthName(date.month)}' : '';
                      final formattedTime = date != null ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}' : '';

                      // Get provider name
                      String providerName = 'Doctor';
                      final provider = a['provider'];
                      if (provider is Map) {
                        providerName = provider['full_name']?.toString() ?? provider['user']?['full_name']?.toString() ?? 'Doctor';
                      }

                      final sc = _statusColor(status);

                      return GestureDetector(
                        onTap: id.isEmpty ? null : () => context.push('/appointments/$id'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: sc.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  type == 'virtual' ? Icons.video_call_rounded : Icons.local_hospital_rounded,
                                  color: sc, size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(providerName, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0A1628)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Text('$formattedDate  $formattedTime', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade500)),
                                ],
                              )),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: sc.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status[0].toUpperCase() + status.substring(1),
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: sc),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _dayName(int wd) => const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][wd];
  String _monthName(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}

class _ProviderAppointmentsPlaceholder extends StatefulWidget {
  const _ProviderAppointmentsPlaceholder();

  @override
  State<_ProviderAppointmentsPlaceholder> createState() => _ProviderAppointmentsPlaceholderState();
}

class _ProviderAppointmentsPlaceholderState extends State<_ProviderAppointmentsPlaceholder> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AppointmentService.getMyAppointments();
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Appointments', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0A1628))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0A1628), size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final a = _items[i];
                  final id = a['appointment_id']?.toString() ?? '';
                  final when = a['scheduled_at']?.toString() ?? '';
                  final u = a['patient']?['user'];
                  final name = u is Map ? u['full_name']?.toString() ?? 'Patient' : 'Patient';
                  final status = a['status']?.toString() ?? 'pending';
                  return GestureDetector(
                    onTap: id.isEmpty ? null : () => context.push('/appointments/$id'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: const Color(0xFFE0F4FF), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.person_rounded, color: Color(0xFF0EA5E9), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0A1628))),
                          Text(when, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade500)),
                        ])),
                        Text(status, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: status == 'confirmed' ? const Color(0xFF10B981) : const Color(0xFFF97316))),
                      ]),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
