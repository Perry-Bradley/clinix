import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/call_handler.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';

class VideoConsultationScreen extends StatefulWidget {
  final String consultationId;
  final String? doctorName;
  final bool audioOnly;
  // True when this user ANSWERED a call (came in via the incoming-call
  // screen). The callee just joins — it must not ring the peer back or play
  // the caller's "calling…" ringback on its own phone.
  final bool incoming;

  const VideoConsultationScreen({
    super.key,
    required this.consultationId,
    this.doctorName,
    this.audioOnly = false,
    this.incoming = false,
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
  bool _speakerOn = true;
  bool _onHold = false;
  // AI scribe — record the call audio on the doctor's device, then upload
  // for Google STT + Gemini drafting after `End Session`.
  bool _isProvider = false;
  bool _aiScribeConsented = false;
  bool _isRecording = false;
  String? _recordingPath;
  // Caller-side ring state. The peer is "ringing" until they join the Agora
  // channel (or 30s pass). We play a soft ringback tone via the system
  // notification sound while we wait.
  bool _ringbackActive = false;
  Timer? _noAnswerTimer;
  // Set when the peer joins, so we can log a completed call (with duration)
  // in both users' call history when the call ends.
  DateTime? _connectedAt;
  // Live captions — both speakers, transcribed server-side by Groq Whisper.
  // We tap Agora's audio frames (NOT a second mic, so no contention): the
  // local mic = doctor, each remote stream = patient. Every ~10s we wrap the
  // buffered PCM for each speaker as a WAV and POST it; the server appends a
  // labeled line to the transcript and returns the text we show here.
  bool _captionsOn = true;
  String _liveCaption = '';
  bool _captureActive = false;
  // PCM16 mono 16kHz, accumulated per speaker between chunk flushes.
  final List<int> _docPcm = [];
  final List<int> _patPcm = [];
  Timer? _chunkTimer;
  AudioFrameObserver? _frameObserver;
  // Agora delivers frames on a native thread; guard the buffers' max size so a
  // stalled uploader can't grow them without bound (~60s of audio each).
  static const int _maxPcmBytes = 16000 * 2 * 60;
  // Debug-only capture counters, shown on screen in debug builds so the
  // real-device spike can see exactly where the pipeline stalls: bytes climbing
  // = frames flowing; sent/✓/✗ = uploads + server responses.
  int _dbgDocBytes = 0;
  int _dbgPatBytes = 0;
  int _dbgSent = 0;
  int _dbgOk = 0;
  int _dbgFail = 0;
  String _dbgLastErr = '';
  Timer? _dbgTimer;

  @override
  void initState() {
    super.initState();
    // Note: Wake lock temporarily disabled due to build compatibility issues
    // TODO: Implement alternative sleep prevention method
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

      // Resolve role so we know if we should offer the AI scribe to the doctor.
      try {
        final t = await AuthService.getUserType();
        _isProvider = t == 'provider';
      } catch (_) {}

      // Both sides see the AI-scribe consent before joining — patient
      // consents to being transcribed, doctor consents to recording.
      if (mounted) {
        _aiScribeConsented = await _showConsentDialog() ?? false;
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

  Future<bool?> _showConsentDialog() {
    final body = _isProvider
        ? 'Clinix can record this call and let an AI medical-scribe draft a '
          'medical report for you. You\'ll review and edit it before sending '
          'it to the patient.\n\nThe patient is shown the same prompt and '
          'must also accept.'
        : 'Your doctor would like to use Clinix\'s AI medical-scribe. The call '
          'audio will be transcribed so they can write your report faster. '
          'Only your doctor sees the draft, and they review every word before '
          'it lands in your medical record.';
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.darkBlue500),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AI medical scribe',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.darkBlue900,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
        ]),
        content: Text(
          body,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.darkBlue900,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Skip',
              style: TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            child: const Text(
              'Allow AI scribe',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
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
          // Peer answered → stop the ringback tone + clear the "ringing"
          // overlay. From here it's just a normal call.
          _stopRingback();
          _connectedAt ??= DateTime.now();
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

    // Only the CALLER rings the peer and shows the "calling…" state. The
    // callee already answered via the incoming-call screen, so it just joins
    // — no ringing its own phone, no calling the caller back.
    if (!widget.incoming) {
      unawaited(_ringPeer());
      _startRingback();
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

    // Start the AI-scribe recording on the doctor's device only — patient
    // mics aren't recorded locally; both voices are still captured because
    // Agora's mixed recording includes the remote audio stream.
    if (_isProvider && _aiScribeConsented) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        _recordingPath = '${dir.path}/clinix_call_${widget.consultationId}.wav';
        // Wipe any leftover recording from a previous attempt.
        final f = File(_recordingPath!);
        if (await f.exists()) await f.delete();
        await engine.startAudioRecording(AudioRecordingConfiguration(
          filePath: _recordingPath!,
          sampleRate: 16000,
          fileRecordingType: AudioFileRecordingType.audioFileRecordingMixed,
          quality: AudioRecordingQualityType.audioRecordingQualityMedium,
        ));
        _isRecording = true;
      } catch (e) {
        debugPrint('[AIScribe] Could not start recording: $e');
      }
    }

    // Live, both-speaker captions — only the doctor's device captures + posts,
    // and only when the AI scribe was consented (same privacy surface as the
    // recording). The transcript it builds is what the AI report reads.
    if (_isProvider && _aiScribeConsented) {
      _startLiveCaptions();
    }

    if (mounted) setState(() => _isInitializing = false);
  }

  // ---- Live captions: tap Agora audio frames → chunked Groq Whisper ------

  void _startLiveCaptions() {
    final e = _engine;
    if (e == null || _captureActive || !_captionsOn) return;
    try {
      // Ask Agora to deliver both the local mic and each remote stream as
      // 16kHz mono PCM (read-only — we don't modify the call audio).
      e.setRecordingAudioFrameParameters(
        sampleRate: 16000,
        channel: 1,
        mode: RawAudioFrameOpModeType.rawAudioFrameOpModeReadOnly,
        samplesPerCall: 1024,
      );
      e.setPlaybackAudioFrameBeforeMixingParameters(
        sampleRate: 16000,
        channel: 1,
      );

      _frameObserver = AudioFrameObserver(
        // Local mic = the doctor.
        onRecordAudioFrame: (String channelId, AudioFrame frame) {
          _appendFrame(_docPcm, frame);
        },
        // Each remote stream, pre-mix = the patient.
        onPlaybackAudioFrameBeforeMixing:
            (String channelId, int uid, AudioFrame frame) {
          _appendFrame(_patPcm, frame);
        },
      );
      e.getMediaEngine().registerAudioFrameObserver(_frameObserver!);

      _captureActive = true;
      // Flush a chunk per speaker every 10s. The very first flush also covers
      // anything spoken while the call was still ringing.
      _chunkTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(_flushChunks()),
      );
      // Repaint the on-screen debug counter once a second (debug builds only).
      if (kDebugMode) {
        _dbgTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    } catch (e) {
      debugPrint('[Captions] could not start audio capture: $e');
    }
  }

  void _appendFrame(List<int> buf, AudioFrame frame) {
    final data = frame.buffer;
    if (data == null || data.isEmpty) return;
    if (identical(buf, _docPcm)) {
      _dbgDocBytes += data.length;
    } else {
      _dbgPatBytes += data.length;
    }
    // Drop oldest audio if an upload stalls, so memory stays bounded.
    if (buf.length + data.length > _maxPcmBytes) {
      final overflow = buf.length + data.length - _maxPcmBytes;
      buf.removeRange(0, overflow.clamp(0, buf.length));
    }
    buf.addAll(data);
  }

  /// Snapshot each speaker's buffer, wrap as a WAV, and POST for transcription.
  Future<void> _flushChunks() async {
    if (!_captionsOn) return;
    await Future.wait([
      _flushOne(_docPcm, 'doctor'),
      _flushOne(_patPcm, 'patient'),
    ]);
  }

  Future<void> _flushOne(List<int> buf, String speaker) async {
    if (buf.isEmpty) return;
    final pcm = Uint8List.fromList(buf);
    buf.clear();
    // Skip near-silent chunks to save API calls (PCM16 silence ≈ all zeros).
    if (pcm.length < 16000) return; // <0.5s of audio
    final wav = _wrapWav(pcm);
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) return;
      _dbgSent++;
      final form = FormData.fromMap({
        'speaker': speaker,
        'audio': MultipartFile.fromBytes(wav, filename: '$speaker.wav'),
      });
      final resp = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}${widget.consultationId}/transcribe-chunk/',
        data: form,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      _dbgOk++;
      final data = resp.data is Map ? resp.data as Map : const {};
      final text = (data['text'])?.toString() ?? '';
      // Server now never 500s — it reports save problems in the body instead.
      if (data['saved'] == false) {
        _dbgLastErr = 'save:${(data['error'] ?? '').toString()}';
      } else if (data['stage'] == 'groq') {
        _dbgLastErr = 'groq:${(data['error'] ?? '').toString()}';
      }
      if (text.isNotEmpty && mounted && _captionsOn) {
        final who = speaker == 'doctor' ? 'You' : 'Patient';
        setState(() => _liveCaption = '$who: $text');
      }
    } catch (e) {
      _dbgFail++;
      // Capture the real reason so the on-screen probe shows it (HTTP status
      // for a rejected request, or the timeout/connection type otherwise).
      if (e is DioException) {
        final code = e.response?.statusCode;
        _dbgLastErr = code != null ? 'HTTP $code' : e.type.name;
      } else {
        _dbgLastErr = e.runtimeType.toString();
      }
      debugPrint('[Captions] chunk upload failed: $e');
    }
  }

  /// Prepend a 44-byte PCM16 WAV header (mono, 16kHz) to raw samples.
  Uint8List _wrapWav(Uint8List pcm,
      {int sampleRate = 16000, int channels = 1, int bitsPerSample = 16}) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLen = pcm.length;
    final b = BytesBuilder();
    void str(String s) => b.add(ascii.encode(s));
    void u32(int v) => b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void u16(int v) => b.add([v & 0xff, (v >> 8) & 0xff]);
    str('RIFF');
    u32(36 + dataLen);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1); // PCM
    u16(channels);
    u32(sampleRate);
    u32(byteRate);
    u16(blockAlign);
    u16(bitsPerSample);
    str('data');
    u32(dataLen);
    b.add(pcm);
    return b.toBytes();
  }

  Future<void> _stopLiveCaptions() async {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _dbgTimer?.cancel();
    _dbgTimer = null;
    final e = _engine;
    if (_frameObserver != null && e != null) {
      try {
        e.getMediaEngine().unregisterAudioFrameObserver(_frameObserver!);
      } catch (_) {}
    }
    _frameObserver = null;
    _captureActive = false;
    // Send whatever's left so the last few seconds aren't lost.
    await _flushChunks();
    _docPcm.clear();
    _patPcm.clear();
  }

  Future<void> _toggleCaptions() async {
    _captionsOn = !_captionsOn;
    if (_captionsOn) {
      if (_isProvider && _aiScribeConsented) _startLiveCaptions();
    } else {
      await _stopLiveCaptions();
      _liveCaption = '';
    }
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    _stopRingback();
    // Clear any native CallKit entry for this call so it doesn't linger or
    // keep ringing after the call ends.
    unawaited(CallHandler.endCall(widget.consultationId));
    await _stopLiveCaptions();
    final e = _engine;
    final wasRecording = _isRecording;
    final recordingPath = _recordingPath;
    _engine = null;
    _isRecording = false;
    if (e != null) {
      if (wasRecording) {
        try {
          await e.stopAudioRecording();
        } catch (err) {
          debugPrint('[AIScribe] Stop recording error: $err');
        }
      }
      await e.leaveChannel();
      await e.release();
    }
    // Fire-and-forget upload — keep the user out of a wait state. The doctor
    // gets a push notification when the AI draft is ready.
    if (wasRecording && recordingPath != null) {
      unawaited(_uploadRecording(recordingPath));
    }
    // Draft the AI report from the LIVE transcript — this works even when the
    // WAV/Cloud-Storage path isn't configured. Doctor side, scribe consented.
    // (Server de-dupes, so this is safe alongside the upload trigger.)
    if (_isProvider && _aiScribeConsented) {
      unawaited(_finalizeReport());
    }
    // Connected calls land in both users' call history with their duration.
    if (_connectedAt != null) {
      final secs = DateTime.now().difference(_connectedAt!).inSeconds;
      unawaited(_logCompletedCall(secs));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finalizeReport() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) return;
      await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}${widget.consultationId}/finalize/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      debugPrint('[AIScribe] Finalize failed: $e');
    }
  }

  Future<void> _logCompletedCall(int durationSeconds) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) return;
      await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}${widget.consultationId}/ring/missed/',
        data: {'reason': 'completed', 'duration_seconds': durationSeconds},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Best-effort logging.
    }
  }

  Future<void> _ringPeer() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) return;
      await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}${widget.consultationId}/ring/',
        data: {'audio_only': widget.audioOnly},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Ringing is best-effort — even if it fails, the call still works for
      // any user already in the appointment screen.
    }
  }

  void _startRingback() {
    if (_ringbackActive) return;
    _ringbackActive = true;
    // No audible ringback on the caller's own phone — you're the one calling,
    // so we just show the "Ringing…" state visually. (The CALLEE's phone rings
    // loudly via the incoming-call screen; that's the ring that matters.)
    // Auto-give-up after 45 seconds if the peer doesn't answer.
    _noAnswerTimer?.cancel();
    _noAnswerTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && _remoteUid == null) {
        _stopRingback();
        unawaited(_logMissedCall('no_answer'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No answer. The call was logged in your inbox.')),
        );
        _leave();
      }
    });
  }

  Future<void> _logMissedCall(String reason) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) return;
      await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}${widget.consultationId}/ring/missed/',
        data: {'reason': reason},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Best-effort — the in-app missed-call inbox entry is nice-to-have.
    }
  }

  void _stopRingback() {
    if (!_ringbackActive) return;
    _ringbackActive = false;
    _noAnswerTimer?.cancel();
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
  }

  Future<void> _uploadRecording(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) return;
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(path, filename: 'call.wav'),
      });
      await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}${widget.consultationId}/audio/',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      // Clean up the local file once it's safely on the server.
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      debugPrint('[AIScribe] Upload failed: $e');
    }
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

  Future<void> _toggleSpeaker() async {
    final e = _engine;
    if (e == null) return;
    _speakerOn = !_speakerOn;
    await e.setEnableSpeakerphone(_speakerOn);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    if (widget.audioOnly) return;
    final e = _engine;
    if (e == null) return;
    await e.switchCamera();
  }

  Future<void> _toggleHold() async {
    final e = _engine;
    if (e == null) return;
    _onHold = !_onHold;
    await e.muteLocalAudioStream(_onHold || _muted);
    if (!widget.audioOnly) {
      await e.muteLocalVideoStream(_onHold || _videoDisabled);
    }
    setState(() {});
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(100))),
              const SizedBox(height: 12),
              if (!widget.audioOnly)
                _MoreMenuItem(
                  icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  label: _speakerOn ? 'Speaker On' : 'Speaker Off',
                  onTap: () { Navigator.pop(ctx); _toggleSpeaker(); },
                ),
              _MoreMenuItem(
                icon: _onHold ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: _onHold ? 'Resume call' : 'Hold call',
                onTap: () { Navigator.pop(ctx); _toggleHold(); },
              ),
              if (_isProvider && _aiScribeConsented)
                _MoreMenuItem(
                  icon: _captionsOn
                      ? Icons.closed_caption_rounded
                      : Icons.closed_caption_disabled_rounded,
                  label: _captionsOn ? 'Hide live captions' : 'Show live captions',
                  onTap: () { Navigator.pop(ctx); _toggleCaptions(); },
                ),
              _MoreMenuItem(
                icon: Icons.chat_bubble_rounded,
                label: 'Open chat',
                onTap: () { Navigator.pop(ctx); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopRingback();
    _chunkTimer?.cancel();
    _dbgTimer?.cancel();
    final e = _engine;
    _engine = null;
    if (e != null) {
      if (_frameObserver != null) {
        try {
          e.getMediaEngine().unregisterAudioFrameObserver(_frameObserver!);
        } catch (_) {}
      }
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
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF111827), Colors.black],
                        ),
                      ),
                    ),
                    ColoredBox(
                      color: Colors.black,
                      child: widget.audioOnly || _remoteUid == null
                          ? _CallingOverlay(
                              peerName: widget.doctorName,
                              audioOnly: widget.audioOnly,
                              onHold: _onHold,
                              connected: _remoteUid != null,
                              ringing: _ringbackActive && _remoteUid == null,
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
                      top: 18,
                      left: 18,
                      right: 18,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.doctorName ?? (widget.audioOnly ? 'Audio consultation' : 'Video consultation'),
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _onHold
                                        ? 'On hold'
                                        : _remoteUid != null
                                            ? 'Connected'
                                            : (_ringbackActive ? 'Ringing…' : 'Connecting…'),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Debug-only capture probe (debug builds, doctor side). Lets
                    // the real-device spike see the pipeline stage by stage:
                    // doc/pat KB climbing = Agora frames flowing; sent/✓/✗ =
                    // chunk uploads + server responses.
                    if (kDebugMode && _captureActive)
                      Positioned(
                        top: 86,
                        left: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                          ),
                          child: Text(
                            'cap doc ${(_dbgDocBytes / 1024).round()}KB · '
                            'pat ${(_dbgPatBytes / 1024).round()}KB · '
                            'sent $_dbgSent ✓$_dbgOk ✗$_dbgFail'
                            '${_dbgLastErr.isEmpty ? '' : '\n$_dbgLastErr'}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // Live caption strip — the local speaker's words as they
                    // talk. Sits just above the call controls.
                    if (_captionsOn && _liveCaption.isNotEmpty)
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 124,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.10)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.closed_caption_rounded, color: Colors.white70, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _liveCaption,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 30,
                      child: Column(
                        children: [
                          if (_onHold)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text('Call on hold', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CallButton(
                                icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                color: _muted ? Colors.white : Colors.white24,
                                iconColor: _muted ? Colors.black87 : Colors.white,
                                onPressed: _toggleMute,
                              ),
                              const SizedBox(width: 18),
                              if (!widget.audioOnly)
                                _CallButton(
                                  icon: _videoDisabled ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                                  color: _videoDisabled ? Colors.white : Colors.white24,
                                  iconColor: _videoDisabled ? Colors.black87 : Colors.white,
                                  onPressed: _toggleVideo,
                                )
                              else
                                _CallButton(
                                  icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                  color: _speakerOn ? Colors.white24 : Colors.white,
                                  iconColor: _speakerOn ? Colors.white : Colors.black87,
                                  onPressed: _toggleSpeaker,
                                ),
                              const SizedBox(width: 18),
                              if (!widget.audioOnly)
                                _CallButton(
                                  icon: Icons.cameraswitch_rounded,
                                  color: Colors.white24,
                                  iconColor: Colors.white,
                                  onPressed: _switchCamera,
                                ),
                              if (!widget.audioOnly) const SizedBox(width: 18),
                              // More menu (3-dots) — Speaker, Hold, etc.
                              _CallButton(
                                icon: Icons.more_vert_rounded,
                                color: Colors.white24,
                                iconColor: Colors.white,
                                onPressed: _showMoreMenu,
                              ),
                              const SizedBox(width: 18),
                              _CallButton(
                                icon: Icons.call_end_rounded,
                                color: Colors.redAccent,
                                iconColor: Colors.white,
                                onPressed: _leave,
                                size: 64,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MoreMenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onPressed;
  final double size;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.iconColor = Colors.white,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: size * 0.44),
        ),
      ),
    );
  }
}

