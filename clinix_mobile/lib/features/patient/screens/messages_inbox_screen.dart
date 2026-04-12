import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/appointment_service.dart';
import '../../../core/theme/app_colors.dart';

/// Lists appointments that have an active [consultation_id] so the user can open in-app chat.
class MessagesInboxScreen extends StatefulWidget {
  final bool isProvider;

  const MessagesInboxScreen({super.key, this.isProvider = false});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await AppointmentService.getMyAppointments();
      final withChat = <Map<String, dynamic>>[];
      for (final a in all) {
        final cid = a['consultation_id']?.toString();
        if (cid != null && cid.isNotEmpty) {
          withChat.add(Map<String, dynamic>.from(a));
        }
      }
      if (mounted) {
        setState(() {
          _rows = withChat;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _peerTitle(Map<String, dynamic> a) {
    if (widget.isProvider) {
      final u = a['patient']?['user'];
      if (u is Map && u['full_name'] != null) {
        return u['full_name'].toString();
      }
      return 'Patient';
    }
    final p = a['provider'];
    if (p is Map && p['full_name'] != null) {
      return p['full_name'].toString();
    }
    return 'Provider';
  }

  String _scheduledLabel(Map<String, dynamic> a) {
    final raw = a['scheduled_at']?.toString();
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, y • HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkBlue900,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  )
                : _rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(32),
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No message threads yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'After you book an appointment and a consultation is started for it, your provider chat will appear here.',
                            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, i) {
                          final a = _rows[i];
                          final cid = a['consultation_id']!.toString();
                          final title = _peerTitle(a);
                          final sub = _scheduledLabel(a);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.sky100,
                              child: Icon(Icons.chat_rounded, color: AppColors.sky600),
                            ),
                            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: sub.isEmpty ? null : Text(sub, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              final q = Uri.encodeComponent(title);
                              context.push('/chat/$cid?doctorName=$q');
                            },
                          );
                        },
                      ),
      ),
    );
  }
}
