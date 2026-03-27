import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/patient_bottom_nav.dart';
import '../../../appointments/presentation/pages/appointment_detail_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  int _selectedTab = 0;

  final List<Widget> _pages = const [
    _PatientDashboard(),
    _PatientDoctorsTab(),
    _PatientAppointmentsTab(),
    _PatientProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: IndexedStack(index: _selectedTab, children: _pages),
      bottomNavigationBar: PatientBottomNav(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
      ),
    );
  }
}

class _PatientDashboard extends StatelessWidget {
  const _PatientDashboard();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good Morning 👋', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.sky200)),
                          SizedBox(height: 4),
                          Text('John Doe', style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.white)),
                        ],
                      ),
                    ),
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Stack(
                        children: [
                          const Center(child: Icon(Icons.notifications_outlined, color: AppColors.white, size: 24)),
                          Positioned(top: 8, right: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accentOrange, shape: BoxShape.circle))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.sky200, size: 20),
                      const SizedBox(width: 10),
                      Text('Search doctors, specialists...', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Quick Actions
              Text('Quick Actions', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _QuickAction(icon: Icons.medical_services_outlined, label: 'Find\nDoctor', color: AppColors.sky500),
                  _QuickAction(icon: Icons.psychology_outlined, label: 'AI\nChecker', color: AppColors.accentCyan),
                  _QuickAction(icon: Icons.calendar_today_outlined, label: 'Book\nAppt', color: AppColors.darkBlue500),
                  _QuickAction(icon: Icons.receipt_long_outlined, label: 'My\nRecords', color: AppColors.accentGreen),
                ],
              ),
              const SizedBox(height: 28),
              // Health Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.darkBlue700, AppColors.sky600]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppColors.sky600.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Health Score', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                          const SizedBox(height: 8),
                          const Text('Excellent', style: TextStyle(fontFamily: 'Inter', fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.white)),
                          const SizedBox(height: 4),
                          Text('Last checkup: 2 weeks ago', style: AppTextStyles.caption.copyWith(color: AppColors.sky300)),
                        ],
                      ),
                    ),
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Center(child: Text('92%', style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.white))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Upcoming Appointment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Upcoming', style: AppTextStyles.headlineMedium),
                  TextButton(onPressed: () {}, child: Text('See all', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500))),
                ],
              ),
              const SizedBox(height: 12),
              _AppointmentCard(),
              const SizedBox(height: 28),
              // Top Doctors
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Top Doctors', style: AppTextStyles.headlineMedium),
                  TextButton(onPressed: () {}, child: Text('See all', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500))),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (ctx, i) => _DoctorCard(index: i),
                ),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _QuickAction({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.grey700, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [BoxShadow(color: AppColors.darkBlue900.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.sky500, AppColors.sky600]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.heart_broken_outlined, color: AppColors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. Marie Nkomo', style: AppTextStyles.headlineSmall.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('Cardiologist', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    Text('Tomorrow, 10:00 AM', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.sky100, borderRadius: BorderRadius.circular(8)),
            child: Text('Video', style: AppTextStyles.caption.copyWith(color: AppColors.sky600, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

final List<Map<String, String>> _mockDoctors = [
  {'name': 'Dr. Jean Paul', 'spec': 'Neurologist', 'rating': '4.9'},
  {'name': 'Dr. Fatou Bah', 'spec': 'Pediatrician', 'rating': '4.8'},
  {'name': 'Dr. Marc Essoh', 'spec': 'Cardiologist', 'rating': '4.7'},
  {'name': 'Dr. Amina Ali', 'spec': 'Dermatologist', 'rating': '4.9'},
];

class _DoctorCard extends StatelessWidget {
  final int index;
  const _DoctorCard({required this.index});

  static const List<List<Color>> _gradients = [
    [AppColors.darkBlue700, AppColors.sky500],
    [Color(0xFF0E4973), AppColors.accentCyan],
    [AppColors.darkBlue600, Color(0xFF0EA5E9)],
    [Color(0xFF163563), AppColors.sky400],
  ];

  @override
  Widget build(BuildContext context) {
    final doc = _mockDoctors[index];
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey200),
          boxShadow: [BoxShadow(color: AppColors.darkBlue900.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradients[index % _gradients.length]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_outline_rounded, color: AppColors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(doc['name']!, style: AppTextStyles.headlineSmall.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(doc['spec']!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontSize: 11)),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                const SizedBox(width: 3),
                Text(doc['rating']!, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.grey700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientDoctorsTab extends StatelessWidget {
  const _PatientDoctorsTab();

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
                          Text('Dr. Jean Paul', style: AppTextStyles.headlineSmall.copyWith(fontSize: 15)),
                          Text('Neurology', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500)),
                          const SizedBox(height: 6),
                          Text('Apr 12, 2026 • 09:30 AM', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
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

class _PatientProfileTab extends StatelessWidget {
  const _PatientProfileTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2.5),
                  ),
                  child: const Icon(Icons.person_rounded, color: AppColors.white, size: 46),
                ),
                const SizedBox(height: 14),
                Text('John Doe', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white)),
                const SizedBox(height: 4),
                Text('+237 677 000 000', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ProfileMenuItem(icon: Icons.medical_information_outlined, label: 'Medical Records', onTap: () {}),
              _ProfileMenuItem(icon: Icons.receipt_long_outlined, label: 'Prescriptions', onTap: () {}),
              _ProfileMenuItem(icon: Icons.payment_outlined, label: 'Payment History', onTap: () {}),
              _ProfileMenuItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
              _ProfileMenuItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () {}),
              _ProfileMenuItem(icon: Icons.logout_rounded, label: 'Log Out', color: AppColors.error, onTap: () => context.go('/login')),
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
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(label, style: AppTextStyles.headlineSmall.copyWith(fontSize: 14, color: c)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 20),
      ),
    );
  }
}
