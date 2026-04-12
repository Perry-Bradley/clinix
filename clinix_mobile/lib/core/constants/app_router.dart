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
          serviceCharge: asInt(extra['serviceCharge'], 500),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My appointments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final a = _items[i];
                  final id = a['appointment_id']?.toString() ?? '';
                  final when = a['scheduled_at']?.toString() ?? '';
                  final status = a['status']?.toString() ?? '';
                  return ListTile(
                    title: Text(when.isEmpty ? 'Appointment' : when),
                    subtitle: Text(status),
                    onTap: id.isEmpty ? null : () => context.push('/appointments/$id'),
                  );
                },
              ),
            ),
    );
  }
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
      appBar: AppBar(title: const Text('Appointments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final a = _items[i];
                  final id = a['appointment_id']?.toString() ?? '';
                  final when = a['scheduled_at']?.toString() ?? '';
                  final u = a['patient']?['user'];
                  final name = u is Map ? u['full_name']?.toString() : null;
                  return ListTile(
                    title: Text(name ?? 'Patient'),
                    subtitle: Text('$when • ${a['status'] ?? ''}'),
                    onTap: id.isEmpty ? null : () => context.push('/appointments/$id'),
                  );
                },
              ),
            ),
    );
  }
}
