import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/direct_chat_service.dart';
import '../../../core/services/auth_service.dart';
import '../../appointments/screens/video_consultation_screen.dart';

/// WhatsApp-style 1:1 chat screen backed by the new DirectChat backend.
class DirectChatScreen extends StatefulWidget {
  final String conversationId;
  final String? peerName;
  final String? peerPhoto;

  const DirectChatScreen({
    super.key,
    required this.conversationId,
    this.peerName,
    this.peerPhoto,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final DirectChatService _service = DirectChatService();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  String? _myUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final token = await AuthService.getAccessToken();
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      _myUserId = await AuthService.getCurrentUserId();
    } catch (_) {
      _myUserId = null;
    }

    try {
      final history = await DirectChatService.fetchMessages(widget.conversationId);
      debugPrint('[DirectChat] Loaded ${history.length} history messages for ${widget.conversationId}');
      if (mounted) {
        setState(() {
          _messages.addAll(history);
          _isLoading = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('[DirectChat] fetchMessages failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }

    _service.connect(widget.conversationId, token);
    _sub = _service.messages.listen((data) {
      if (!mounted) return;
      final id = data['message_id']?.toString();
      final content = data['content']?.toString() ?? '';

      // If this is an echo of a message I sent optimistically, replace the temp entry
      final idx = _messages.indexWhere((m) {
        final mid = (m['message_id'] ?? '').toString();
        return mid.startsWith('local_') && m['sender_name'] == '__me__' && m['content'] == content;
      });
      if (idx >= 0) {
        setState(() => _messages[idx] = {...data, 'sender_name': '__me__'});
        return;
      }

      // Regular deduplication by message_id
      if (id != null && _messages.any((m) => m['message_id']?.toString() == id)) return;

      setState(() => _messages.add(data));
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    });
  }

  void _openCall({required bool audioOnly}) {
    // Use conversation_id as the Agora channel — both participants will join the same channel.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoConsultationScreen(
          consultationId: widget.conversationId,
          doctorName: widget.peerName,
          audioOnly: audioOnly,
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    // Optimistic UI: show the message immediately
    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messages.add({
        'message_id': tempId,
        'content': text,
        'message_type': 'text',
        'sender_name': '__me__',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    // Send via WebSocket — the consumer persists and broadcasts back to both parties
    _service.send(text);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image == null) return;
    await _uploadToFirebaseAndSend(File(image.path), 'image');
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (image == null) return;
    await _uploadToFirebaseAndSend(File(image.path), 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.single.path == null) return;
    await _uploadToFirebaseAndSend(File(result.files.single.path!), 'file');
  }

  Future<void> _uploadToFirebaseAndSend(File file, String type) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading...'), duration: Duration(seconds: 2)),
        );
      }
      final name = file.path.split(Platform.pathSeparator).last;
      final ref = FirebaseStorage.instance.ref('dchat/${widget.conversationId}/${DateTime.now().millisecondsSinceEpoch}_$name');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      // Send via HTTP so it persists reliably with file metadata
      await DirectChatService.sendViaHttp(
        widget.conversationId,
        content: type == 'image' ? '' : name,
        messageType: type,
        fileUrl: url,
        fileName: name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.sky100,
                shape: BoxShape.circle,
                image: (widget.peerPhoto != null && widget.peerPhoto!.isNotEmpty)
                    ? DecorationImage(image: NetworkImage(widget.peerPhoto!), fit: BoxFit.cover)
                    : null,
              ),
              child: (widget.peerPhoto == null || widget.peerPhoto!.isEmpty)
                  ? const Icon(Icons.person_rounded, color: AppColors.sky500, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerName ?? 'Chat',
                style: AppTextStyles.headlineSmall.copyWith(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openCall(audioOnly: false),
            iconSize: 30,
            icon: const Icon(Icons.videocam_rounded, color: AppColors.darkBlue900),
            tooltip: 'Video call',
          ),
          IconButton(
            onPressed: () => _openCall(audioOnly: true),
            iconSize: 28,
            icon: const Icon(Icons.phone_rounded, color: AppColors.darkBlue900),
            tooltip: 'Voice call',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.grey200),
                            const SizedBox(height: 14),
                            Text('Say hi to start the conversation',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final senderId = m['sender_id']?.toString();
                          final isMe = (_myUserId != null && senderId == _myUserId) ||
                              m['sender_name'] == '__me__';
                          return _Bubble(
                            content: (m['content'] ?? '').toString(),
                            type: (m['message_type'] ?? 'text').toString(),
                            fileUrl: m['file_url']?.toString(),
                            fileName: m['file_name']?.toString(),
                            isMe: isMe,
                            time: _formatTime(m['created_at']?.toString()),
                            senderName: m['sender_name']?.toString() ?? '',
                          );
                        },
                      ),
          ),
          _composer(),
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _composer() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: AppColors.grey50,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _showAttachSheet,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.add_rounded, color: AppColors.grey500, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black12,
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                cursorColor: AppColors.sky500,
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.darkBlue900, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.sky500,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _send,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(100))),
            const SizedBox(height: 20),
            Text('Attach', style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(icon: Icons.photo_library_rounded, label: 'Gallery', color: AppColors.sky500, onTap: () { Navigator.pop(ctx); _pickImage(); }),
                _AttachOption(icon: Icons.camera_alt_rounded, label: 'Camera', color: AppColors.accentCyan, onTap: () { Navigator.pop(ctx); _pickCamera(); }),
                _AttachOption(icon: Icons.description_rounded, label: 'File', color: AppColors.accentOrange, onTap: () { Navigator.pop(ctx); _pickFile(); }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String content;
  final String type;
  final String? fileUrl;
  final String? fileName;
  final bool isMe;
  final String time;
  final String senderName;
  const _Bubble({
    required this.content,
    required this.type,
    required this.isMe,
    required this.time,
    required this.senderName,
    this.fileUrl,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.sky500 : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: Border.all(color: isMe ? Colors.transparent : AppColors.grey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type == 'image' && fileUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(fileUrl!, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                      ),
                    if (type == 'file' && fileUrl != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.insert_drive_file_outlined, color: isMe ? Colors.white : AppColors.grey500, size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(fileName ?? 'Document', style: TextStyle(color: isMe ? Colors.white : AppColors.darkBlue900, fontSize: 13))),
                      ]),
                    if (content.isNotEmpty) ...[
                      if (type == 'image' && fileUrl != null) const SizedBox(height: 8),
                      Text(content, style: TextStyle(color: isMe ? Colors.white : AppColors.darkBlue900, fontSize: 15, height: 1.35)),
                    ],
                  ],
                ),
              ),
              if (time.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                  child: Text(time, style: TextStyle(fontSize: 11, color: AppColors.grey400)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
