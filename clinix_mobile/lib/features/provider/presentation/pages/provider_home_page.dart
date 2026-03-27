import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

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
      body: IndexedStack(index: _selectedTab, children: _pages),
      bottomNavigationBar: _ProviderBottomNav(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
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
    const items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Schedule'},
      {'icon': Icons.account_balance_wallet_outlined, 'label': 'Earnings'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.darkBlue900.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
        border: const Border(top: BorderSide(color: AppColors.grey200)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              final icon = items[i]['icon'] as IconData;
              final label = items[i]['label'] as String;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.sky500.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: isActive ? AppColors.sky500 : AppColors.grey400, size: 24),
                      const SizedBox(height: 3),
                      Text(label, style: AppTextStyles.caption.copyWith(color: isActive ? AppColors.sky500 : AppColors.grey400, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, fontSize: 10)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ProviderDashboard extends StatelessWidget {
  const _ProviderDashboard();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Doctor Portal 🩺', style: AppTextStyles.caption.copyWith(color: AppColors.sky300, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Dr. Marie Nkomo', style: AppTextStyles.displayLarge.copyWith(fontSize: 22)),
                          const SizedBox(height: 2),
                          Text('Cardiologist', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                        ],
                      ),
                    ),
                    _AvailabilityToggle(),
                  ],
                ),
                const SizedBox(height: 24),
                // Stats Row
                Row(
                  children: [
                    _StatChip(label: 'Today', value: '8', icon: Icons.today_rounded),
                    const SizedBox(width: 12),
                    _StatChip(label: 'Pending', value: '3', icon: Icons.pending_actions_rounded),
                    const SizedBox(width: 12),
                    _StatChip(label: 'Rating', value: '4.9', icon: Icons.star_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text("Today's Appointments", style: AppTextStyles.headlineMedium),
              const SizedBox(height: 14),
              ...[0, 1, 2].map((i) => _ProviderApptCard(index: i)),
              const SizedBox(height: 24),
              Text('Quick Actions', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ProviderQuickCard(icon: Icons.video_call_rounded, label: 'Start\nConsult', color: AppColors.sky500),
                  const SizedBox(width: 12),
                  _ProviderQuickCard(icon: Icons.description_outlined, label: 'Write\nPrescription', color: AppColors.accentCyan),
                  const SizedBox(width: 12),
                  _ProviderQuickCard(icon: Icons.bar_chart_rounded, label: 'View\nAnalytics', color: AppColors.darkBlue500),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityToggle extends StatefulWidget {
  @override
  State<_AvailabilityToggle> createState() => __AvailabilityToggleState();
}

class __AvailabilityToggleState extends State<_AvailabilityToggle> {
  bool _isAvailable = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isAvailable = !_isAvailable),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isAvailable ? AppColors.accentGreen.withOpacity(0.2) : Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isAvailable ? AppColors.accentGreen : Colors.redAccent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 8, height: 8,
              decoration: BoxDecoration(color: _isAvailable ? AppColors.accentGreen : Colors.redAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(_isAvailable ? 'Online' : 'Offline', style: AppTextStyles.caption.copyWith(color: _isAvailable ? AppColors.accentGreen : Colors.redAccent, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.sky300, size: 18),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white, fontSize: 20)),
            Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.sky200, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ProviderApptCard extends StatelessWidget {
  final int index;
  const _ProviderApptCard({required this.index});

  static const List<Map<String, String>> _patients = [
    {'name': 'John Doe', 'time': '09:00 AM', 'type': 'Video'},
    {'name': 'Alice Ngwa', 'time': '10:30 AM', 'type': 'In-Person'},
    {'name': 'Paul Biya', 'time': '02:00 PM', 'type': 'Video'},
  ];

  @override
  Widget build(BuildContext context) {
    final p = _patients[index];
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
            width: 46, height: 46,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.darkBlue700, AppColors.sky500]), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.person_rounded, color: AppColors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name']!, style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                const SizedBox(height: 3),
                Text(p['time']!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: p['type'] == 'Video' ? AppColors.sky100 : AppColors.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(p['type']!, style: AppTextStyles.caption.copyWith(color: p['type'] == 'Video' ? AppColors.sky600 : AppColors.accentGreen, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.sky500.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.sky500, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderQuickCard extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _ProviderQuickCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderScheduleTab extends StatelessWidget {
  const _ProviderScheduleTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.darkBlue900,
          pinned: true,
          automaticallyImplyLeading: false,
          title: Text('My Schedule', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white, fontSize: 16)),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Weekly calendar strip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.darkBlue800, AppColors.sky600]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('March 2026', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white)),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.sky200),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['M','T','W','T','F','S','S'].asMap().entries.map((e) {
                        final isToday = e.key == DateTime.now().weekday - 1;
                        return Column(
                          children: [
                            Text(e.value, style: AppTextStyles.caption.copyWith(color: AppColors.sky200)),
                            const SizedBox(height: 6),
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: isToday ? AppColors.white : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text('${27 + e.key}', style: AppTextStyles.headlineSmall.copyWith(color: isToday ? AppColors.sky600 : AppColors.white, fontSize: 13))),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text("Upcoming Sessions", style: AppTextStyles.headlineMedium),
              const SizedBox(height: 14),
              ...[0, 1, 2].map((i) => _ProviderApptCard(index: i)),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ProviderEarningsTab extends StatelessWidget {
  const _ProviderEarningsTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.darkBlue900,
          pinned: true,
          automaticallyImplyLeading: false,
          title: Text('Earnings', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white, fontSize: 16)),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Earnings card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.darkBlue800, AppColors.sky600], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppColors.sky600.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Total Earnings', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('This Month', style: AppTextStyles.caption.copyWith(color: AppColors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('XAF 425,000', style: AppTextStyles.displayLarge.copyWith(fontSize: 32)),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _EarningStat(label: 'Consultations', value: '34'),
                        _EarningStat(label: 'Platform Fee', value: '42,500'),
                        _EarningStat(label: 'Net Payout', value: '382,500'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Recent Payouts', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 14),
              ...List.generate(5, (i) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: AppColors.sky100, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.sky500, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payout', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                        Text('Mar ${15 + i},  2026', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                      ],
                    )),
                    Text('XAF ${(12500 + i * 1200).toString()}', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.accentGreen, fontSize: 14)),
                  ],
                ),
              )),
            ]),
          ),
        ),
      ],
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

class _ProviderProfileTab extends StatelessWidget {
  const _ProviderProfileTab();

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
                Stack(
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.sky500, AppColors.sky300]),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2.5),
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.white, size: 46),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 26, height: 26,
                        decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: AppColors.white, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Dr. Marie Nkomo', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white)),
                const SizedBox(height: 4),
                Text('Cardiologist • Verified', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                    const SizedBox(width: 4),
                    Text('4.9 Rating', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                    const SizedBox(width: 16),
                    const Icon(Icons.people_alt_rounded, color: AppColors.sky300, size: 16),
                    const SizedBox(width: 4),
                    Text('342 Patients', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ProfileMenuItem(icon: Icons.badge_outlined, label: 'My Credentials', onTap: () {}),
              _ProfileMenuItem(icon: Icons.schedule_outlined, label: 'Availability Settings', onTap: () {}),
              _ProfileMenuItem(icon: Icons.payments_outlined, label: 'Payout Settings', onTap: () {}),
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
