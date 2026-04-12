import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/api_constants.dart';

class VideoConsultationScreen extends StatefulWidget {
  final String consultationId;
  final String? doctorName;
  final bool audioOnly;

  const VideoConsultationScreen({
    super.key,
    required this.consultationId,
    this.doctorName,
    this.audioOnly = false,
  });

  @override
  State<VideoConsultationScreen> createState() => _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _isInitializing = true;
  String? _errorMessage;
  String? _appId;
  String? _token;
  bool _localUserJoined = false;
  bool _muted = false;
  bool _videoDisabled = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'You must be signed in to join the call.';
          _isInitializing = false;
        });
        return;
      }

      final response = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}agora/token/',
        queryParameters: {'channel': widget.consultationId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      _appId = response.data['app_id'] as String?;
      _token = response.data['token'] as String?;

      if (_appId == null || _token == null || _appId!.isEmpty || _token!.isEmpty) {
        setState(() {
          _errorMessage = response.data['error']?.toString() ?? 'Could not start call (missing Agora config).';
          _isInitializing = false;
        });
        return;
      }

      await _initAgora();
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not connect to the call service.';
        _isInitializing = false;
      });
    }
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: _appId!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
    _engine = engine;

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (mounted) setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          if (mounted) setState(() => _remoteUid = null);
        },
        onError: (ErrorCodeType err, String msg) {
          if (mounted) setState(() => _errorMessage ??= 'Call error: $msg');
        },
      ),
    );

    if (widget.audioOnly) {
      await engine.disableVideo();
      _videoDisabled = true;
    } else {
      await engine.enableVideo();
      await engine.startPreview();
    }

    await engine.joinChannel(
      token: _token!,
      channelId: widget.consultationId,
      options: ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: !widget.audioOnly && !_videoDisabled,
        publishMicrophoneTrack: !_muted,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
      uid: 0,
    );

    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _leave() async {
    final e = _engine;
    _engine = null;
    if (e != null) {
      await e.leaveChannel();
      await e.release();
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleMute() async {
    final e = _engine;
    if (e == null) return;
    _muted = !_muted;
    await e.muteLocalAudioStream(_muted);
    setState(() {});
  }

  Future<void> _toggleVideo() async {
    if (widget.audioOnly) return;
    final e = _engine;
    if (e == null) return;
    _videoDisabled = !_videoDisabled;
    await e.muteLocalVideoStream(_videoDisabled);
    setState(() {});
  }

  @override
  void dispose() {
    final e = _engine;
    _engine = null;
    if (e != null) {
      unawaited(e.leaveChannel());
      unawaited(e.release());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.audioOnly ? 'Audio call' : 'Video consultation';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(widget.doctorName != null ? '${widget.doctorName!} · $title' : title),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.black,
                      child: widget.audioOnly || _remoteUid == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(widget.audioOnly ? Icons.person_rounded : Icons.videocam_off_outlined,
                                      size: 72, color: Colors.white24),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.audioOnly
                                        ? 'Connected — audio only'
                                        : 'Waiting for the other party to join…',
                                    style: const TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            )
                          : AgoraVideoView(
                              controller: VideoViewController.remote(
                                rtcEngine: _engine!,
                                canvas: VideoCanvas(uid: _remoteUid),
                                connection: RtcConnection(channelId: widget.consultationId),
                              ),
                            ),
                    ),
                    if (!widget.audioOnly && _localUserJoined && _engine != null && !_videoDisabled)
                      Positioned(
                        top: 16,
                        right: 16,
                        width: 110,
                        height: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: _engine!,
                              canvas: const VideoCanvas(uid: 0),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CallButton(
                            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: Colors.white24,
                            onPressed: _toggleMute,
                          ),
                          const SizedBox(width: 20),
                          _CallButton(
                            icon: Icons.call_end_rounded,
                            color: Colors.redAccent,
                            onPressed: _leave,
                          ),
                          if (!widget.audioOnly) ...[
                            const SizedBox(width: 20),
                            _CallButton(
                              icon: _videoDisabled ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                              color: Colors.white24,
                              onPressed: _toggleVideo,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CallButton({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