/// Caller-side waiting screen — shows the peer's avatar with a soft pulsing
/// ring and a "Calling… / Ringing…" caption while we wait for them to join
/// the Agora channel. Reused for audio-only calls too (no remote video).
class _CallingOverlay extends StatefulWidget {
  final String? peerName;
  final bool audioOnly;
  final bool onHold;
  final bool connected;
  final bool ringing;
  const _CallingOverlay({
    required this.peerName,
    required this.audioOnly,
    required this.onHold,
    required this.connected,
    required this.ringing,
  });

  @override
  State<_CallingOverlay> createState() => _CallingOverlayState();
}

class _CallingOverlayState extends State<_CallingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final cleaned = name
        .replaceAll(
            RegExp(r'^(Dr\.?|Doctor|Mr\.?|Mrs\.?|Ms\.?)\s+',
                caseSensitive: false),
            '')
        .trim();
    if (cleaned.isEmpty) return '?';
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _statusText() {
    if (widget.onHold) return 'On hold';
    if (widget.connected && widget.audioOnly) return 'Connected — audio only';
    if (widget.ringing) return 'Ringing…';
    return 'Calling…';
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.peerName == null || widget.peerName!.trim().isEmpty)
        ? 'Clinix'
        : widget.peerName!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = _pulse.value;
              return SizedBox(
                width: 200, height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140 + 60 * t,
                      height: 140 + 60 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity((1 - t) * 0.14),
                      ),
                    ),
                    Container(
                      width: 120, height: 120,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.darkBlue500,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusText(),
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
