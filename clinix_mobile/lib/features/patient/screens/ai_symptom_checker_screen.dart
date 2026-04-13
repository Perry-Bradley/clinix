import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/ai_chat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

const Color _kAiBgTop = Color(0xFFF1F5F9);

class AiConsultScreen extends StatefulWidget {
  const AiConsultScreen({super.key});

  @override
  State<AiConsultScreen> createState() => _AiConsultScreenState();
}

class _AiConsultScreenState extends State<AiConsultScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _sessionId;
  bool _isSessionActive = true;
  Map<String, dynamic>? _finalAssessment;

  String? _pendingImageBase64;
  String? _pendingImageMime;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    try {
      final result = await AiChatService.startChat();
      setState(() {
        _sessionId = result['session_id'];
        _messages.add(ChatMessage(
          text: result['message'],
          isUser: false,
        ));
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      final map = body is Map ? Map<String, dynamic>.from(body as Map) : <String, dynamic>{};
      final detail = map['detail']?.toString() ?? map['error']?.toString();
      if (code == 401 || code == 403) {
        _showError(detail ?? 'Sign in as a patient to use Clinix AI.');
      } else if (code == 404) {
        _showError('AI endpoint not found. Update api_constants.dart base URL to your running API (e.g. same Wi‑Fi IP as this phone).');
      } else if (code == 503 || code == 502) {
        _showError(
          detail ??
              'Clinix AI (MedLM) is not available. Set GCP project env vars and credentials on the server, '
              'then restart the API.',
        );
      } else {
        _showError(detail ?? 'Could not start AI session (${code ?? e.message}). Check that the backend is running.');
      }
    } catch (e) {
      _showError('Failed to initialize session: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final hasImage = _pendingImageBase64 != null && (_pendingImageBase64 ?? '').trim().isNotEmpty;
    if ((text.isEmpty && !hasImage) || _sessionId == null || !_isSessionActive) return;

    final imageDataUri = hasImage ? 'data:${_pendingImageMime ?? 'image/jpeg'};base64,${_pendingImageBase64!}' : null;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, imageDataUri: imageDataUri));
      _messageController.clear();
      _pendingImageBase64 = null;
      _pendingImageMime = null;
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final reply = await AiChatService.sendMessage(
        _sessionId!,
        text,
        imageBase64: imageDataUri,
      );
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    } on DioException catch (e) {
      final body = e.response?.data;
      final map = body is Map ? Map<String, dynamic>.from(body as Map) : <String, dynamic>{};
      final detail = map['detail']?.toString() ?? map['error']?.toString();
      _showError(detail ?? e.message ?? 'Could not send message (${e.response?.statusCode}).');
    } catch (e) {
      _showError("Couldn't send message. Please try again.");
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _completeClinicalOnboarding() async {
    if (_sessionId == null) return;
    setState(() => _isLoading = true);
    try {
      final result = await AiChatService.completeChat(_sessionId!);
      setState(() {
        _isSessionActive = false;
        _finalAssessment = result['assessment'];
        _messages.add(ChatMessage(
          text: "I've completed my assessment based on our discussion. Here is your summary:",
          isUser: false,
          isFinal: true,
          assessment: _finalAssessment,
        ));
      });
    } catch (e) {
      _showError("Error generating final assessment.");
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _showError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.redAccent));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.sky500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: AppColors.sky600, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Clinix AI',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.splashSlate900,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Triage assistant · not for emergencies',
              style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 10),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.grey200),
        ),
        actions: [
          if (_isSessionActive && _messages.length > 2)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton(
                onPressed: _completeClinicalOnboarding,
                child: Text(
                  'Summary',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.splashSlate900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.splashSlate900, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kAiBgTop, Colors.white],
            stops: [0.0, 0.35],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const _ThinkingIndicator();
                  }
                  return _messages[index];
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    if (!_isSessionActive) return _buildCompletedArea();

    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _openAttachSheet,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.grey500, size: 28),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_pendingImageBase64 != null && (_pendingImageBase64 ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              base64Decode(_pendingImageBase64!),
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Image attached',
                              style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              _pendingImageBase64 = null;
                              _pendingImageMime = null;
                            }),
                            icon: const Icon(Icons.close_rounded, color: AppColors.grey500, size: 18),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _messageController,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.splashSlate900),
                    cursorColor: AppColors.splashSlate900,
                    decoration: InputDecoration(
                      hintText: 'Describe how you feel…',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.splashSlate900,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sendMessage,
              child: const Padding(
                padding: EdgeInsets.all(12),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _AttachChip(
              icon: Icons.image_rounded,
              label: 'Photo',
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            _AttachChip(
              icon: Icons.photo_camera_rounded,
              label: 'Camera',
              onTap: () {
                Navigator.pop(context);
                _pickCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _pendingImageBase64 = base64Encode(bytes);
      _pendingImageMime = image.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _pendingImageBase64 = base64Encode(bytes);
      _pendingImageMime = image.mimeType ?? 'image/jpeg';
    });
  }

  Widget _buildCompletedArea() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.accentGreen, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Session complete', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.darkBlue900, fontWeight: FontWeight.bold)),
                Text('Review your summary above.', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sky500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Close', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isFinal;
  final Map<String, dynamic>? assessment;
  final String? imageDataUri;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.isFinal = false,
    this.assessment,
    this.imageDataUri,
  });

  @override
  Widget build(BuildContext context) {
    final String? img = imageDataUri;
    final bool hasImage = img != null && img.trim().isNotEmpty;
    final String? b64 = hasImage && img.contains('base64,') ? img.split('base64,')[1] : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) _avatar(Icons.health_and_safety_rounded, AppColors.sky600),
              if (!isUser) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.splashSlate900 : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser ? Colors.transparent : AppColors.grey200,
                    ),
                    boxShadow: [
                      if (!isUser)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (b64 != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: text.trim().isEmpty ? 0 : 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              base64Decode(b64),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      if (text.trim().isNotEmpty)
                        Text(
                          text,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: isUser ? Colors.white : AppColors.splashSlate900,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isFinal && assessment != null) _buildFinalSummary(context),
        ],
      ),
    );
  }

  Widget _avatar(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildFinalSummary(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppColors.sky500),
              const SizedBox(width: 12),
              Text('Medical Insight', style: AppTextStyles.headlineSmall.copyWith(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 20),
          _summaryRow('Triage Priority', assessment!['triage_priority'] ?? 'Standard', Icons.flag_rounded, 
              (assessment!['triage_priority']?.toString().toLowerCase().contains('high') ?? false) ? Colors.red : AppColors.accentGreen),
          _summaryRow('Recommended Care', assessment!['recommended_specialization'] ?? 'General Consultation', Icons.medical_services_rounded, AppColors.sky500),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => context.push('/patient/book-appointment', extra: {'specialty': assessment!['recommended_specialization']}),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.splashSlate900,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Book recommended care', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
                Text(value, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.darkBlue900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.splashSlate900, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.sky500.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.health_and_safety_rounded, color: AppColors.sky600, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Row(
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final value = Curves.easeInOut.transform((_controller.value + delay) % 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: value,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: AppColors.grey400, shape: BoxShape.circle),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
