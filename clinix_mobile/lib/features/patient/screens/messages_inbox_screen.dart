import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/direct_chat_service.dart';

/// Lists all direct-message conversations for the current user.
class MessagesInboxScreen extends StatefulWidget {
  final bool isProvider;
  const MessagesInboxScreen({super.key, this.isProvider = false});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await DirectChatService.listConversations();
      if (!mounted) return;
      setState(() {
        _conversations = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load conversations';
        _loading = false;
      });
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (now.difference(dt).inDays == 0) return DateFormat('HH:mm').format(dt);
      if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Messages', style: AppTextStyles.headlineSmall.copyWith(fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.darkBlue900,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go(widget.isProvider ? '/provider/home' : '/patient/home'),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.sky500,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: AppTextStyles.bodyMedium))])
                : _conversations.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.grey200),
                        const SizedBox(height: 16),
                        Center(child: Text('No conversations yet', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey400))),
                        const SizedBox(height: 6),
                        Center(child: Text('Tap the chat icon on a doctor to start.', style: AppTextStyles.caption.copyWith(color: AppColors.grey400))),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _conversations.length,
                        separatorBuilder: (_, __) => Divider(color: AppColors.grey100, height: 1, indent: 78),
                        itemBuilder: (ctx, i) {
                          final c = _conversations[i];
                          final convId = c['conversation_id']?.toString() ?? '';
                          final peerName = c['peer_name']?.toString() ?? 'User';
                          final peerPhoto = c['peer_photo']?.toString();
                          final last = c['last_message'];
                          final preview = last is Map
                              ? (last['message_type'] == 'image'
                                  ? '📷 Photo'
                                  : last['message_type'] == 'file'
                                      ? '📎 File'
                                      : (last['content']?.toString() ?? ''))
                              : 'Say hi 👋';
                          final time = _formatTime(c['last_message_at']?.toString());
                          final unread = (c['unread_count'] is int) ? c['unread_count'] as int : 0;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.sky100,
                                shape: BoxShape.circle,
                                image: (peerPhoto != null && peerPhoto.isNotEmpty)
                                    ? DecorationImage(image: NetworkImage(peerPhoto), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: (peerPhoto == null || peerPhoto.isEmpty)
                                  ? const Icon(Icons.person_rounded, color: AppColors.sky500, size: 24)
                                  : null,
                            ),
                            title: Text(peerName, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(preview, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(time, style: AppTextStyles.caption.copyWith(color: unread > 0 ? AppColors.sky500 : AppColors.grey400, fontSize: 11)),
                                const SizedBox(height: 4),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.sky500, borderRadius: BorderRadius.circular(10)),
                                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                            onTap: () {
                              final peerId = c['peer_id']?.toString() ?? '';
                              final query = StringBuffer('name=${Uri.encodeComponent(peerName)}');
                              if (peerPhoto != null && peerPhoto.isNotEmpty) {
                                query.write('&photo=${Uri.encodeComponent(peerPhoto)}');
                              }
                              if (peerId.isNotEmpty) {
                                query.write('&peerId=${Uri.encodeComponent(peerId)}');
                              }
                              context.push('/dchat/$convId?$query');
                            },
                          );
                        },
                      ),
      ),
    );
  }
}
