import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/patient/presentation/pages/patient_home_page.dart';
import '../../features/provider/presentation/pages/provider_home_page.dart';
import '../../features/provider/presentation/pages/write_prescription_page.dart';
import '../../features/provider/presentation/pages/medical_record_form_page.dart';
import '../../features/provider/presentation/pages/referral_form_page.dart';
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
import '../../features/patient/screens/homecare_landing_screen.dart';
import '../../features/patient/screens/lab_tests_screen.dart';
import '../../features/patient/screens/book_lab_test_screen.dart';
import '../../features/patient/screens/home_treatment_screen.dart';
import '../../features/patient/screens/medication_reminders_screen.dart';
import '../../features/patient/screens/nurses_list_screen.dart';
import '../../features/appointments/screens/incoming_call_screen.dart';
import '../../features/appointments/screens/call_history_screen.dart';
import '../../features/provider/screens/provider_appointments_screen.dart';
import '../../features/provider/screens/lab_tech_workflow_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final currentLocation = state.uri.path;
    
    // Check if user is already logged in to skip splash screen
    final token = await AuthService.getAccessToken();
    final userType = await AuthService.getUserType();
    final onboardingSeen = await const FlutterSecureStorage().read(key: 'onboarding_seen');

    // If user is trying to access splash/login/onboarding while authenticated, redirect to home
    if (token != null && (currentLocation == '/splash' || currentLocation == '/login' || currentLocation == '/onboarding')) {
      if (userType == 'unassigned') {
        return '/role-selection';
      } else if (userType == 'provider') {
        return '/provider/home';
      } else {
        return '/patient/home';
      }
    }

    // If user is trying to access protected route while not authenticated, redirect to login
    if (token == null && !currentLocation.startsWith('/login') && !currentLocation.startsWith('/register') && !currentLocation.startsWith('/onboarding')) {
      return '/login';
    }

    // If on splash and onboarding not seen, go to onboarding
    if (currentLocation == '/splash' && onboardingSeen != 'true') {
      return '/onboarding';
    }

    // If on splash and authenticated, redirect to appropriate home
    if (currentLocation == '/splash' && token != null) {
      if (userType == 'unassigned') {
        return '/role-selection';
      } else if (userType == 'provider') {
        return '/provider/home';
      } else {
        return '/patient/home';
      }
    }

    return null; // No redirect needed
  },
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

        final pending = extra['pendingBooking'];
        return PaymentScreen(
          appointmentId: extra['appointmentId']?.toString() ?? '',
          consultationFee: asInt(extra['consultationFee'], 15000),
          pendingBooking: pending is Map ? Map<String, dynamic>.from(pending) : null,
          summaryLabel: extra['summaryLabel']?.toString(),
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
      path: '/patient/nurses',
      builder: (c, s) => const NursesListScreen(),
    ),
    GoRoute(
      path: '/calls',
      builder: (c, s) => const CallHistoryScreen(),
    ),
    GoRoute(
      path: '/incoming-call',
      builder: (c, s) {
        final extra = s.extra as Map<String, dynamic>? ?? {};
        final q = s.uri.queryParameters;
        return IncomingCallScreen(
          consultationId:
              extra['consultationId']?.toString() ?? q['consultation_id'] ?? '',
          callerName: extra['callerName']?.toString() ??
              q['caller_name'] ??
              'Caller',
          callerPhoto:
              extra['callerPhoto']?.toString() ?? q['caller_photo'],
          audioOnly: (extra['audioOnly'] is bool)
              ? extra['audioOnly'] as bool
              : (q['audio_only']?.toLowerCase() == 'true'),
          autoAccept: q['auto_accept'] == '1' ||
              q['auto_accept']?.toLowerCase() == 'true',
        );
      },
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
    GoRoute(path: '/homecare', builder: (c, s) => const HomeCareLandingScreen()),
    GoRoute(path: '/homecare/lab-tests', builder: (c, s) => const LabTestsScreen()),
    GoRoute(path: '/homecare/book-test', builder: (c, s) => BookLabTestScreen(test: s.extra as Map<String, dynamic>)),
    GoRoute(path: '/homecare/treatments', builder: (c, s) => const HomeTreatmentScreen()),
    GoRoute(path: '/patient/medication-reminders', builder: (c, s) => const MedicationRemindersScreen()),
    GoRoute(
      path: '/provider/medical-record/new',
      builder: (c, s) {
        final extra = s.extra as Map<String, dynamic>? ?? {};
        // Also accept aiDraftRecordId via the URI query so the FCM deep-link
        // (`/provider/medical-record/new?aiDraftRecordId=<uuid>`) opens the
        // form pre-filled with the draft.
        final draftFromQuery = s.uri.queryParameters['aiDraftRecordId'];
        return MedicalRecordFormPage(
          consultationId: extra['consultationId']?.toString(),
          patientId: extra['patientId']?.toString(),
          aiDraftRecordId: extra['aiDraftRecordId']?.toString() ?? draftFromQuery,
        );
      },
    ),
    GoRoute(
      path: '/provider/refer',
      builder: (c, s) {
        final extra = s.extra as Map<String, dynamic>? ?? {};
        return ReferralFormPage(
          patientId: extra['patientId']?.toString() ?? '',
          medicalRecordId: extra['medicalRecordId']?.toString(),
        );
      },
    ),
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
        peerId: s.uri.queryParameters['peerId'],
      ),
    ),
    GoRoute(
      path: '/patient/appointments',
      builder: (c, s) => const _PatientAppointmentsPlaceholder(),
    ),
    GoRoute(
      path: '/provider/appointments',
      builder: (c, s) => const ProviderAppointmentsScreen(),
    ),
    GoRoute(
      path: '/provider/lab-tests',
      builder: (c, s) => const LabTechWorkflowScreen(),
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
  String _filter = ‘all’;

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

  List<Map<String, dynamic>> get _filtered {
    if (_filter == ‘all’) return _items;
    if (_filter == ‘consults’) return _items.where((a) {
      final t = a[‘appointment_type’]?.toString() ?? ‘’;
      return t == ‘virtual’ || t == ‘in-person’;
    }).toList();
    if (_filter == ‘lab’) return _items.where((a) => a[‘appointment_type’]?.toString() == ‘lab_test’).toList();
    if (_filter == ‘care’) return _items.where((a) => a[‘appointment_type’]?.toString() == ‘home_treatment’).toList();
    return _items;
  }

  Color _statusColor(String s) {
    switch (s) {
      case ‘confirmed’: return const Color(0xFF0EA5E9);
      case ‘completed’: return const Color(0xFF10B981);
      case ‘cancelled’: return const Color(0xFFEF4444);
      case ‘no_show’: return const Color(0xFF64748B);
      default: return const Color(0xFFF97316);
    }
  }

  Color _labStatusColor(String? s) {
    switch (s) {
      case ‘accepted’: return const Color(0xFF0EA5E9);
      case ‘ongoing’: return const Color(0xFFF97316);
      case ‘results_ready’: return const Color(0xFF10B981);
      default: return const Color(0xFF94A3B8);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case ‘lab_test’: return Icons.biotech_rounded;
      case ‘home_treatment’: return Icons.healing_rounded;
      case ‘virtual’: return Icons.video_call_rounded;
      default: return Icons.local_hospital_rounded;
    }
  }

  String _fmt(String? raw) {
    if (raw == null) return ‘’;
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return ‘’;
    const m = [‘’, ‘Jan’, ‘Feb’, ‘Mar’, ‘Apr’, ‘May’, ‘Jun’, ‘Jul’, ‘Aug’, ‘Sep’, ‘Oct’, ‘Nov’, ‘Dec’];
    final hh = dt.hour.toString().padLeft(2, ‘0’);
    final mm = dt.minute.toString().padLeft(2, ‘0’);
    return ‘${dt.day} ${m[dt.month]} · $hh:$mm’;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(‘My Bookings’, style: TextStyle(fontFamily: ‘Inter’, fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0A1628))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0A1628), size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Filter tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: ‘All’, value: ‘all’, selected: _filter, onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: ‘Consults’, value: ‘consults’, selected: _filter, onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: ‘Lab Tests’, value: ‘lab’, selected: _filter, onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: ‘Home Care’, value: ‘care’, selected: _filter, onTap: (v) => setState(() => _filter = v)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
                : filtered.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.calendar_today_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 14),
                        Text(‘Nothing here yet’, style: TextStyle(color: Colors.grey.shade400, fontSize: 15, fontFamily: ‘Inter’)),
                      ]))
                    : RefreshIndicator(
                        color: const Color(0xFF0EA5E9),
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final a = filtered[i];
                            final id = a[‘appointment_id’]?.toString() ?? ‘’;
                            final status = a[‘status’]?.toString() ?? ‘pending’;
                            final type = a[‘appointment_type’]?.toString() ?? ‘virtual’;
                            final labStatus = a[‘lab_test_status’]?.toString();
                            final hasLabResults = (a[‘lab_results’]?.toString() ?? ‘’).isNotEmpty;
                            final serviceName = a[‘service_name’]?.toString() ?? ‘’;

                            String providerName = ‘Provider’;
                            final provider = a[‘provider’];
                            if (provider is Map) {
                              providerName = provider[‘full_name’]?.toString()
                                  ?? provider[‘user’]?[‘full_name’]?.toString()
                                  ?? ‘Provider’;
                            }

                            final sc = _statusColor(status);
                            final isLabTest = type == ‘lab_test’;

                            return GestureDetector(
                              onTap: id.isEmpty ? null : () => context.push(‘/appointments/$id’),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            color: sc.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(_typeIcon(type), color: sc, size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isLabTest && serviceName.isNotEmpty ? serviceName : providerName,
                                              style: const TextStyle(fontFamily: ‘Inter’, fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A1628)),
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isLabTest ? ‘Lab Test · $providerName’ : type == ‘home_treatment’ ? ‘Home Care · $providerName’ : type == ‘virtual’ ? ‘Video Consult’ : ‘In-Person’,
                                              style: TextStyle(fontFamily: ‘Inter’, fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        )),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: sc.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(7),
                                              ),
                                              child: Text(
                                                status[0].toUpperCase() + status.substring(1),
                                                style: TextStyle(fontFamily: ‘Inter’, fontSize: 10, fontWeight: FontWeight.w800, color: sc),
                                              ),
                                            ),
                                            if (isLabTest && labStatus != null) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _labStatusColor(labStatus).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                                child: Text(
                                                  _labStatusDisplay(labStatus),
                                                  style: TextStyle(fontFamily: ‘Inter’, fontSize: 10, fontWeight: FontWeight.w700, color: _labStatusColor(labStatus)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Text(_fmt(a[‘scheduled_at’]?.toString()), style: TextStyle(fontFamily: ‘Inter’, fontSize: 11.5, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                    if (hasLabResults) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFBBF7D0)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                            const SizedBox(width: 6),
                                            const Expanded(
                                              child: Text(‘Lab results available — tap to view’, style: TextStyle(fontFamily: ‘Inter’, fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _labStatusDisplay(String? s) {
    switch (s) {
      case ‘accepted’: return ‘Accepted’;
      case ‘ongoing’: return ‘In Progress’;
      case ‘results_ready’: return ‘Results Ready’;
      default: return ‘Pending’;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A1628) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0A1628) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: TextStyle(fontFamily: ‘Inter’, fontSize: 12.5, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }
}

