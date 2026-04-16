import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/auth_service.dart';
import '../../appointments/screens/video_consultation_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? doctorName;
  final String consultationId;

  const ChatScreen({super.key, this.doctorName, required this.consultationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ChatService _chatService = ChatService();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scroll = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _sub;

  String? _myUserName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final token = await AuthService.getAccessToken();
    _myUserName = await AuthService.getUserName() ?? 'Me';

    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final history = await _chatService.fetchMessages(widget.consultationId, token);
      if (mounted) {
        setState(() {
          for (final m in history) {
            _messages.add({
              'msg': m['content'],
              'isMe': m['sender_name'] == _myUserName,
              'time': _formatTime(m['created_at']),
              'type': m['message_type'],
              'file_url': m['file_url'],
              'file_name': m['file_name'],
            });
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }

    _chatService.connect(widget.consultationId, token);
    _sub = _chatService.messages.listen((data) {
      if (!mounted) return;
      final incoming = data['message']?.toString() ?? '';
      final isMine = data['sender_name'] == _myUserName;

      // Skip echo of my own text messages (already added optimistically)
      if (isMine && (data['message_type']?.toString() ?? 'text') == 'text') {
        final existsLocally = _messages.any((m) =>
          m['isMe'] == true && m['msg'] == incoming && m['type'] == 'text');
        if (existsLocally) return;
      }

      setState(() {
        _messages.add({
          'msg': incoming,
          'isMe': isMine,
          'time': 'Now',
          'type': data['message_type'],
          'file_url': data['file_url'],
          'file_name': data['file_name'],
        });
      });
      _scrollToBottom();
    });

    if (mounted) setState(() => _isLoading = false);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // Optimistic UI — show message immediately so the sender sees it
    setState(() {
      _messages.add({
        'msg': text,
        'isMe': true,
        'time': 'Now',
        'type': 'text',
        'file_url': null,
        'file_name': null,
      });
    });

    _chatService.sendMessage(text);
    _msgCtrl.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) _uploadAndSend(image.path, 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      _uploadAndSend(result.files.single.path!, 'file');
    }
  }

  Future<void> _uploadAndSend(String path, String type) async {
    final token = await AuthService.getAccessToken();
    if (token == null) return;
    try {
      final response = await _chatService.uploadMedia(widget.consultationId, token, path, type);
      _chatService.sendMessage(
        response['content']?.toString() ?? '',
        type: response['message_type']?.toString() ?? type,
        fileUrl: response['file_url']?.toString(),
        fileName: response['file_name']?.toString(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _openCall({required bool audioOnly}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoConsultationScreen(
          consultationId: widget.consultationId,
          doctorName: widget.doctorName,
          audioOnly: audioOnly,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _chatService.dispose();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.darkBlue900,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        title: Text(widget.doctorName ?? 'Consultation', style: AppTextStyles.headlineSmall.copyWith(fontSize: 17)),
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
            tooltip: 'Audio call',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _GptBubble(
                      msg: _messages[i]['msg'] as String,
                      isMe: _messages[i]['isMe'] as bool,
                      time: _messages[i]['time'] as String,
                      type: _messages[i]['type'] as String? ?? 'text',
                      fileUrl: _messages[i]['file_url'] as String?,
                      fileName: _messages[i]['file_name'] as String?,
                    ),
                  ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attach button
          Material(
            color: AppColors.grey50,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openAttachSheet,
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
                controller: _msgCtrl,
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

  void _openAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                _AttachOption(icon: Icons.photo_library_rounded, label: 'Gallery', color: AppColors.sky500, onTap: () { Navigator.pop(context); _pickImage(); }),
                _AttachOption(icon: Icons.camera_alt_rounded, label: 'Camera', color: AppColors.accentCyan, onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (image != null) _uploadAndSend(image.path, 'image');
                }),
                _AttachOption(icon: Icons.description_rounded, label: 'File', color: AppColors.accentOrange, onTap: () { Navigator.pop(context); _pickFile(); }),
              ],
            ),
            const SizedBox(height: 8),
          ],
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
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
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

class _GptBubble extends StatelessWidget {
  final String msg;
  final bool isMe;
  final String time;
  final String type;
  final String? fileUrl;
  final String? fileName;

  const _GptBubble({
    required this.msg,
    required this.isMe,
    required this.time,
    required this.type,
    this.fileUrl,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.86;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                  color: isMe ? const Color(0xFFE3F2FD) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: Border.all(color: isMe ? Colors.transparent : AppColors.grey200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type == 'image' && fileUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          fileUrl!,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              height: 120,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
                    if (type == 'file' && fileUrl != null)
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName ?? 'Document',
                              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (msg.isNotEmpty) ...[
                      if (type == 'image' && fileUrl != null) const SizedBox(height: 8),
                      Text(
                        msg,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.darkBlue900,
                          height: 1.35,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (time.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                  child: Text(
                    time,
                    style: TextStyle(fontSize: 11, color: AppColors.grey400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
