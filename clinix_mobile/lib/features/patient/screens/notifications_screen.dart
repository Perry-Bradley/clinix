import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../shared/widgets/swipe_to_delete.dart';

String _formatNotifTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && dt.day == now.day) return DateFormat('HH:mm').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE HH:mm').format(dt);
    if (dt.year == now.year) return DateFormat('MMM d').format(dt);
    return DateFormat('MMM d, y').format(dt);
  } catch (_) {
    return '';
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final token = await AuthService.getAccessToken();
      final response = await Dio().get(
        '${ApiConstants.baseUrl}notifications/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      List items = [];
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('results')) {
        items = data['results'];
      }
      if (mounted) {
        setState(() {
          _notifications = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      final token = await AuthService.getAccessToken();
      await Dio().patch(
        '${ApiConstants.baseUrl}notifications/read-all/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _loadNotifications();
    } catch (_) {}
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment': return Icons.calendar_today_rounded;
      case 'consultation': return Icons.video_call_rounded;
      case 'payment': return Icons.payment_rounded;
      case 'verification': return Icons.verified_rounded;
      case 'reminder': return Icons.alarm_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'appointment': return AppColors.sky500;
      case 'consultation': return AppColors.accentCyan;
      case 'payment': return AppColors.accentGreen;
      case 'verification': return AppColors.accentOrange;
      case 'reminder': return const Color(0xFFEF4444);
      default: return AppColors.grey500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Notifications', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read', style: AppTextStyles.caption.copyWith(color: AppColors.sky500, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_rounded, size: 56, color: AppColors.grey200),
                      const SizedBox(height: 16),
                      Text('No notifications yet', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey400)),
                      const SizedBox(height: 4),
                      Text('You\'ll see updates here', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.sky500,
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final type = n['type']?.toString() ?? 'system';
                      final isRead = n['is_read'] == true;
                      final id = n['notification_id']?.toString() ?? n['id']?.toString() ?? '$index';
                      return SwipeToDeleteCard(
                        dismissibleKey: 'notif-$id',
                        deletedSnack: 'Notification removed',
                        onDelete: () async {
                          try {
                            final token = await AuthService.getAccessToken();
                            await Dio().delete(
                              '${ApiConstants.baseUrl}notifications/$id/',
                              options: Options(headers: {'Authorization': 'Bearer $token'}),
                            );
                          } catch (_) {
                            // Even if the server call fails, hide locally so the
                            // user gets immediate feedback. A pull-to-refresh
                            // brings it back if the delete didn't actually go.
                          }
                          if (mounted) setState(() => _notifications.removeAt(index));
                          return true;
                        },
                        child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : AppColors.sky100.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isRead ? AppColors.grey200 : AppColors.sky200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: _colorForType(type).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_iconForType(type), color: _colorForType(type), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n['title']?.toString() ?? 'Notification', style: AppTextStyles.bodyLarge.copyWith(fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(n['body']?.toString() ?? '', style: AppTextStyles.caption.copyWith(color: AppColors.grey500), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(_formatNotifTime(n['sent_at']?.toString()), style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.sky500, shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                      );
                    },
                  ),
                ),
    );
  }
}
