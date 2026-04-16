import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/direct_chat_service.dart';

/// Resolves a provider_id into a conversation_id, then opens DirectChatScreen.
class DirectChatLauncher extends StatefulWidget {
  final String providerId;
  final String? doctorName;
  final String? doctorPhoto;

  const DirectChatLauncher({
    super.key,
    required this.providerId,
    this.doctorName,
    this.doctorPhoto,
  });

  @override
  State<DirectChatLauncher> createState() => _DirectChatLauncherState();
}

class _DirectChatLauncherState extends State<DirectChatLauncher> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final conv = await DirectChatService.startWithProvider(widget.providerId);
      final convId = conv['conversation_id']?.toString();
      if (convId == null) throw Exception('No conversation_id in response');

      if (!mounted) return;
      final peerName = widget.doctorName ?? conv['peer_name']?.toString() ?? '';
      final peerPhoto = widget.doctorPhoto ?? conv['peer_photo']?.toString() ?? '';

      // Build the query string safely
      final params = <String, String>{};
      if (peerName.isNotEmpty) params['name'] = peerName;
      if (peerPhoto.isNotEmpty) params['photo'] = peerPhoto;
      final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final path = qs.isEmpty ? '/dchat/$convId' : '/dchat/$convId?$qs';

      // Defer navigation until after the current frame to avoid the _debugLocked
      // assertion when running inside a GoRouter transition.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.pushReplacement(path);
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open chat: $e');
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.darkBlue900),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator(color: AppColors.sky500)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
              ),
      ),
    );
  }
}
