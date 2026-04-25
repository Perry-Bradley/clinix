import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/ai_chat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// ─── Primary accent used throughout the AI screen ───────────────────────────
const Color _kAccent = Color(0xFF1B4080);      // bright dark blue (matches home icons)
const Color _kAccentLight = Color(0xFFEDF2F7); // soft blue-grey
const Color _kAccentDark = Color(0xFF0F172A);  // text color
const Color _kBg = Colors.white;
const Color _kCardBg = Colors.white;

class AiConsultScreen extends StatefulWidget {
  const AiConsultScreen({super.key});

  @override
  State<AiConsultScreen> createState() => _AiConsultScreenState();
}

class _AiConsultScreenState extends State<AiConsultScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _historySearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _sessionId;
  bool _isSessionActive = true;
  Map<String, dynamic>? _finalAssessment;

  String? _pendingImageBase64;
  String? _pendingImageMime;

  List<Map<String, dynamic>> _sessions = [];
  bool _isLoadingSessions = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  // ─── Session management ─────────────────────────────────────────────────

  Future<void> _loadSessions() async {
    setState(() => _isLoadingSessions = true);
    try {
      _sessions = await AiChatService.getSessions();
    } catch (_) {}
    if (mounted) setState(() => _isLoadingSessions = false);
  }

  Future<void> _startNewChat() async {
    setState(() {
      _messages.clear();
      _sessionId = null;
      _isSessionActive = true;
      _finalAssessment = null;
      _isLoading = true;
    });
    try {
      final result = await AiChatService.startChat();
      setState(() {
        _sessionId = result['session_id'];
        _messages.add(ChatMessage(text: result['message'] ?? 'Hello! How can I help you today?', isUser: false));
      });
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      _showError('Failed to start session: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    _loadSessions();
  }

  Future<void> _openSession(String? sessionId) async {
    if (sessionId == null) return;
    setState(() {
      _messages.clear();
      _isLoading = true;
      _isSessionActive = true;
      _finalAssessment = null;
    });
    try {
      final data = await AiChatService.getChatHistory(sessionId);
      final msgs = (data['messages'] as List?) ?? [];
      setState(() {
        _sessionId = sessionId;
        _isSessionActive = data['is_active'] == true;
        for (final m in msgs) {
          final map = Map<String, dynamic>.from(m as Map);
          _messages.add(ChatMessage(
            text: map['message']?.toString() ?? '',
            isUser: map['role'] == 'user',
          ));
        }
      });
    } catch (e) {
      _showError('Could not load chat.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // ─── Messaging ──────────────────────────────────────────────────────────

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
      final reply = await AiChatService.sendMessage(_sessionId!, text, imageBase64: imageDataUri);
      setState(() => _messages.add(ChatMessage(text: reply, isUser: false)));
    } on DioException catch (e) {
      final body = e.response?.data;
      final map = body is Map ? Map<String, dynamic>.from(body as Map) : <String, dynamic>{};
      _showError(map['detail']?.toString() ?? map['error']?.toString() ?? 'Could not send message.');
    } catch (e) {
      _showError("Couldn't send message. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _completeChat() async {
    if (_sessionId == null) return;
    setState(() => _isLoading = true);
    try {
      final result = await AiChatService.completeChat(_sessionId!);
      setState(() {
        _isSessionActive = false;
        _finalAssessment = result['assessment'];
        _messages.add(ChatMessage(
          text: "I've completed my assessment. Here is your summary:",
          isUser: false,
          isFinal: true,
          assessment: _finalAssessment,
        ));
      });
    } catch (e) {
      _showError("Error generating assessment.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  void _handleDioError(DioException e) {
    final code = e.response?.statusCode;
    final body = e.response?.data;
    final map = body is Map ? Map<String, dynamic>.from(body as Map) : <String, dynamic>{};
    final detail = map['detail']?.toString() ?? map['error']?.toString();
    if (code == 401 || code == 403) {
      _showError(detail ?? 'Sign in as a patient to use Clinix AI.');
    } else if (code == 404) {
      _showError('AI endpoint not found. Check your backend URL.');
    } else if (code == 503 || code == 502) {
      _showError(detail ?? 'AI service unavailable. Check server config.');
    } else {
      _showError(detail ?? 'Could not connect (${code ?? e.message}).');
    }
  }

  void _showError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
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

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // If no session started yet, show the landing page
    final bool showLanding = _sessionId == null && _messages.isEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: _kBg,
      body: showLanding ? _buildLandingPage() : _buildChatPage(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LANDING PAGE — shown before any chat starts
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLandingPage() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.grey500, size: 20),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showHistorySheet,
                  icon: const Icon(Icons.history_rounded, color: _kAccent, size: 20),
                  label: Text('History', style: AppTextStyles.bodyMedium.copyWith(color: _kAccent, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
          // Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _kAccentLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.spa_rounded, color: _kAccent, size: 50),
          ),
          const SizedBox(height: 28),
          Text(
            'Clinix AI',
            style: AppTextStyles.displayLarge.copyWith(color: _kAccentDark, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your intelligent health assistant.\nDescribe symptoms, get guidance, and connect with doctors.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, height: 1.5),
            ),
          ),
          const SizedBox(height: 40),
          // Topic chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _TopicChip(label: 'Symptoms', icon: Icons.thermostat_rounded, onTap: () => _startWithPrompt('I have some symptoms I want to discuss')),
                _TopicChip(label: 'Medication', icon: Icons.medication_rounded, onTap: () => _startWithPrompt('I need advice about medication')),
                _TopicChip(label: 'Mental Health', icon: Icons.self_improvement_rounded, onTap: () => _startWithPrompt('I want to discuss my mental health')),
                _TopicChip(label: 'Nutrition', icon: Icons.restaurant_rounded, onTap: () => _startWithPrompt('I need nutrition and diet advice')),
              ],
            ),
          ),
          const Spacer(flex: 3),
          // Start button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startNewChat,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text('Start New Chat', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
          // History button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _showHistorySheet,
                icon: Icon(Icons.history_rounded, size: 20, color: _kAccent),
                label: Text('View Chat History', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 15, color: _kAccent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kAccent.withOpacity(0.2)),
                  foregroundColor: _kAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startWithPrompt(String prompt) async {
    await _startNewChat();
    if (_sessionId != null) {
      _messageController.text = prompt;
      await _sendMessage();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT PAGE — active conversation
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildChatPage() {
    return Column(
      children: [
        _buildChatAppBar(),
        Expanded(
          child: _messages.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator(color: _kAccent))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) return const _ThinkingIndicator();
                    return _messages[index];
                  },
                ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildChatAppBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(4, MediaQuery.of(context).padding.top + 4, 4, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // Go back to landing
              setState(() {
                _messages.clear();
                _sessionId = null;
                _isSessionActive = true;
                _finalAssessment = null;
              });
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: _kAccentLight, shape: BoxShape.circle),
            child: const Icon(Icons.spa_rounded, color: _kAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clinix AI', style: AppTextStyles.headlineSmall.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  _isSessionActive ? 'Online' : 'Session ended',
                  style: AppTextStyles.caption.copyWith(color: _isSessionActive ? AppColors.accentGreen : AppColors.grey400, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_isSessionActive && _messages.length > 2)
            TextButton(
              onPressed: _completeChat,
              style: TextButton.styleFrom(
                backgroundColor: _kAccentLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text('Summary', style: AppTextStyles.caption.copyWith(color: _kAccent, fontWeight: FontWeight.w800)),
            ),
          IconButton(
            onPressed: _startNewChat,
            icon: const Icon(Icons.edit_note_rounded, color: _kAccent, size: 24),
            tooltip: 'New Chat',
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    if (!_isSessionActive) return _buildCompletedBar();

    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview
          if (_pendingImageBase64 != null && (_pendingImageBase64 ?? '').trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kAccentLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(base64Decode(_pendingImageBase64!), width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Image attached', style: AppTextStyles.caption.copyWith(color: _kAccentDark))),
                  IconButton(
                    onPressed: () => setState(() { _pendingImageBase64 = null; _pendingImageMime = null; }),
                    icon: const Icon(Icons.close_rounded, size: 18, color: _kAccentDark),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          Row(
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
              // Text field
              Expanded(
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black12,
                  borderRadius: BorderRadius.circular(24),
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.splashSlate900, fontSize: 15),
                    cursorColor: _kAccent,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
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
              // Send button
              Material(
                color: _kAccent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sendMessage,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedBar() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.accentGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Session complete', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                Text('Review your summary above', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
              ],
            ),
          ),
          FilledButton(
            onPressed: _startNewChat,
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text('New Chat', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
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
            Text('Attach an image', style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(icon: Icons.photo_library_rounded, label: 'Gallery', color: _kAccent, onTap: () { Navigator.pop(context); _pickImage(); }),
                _AttachOption(icon: Icons.camera_alt_rounded, label: 'Camera', color: AppColors.accentCyan, onTap: () { Navigator.pop(context); _pickCamera(); }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORY SHEET
  // ═══════════════════════════════════════════════════════════════════════════

  void _showHistorySheet() {
    _loadSessions();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final query = _historySearchController.text.trim().toLowerCase();
            final filtered = _sessions.where((s) {
              final msgs = (s['messages'] as List?) ?? [];
              final preview = msgs.isNotEmpty ? Map<String, dynamic>.from(msgs.last as Map)['message']?.toString() ?? '' : '';
              return query.isEmpty || preview.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(100))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, color: _kAccent),
                        const SizedBox(width: 10),
                        Text('Chat History', style: AppTextStyles.headlineSmall.copyWith(fontSize: 18)),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () { Navigator.pop(context); _startNewChat(); },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: TextField(
                      controller: _historySearchController,
                      onChanged: (_) => setLocal(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400),
                        filled: true,
                        fillColor: AppColors.grey50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // List
                  Expanded(
                    child: _isLoadingSessions
                        ? const Center(child: CircularProgressIndicator(color: _kAccent))
                        : filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.grey200),
                                    const SizedBox(height: 12),
                                    Text('No conversations yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final session = filtered[index];
                                  final msgs = (session['messages'] as List?) ?? [];
                                  final preview = msgs.isNotEmpty
                                      ? Map<String, dynamic>.from(msgs.last as Map)['message']?.toString() ?? 'New chat'
                                      : 'New chat';
                                  final createdAt = session['created_at']?.toString() ?? '';
                                  final isActive = session['is_active'] == true;

                                  return InkWell(
                                    onTap: () { Navigator.pop(context); _openSession(session['session_id']?.toString()); },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.grey100),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: isActive ? _kAccentLight : AppColors.grey50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              isActive ? Icons.chat_rounded : Icons.check_circle_rounded,
                                              color: isActive ? _kAccent : AppColors.accentGreen,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                                                const SizedBox(height: 2),
                                                Text(createdAt, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right_rounded, color: AppColors.grey200, size: 20),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _TopicChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TopicChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _kAccentLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _kAccent, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: _kAccentDark, fontSize: 13, fontWeight: FontWeight.w600)),
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
              width: 56,
              height: 56,
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

// ─── Chat message bubble ──────────────────────────────────────────────────

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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) _avatar(),
              if (!isUser) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? _kAccent : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isUser ? _kAccent : Colors.black).withValues(alpha: 0.08),
                        blurRadius: 10,
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
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(base64Decode(b64), fit: BoxFit.cover),
                          ),
                        ),
                      if (text.trim().isNotEmpty)
                        Text(
                          text,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: isUser ? Colors.white : AppColors.splashSlate900,
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
              if (isUser) _userAvatar(),
            ],
          ),
          if (isFinal && assessment != null) _buildFinalSummary(context),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(color: _kAccentLight, shape: BoxShape.circle),
      child: const Icon(Icons.spa_rounded, color: _kAccent, size: 18),
    );
  }

  Widget _userAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: const Icon(Icons.person_rounded, color: _kAccent, size: 18),
    );
  }

  Widget _buildFinalSummary(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16, left: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kAccentLight),
        boxShadow: [
          BoxShadow(color: _kAccent.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _kAccentLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.analytics_rounded, color: _kAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Medical Insight', style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 18),
          _summaryRow('Triage Priority', assessment!['triage_priority'] ?? 'Standard', Icons.flag_rounded,
              (assessment!['triage_priority']?.toString().toLowerCase().contains('high') ?? false) ? Colors.red : AppColors.accentGreen),
          _summaryRow('Recommended Care', assessment!['recommended_specialization'] ?? 'General Consultation', Icons.medical_services_rounded, _kAccent),
          // ── Smart doctor recommendations: matches the AI's suggested
          //    specialty against verified doctors and surfaces the best 3.
          if ((assessment!['recommended_specialization'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            _RecommendedDoctorsCard(
              specialty: assessment!['recommended_specialization'].toString(),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => context.push('/patient/book-appointment', extra: {'specialty': assessment!['recommended_specialization']}),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('See all matching doctors', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 11)),
                Text(value, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.darkBlue900, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thinking dots ────────────────────────────────────────────────────────

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: _kAccentLight, shape: BoxShape.circle),
            child: const Icon(Icons.spa_rounded, color: _kAccent, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final delay = index * 0.25;
                    final t = ((_controller.value + delay) % 1.0);
                    final scale = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _kAccent.withValues(alpha: 0.5 + 0.5 * scale),
                            shape: BoxShape.circle,
                          ),
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

/// Inline doctor-recommendation card rendered after the AI's final assessment.
///
/// Reads the AI's `recommended_specialization`, fetches verified doctors that
/// match (by `specialty` query), and shows up to three ranked picks. Tapping
/// "Book" jumps straight into the booking flow for that doctor.
class _RecommendedDoctorsCard extends StatefulWidget {
  final String specialty;
  const _RecommendedDoctorsCard({required this.specialty});

  @override
  State<_RecommendedDoctorsCard> createState() => _RecommendedDoctorsCardState();
}

class _RecommendedDoctorsCardState extends State<_RecommendedDoctorsCard> {
  bool _loading = true;
  List<Map<String, dynamic>> _doctors = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Dio().get(
        '${ApiConstants.baseUrl}providers/nearby/',
        queryParameters: {
          'specialty': widget.specialty,
          'available': 'true',
        },
      );
      final data = res.data;
      List items = data is List ? data : (data is Map ? data['results'] ?? [] : []);
      var raw = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      raw.sort((a, b) => _score(b).compareTo(_score(a)));
      if (mounted) {
        setState(() {
          _doctors = raw.take(3).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _score(Map<String, dynamic> d) {
    final rating = double.tryParse(d['rating']?.toString() ?? '0') ?? 0.0;
    final consults = double.tryParse(d['total_consultations']?.toString() ?? '0') ?? 0.0;
    final online = (d['status']?.toString() ?? '').toLowerCase() == 'online' ? 1.0 : 0.0;
    return rating * 2 + consults * 0.05 + online;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kAccentLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _kAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recommended doctors for your case',
                  style: AppTextStyles.caption.copyWith(
                    color: _kAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2)),
            )
          else if (_doctors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No verified ${widget.specialty} doctors are online right now. Try again shortly or browse the directory.',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
              ),
            )
          else
            ..._doctors.map((d) => _doctorTile(context, d)),
        ],
      ),
    );
  }

  Widget _doctorTile(BuildContext context, Map<String, dynamic> d) {
    final name = d['full_name']?.toString() ?? 'Doctor';
    final specialty = (d['specialty_name'] ??
            d['other_specialty'] ??
            d['specialty'] ??
            'General')
        .toString();
    final rating = (double.tryParse(d['rating']?.toString() ?? '0') ?? 0.0)
        .toStringAsFixed(1);
    final feeRaw = d['consultation_fee']?.toString() ?? '0';
    final fee = double.tryParse(feeRaw)?.toInt() ?? 0;
    final isOnline = (d['status']?.toString() ?? '').toLowerCase() == 'online';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), _kAccent],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 18),
              ),
              if (isOnline)
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _kAccentDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Text(
                  specialty,
                  style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 12),
                    const SizedBox(width: 2),
                    Text(rating,
                        style: AppTextStyles.caption.copyWith(
                            color: _kAccentDark, fontWeight: FontWeight.w700, fontSize: 11)),
                    if (fee > 0) ...[
                      const SizedBox(width: 8),
                      Text('· $fee XAF',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.grey500, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push(
              '/patient/doctor-profile/${d['provider_id']}',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Book',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
