import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../shared/widgets/custom_sidebar_drawer.dart';
import '../../../shared/widgets/bubble_bottom_bar.dart';

class _ProviderApi {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static Future<Options> _authOptions() async {
    final token = await AuthService.getAccessToken();
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
    await _dio.post(
      '${ApiConstants.providers}credentials/',
      data: formData,
      options: (await _authOptions()).copyWith(contentType: 'multipart/form-data'),
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

  @override
  void initState() {
    super.initState();
    _loadProviderName();
  }

  Future<void> _loadProviderName() async {
    final name = await AuthService.getUserName();
    if (!mounted) return;
    setState(() {
      _providerName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Doctor';
    });
  }

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
                          Text(_providerName, style: AppTextStyles.displayLarge.copyWith(fontSize: 22)),
                          const SizedBox(height: 2),
                          Text('Healthcare Provider', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                        ],
                      ),
                    ),
                    _AvailabilityToggle(),
                  ],
                ),
                const SizedBox(height: 24),
                // Stats Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _StatChip(label: 'Today', value: '8', icon: Icons.today_rounded),
                      const SizedBox(width: 12),
                      _StatChip(label: 'Pending', value: '3', icon: Icons.pending_actions_rounded),
                      const SizedBox(width: 12),
                      _StatChip(label: 'Rating', value: '4.9', icon: Icons.star_rounded),
                    ],
                  ),
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _ProviderQuickCard(icon: Icons.video_call_rounded, label: 'Start\nConsult', color: AppColors.sky500),
                    const SizedBox(width: 12),
                    _ProviderQuickCard(icon: Icons.description_outlined, label: 'Write\nPrescription', color: AppColors.accentCyan),
                    const SizedBox(width: 12),
                    _ProviderQuickCard(icon: Icons.bar_chart_rounded, label: 'View\nAnalytics', color: AppColors.darkBlue500),
                  ],
                ),
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
    return SizedBox(
      width: 112,
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
    {'name': 'John Doe', 'time': '09:00 AM', 'type': 'Video', 'status': 'Confirmed'},
    {'name': 'Alice Ngwa', 'time': '10:30 AM', 'type': 'In-Person', 'status': 'Pending'},
    {'name': 'Paul Biya', 'time': '02:00 PM', 'type': 'Video', 'status': 'Completed'},
  ];

  void _openConsultationFlow(BuildContext context, Map<String, String> p) {
    // Real chat lives at /chat/:consultationId — demo cards link to inbox.
    if (p['type'] == 'Video') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a patient thread below, then start video from the live consultation when Agora is configured.'),
        ),
      );
    }
    context.push('/provider/messages');
  }

  @override
  Widget build(BuildContext context) {
    final p = _patients[index];
    final isPending = p['status'] == 'Pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [BoxShadow(color: AppColors.darkBlue900.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.darkBlue700, AppColors.sky500]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name']!, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text("${p['type']} • ${p['time']}", style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPending ? AppColors.accentOrange.withOpacity(0.1) : AppColors.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(p['status']!, style: AppTextStyles.caption.copyWith(color: isPending ? AppColors.accentOrange : AppColors.accentGreen, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.grey200),
                  ),
                  child: Text("View Charts", style: AppTextStyles.labelLarge.copyWith(color: AppColors.grey700, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _openConsultationFlow(context, p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sky500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(p['type'] == 'Video' ? "Start Call" : "Open Chat", style: AppTextStyles.labelLarge.copyWith(fontSize: 12)),
                ),
              ),
            ],
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
    return SizedBox(
      width: 104,
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
      final credentials = await _ProviderApi.fetchCredentials();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _credentials = credentials;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load provider profile.';
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

    final user = (_profile?['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final providerName = user['full_name']?.toString() ?? 'Provider';
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
                Stack(
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.sky600, size: 50),
                    ),
                    Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle), child: const Icon(Icons.check, color: AppColors.white, size: 14))),
                  ],
                ),
                const SizedBox(height: 16),
                Text(providerName, style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white)),
                Text('${verificationStatus[0].toUpperCase()}${verificationStatus.substring(1)} • $specialty', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: verificationStatus == 'approved' ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: verificationStatus == 'approved' ? const Color(0xFFBBF7D0) : const Color(0xFFFFEDD5)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          verificationStatus == 'approved' ? Icons.verified_rounded : Icons.warning_amber_rounded,
                          color: verificationStatus == 'approved' ? const Color(0xFF16A34A) : const Color(0xFFF97316),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          verificationStatus == 'approved' ? 'Profile Verified' : 'Verify Profile',
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: verificationStatus == 'approved' ? const Color(0xFF166534) : const Color(0xFFC2410C),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      verificationStatus == 'approved'
                          ? 'Your KYC has been approved by admin and your provider profile can be listed in the system.'
                          : 'Submit National ID front, National ID back, and your medical license for admin KYC approval.',
                      style: AppTextStyles.caption.copyWith(color: verificationStatus == 'approved' ? const Color(0xFF166534) : const Color(0xFF9A3412)),
                    ),
                    const SizedBox(height: 14),
                    if (verificationStatus != 'approved')
                      SizedBox(width: double.infinity, child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _showVerifyProfileModal(context, onUploaded: _loadProfile), 
                        child: const Text("Verify Profile", style: TextStyle(fontWeight: FontWeight.bold)),
                      )),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _ProfileMenuItem(icon: Icons.verified_user_outlined, label: 'Verify Profile', onTap: () => _showVerifyProfileModal(context, onUploaded: _loadProfile)),
              _ProfileMenuItem(icon: Icons.edit_note_rounded, label: 'Optimization & Bio', onTap: () => _showEditBioModal(context, _profile!, onSaved: _loadProfile)),
              _ProfileMenuItem(icon: Icons.notifications_none_rounded, label: 'Notification Settings', onTap: () {}),
              _ProfileMenuItem(icon: Icons.security_outlined, label: 'Account Integrity', onTap: () {}),
              _ProfileMenuItem(icon: Icons.logout_rounded, label: 'Log Out', color: AppColors.error, onTap: () => context.go('/login')),
              const SizedBox(height: 12),
              if (_credentials.isNotEmpty)
                ..._credentials.map((cred) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: AppColors.sky500),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_credentialLabel((cred['document_type'] ?? 'document').toString()), style: AppTextStyles.bodyMedium)),
                      Text((cred['is_verified'] == true) ? 'Verified' : 'Pending', style: AppTextStyles.caption.copyWith(color: (cred['is_verified'] == true) ? AppColors.accentGreen : AppColors.accentOrange)),
                    ],
                  ),
                )),
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
  String _payoutMethod = 'MoMo';
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
          const SizedBox(height: 30),
          Text('Request Payout 💸', style: AppTextStyles.headlineLarge.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text('Withdraw your earnings securely to your account.', style: AppTextStyles.caption),
          const SizedBox(height: 25),
          
          Text('Select Payout Method', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              _MethodChip(label: 'Mobile Money', selected: _payoutMethod == 'MoMo', onTap: () => setState(() => _payoutMethod = 'MoMo')),
              const SizedBox(width: 12),
              _MethodChip(label: 'Bank Account', selected: _payoutMethod == 'Bank', onTap: () => setState(() => _payoutMethod = 'Bank')),
            ],
          ),
          const SizedBox(height: 24),
          
          Text(_payoutMethod == 'MoMo' ? 'Phone Number' : 'Account Number', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Amount in XAF',
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: _payoutMethod == 'MoMo' ? 'e.g. 677XXXXXX' : 'Enter account number',
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 30),
          
          ElevatedButton(
            onPressed: _submitting ? null : () async {
              setState(() => _submitting = true);
              try {
                await _ProviderApi.requestWithdrawal(
                  amount: _amountController.text.trim(),
                  method: _payoutMethod == 'MoMo' ? 'mtn_momo' : 'bank',
                  details: _numberController.text.trim(),
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
              backgroundColor: AppColors.sky600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirm Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(
      text: (widget.profile['bio'] ?? '').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(25, 25, 25, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 30),
          Text('Profile Optimization 🚀', style: AppTextStyles.headlineLarge.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text('Update the professional information patients see on your profile.', style: AppTextStyles.caption),
          const SizedBox(height: 25),

          Text('Biography', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _bioController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter your background...',
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : () async {
              setState(() => _saving = true);
              try {
                await _ProviderApi.updateProfile({'bio': _bioController.text.trim()});
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
    );
  }
}
