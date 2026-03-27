import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/patient/presentation/pages/patient_home_page.dart';
import '../../features/provider/presentation/pages/provider_home_page.dart';
import '../../features/appointments/presentation/pages/book_appointment_page.dart';
import '../../features/appointments/presentation/pages/appointment_detail_page.dart';

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
            phone: s.uri.queryParameters['phone'] ?? '',
          ),
        ),
      ],
    ),
    GoRoute(path: '/patient/home', builder: (c, s) => const PatientHomePage()),
    GoRoute(path: '/provider/home', builder: (c, s) => const ProviderHomePage()),
    GoRoute(
      path: '/appointments/book',
      builder: (c, s) => BookAppointmentPage(
        providerId: s.uri.queryParameters['providerId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/appointments/:id',
      builder: (c, s) => AppointmentDetailPage(
        appointmentId: s.pathParameters['id'] ?? '',
      ),
    ),
  ],
);
