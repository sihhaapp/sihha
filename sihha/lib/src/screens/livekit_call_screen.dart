import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';

enum _SpeakerRole { none, local, remote }

class LiveKitCallScreen extends StatefulWidget {
  const LiveKitCallScreen({
    super.key,
    required this.roomId,
    required this.url,
    required this.token,
    required this.roomName,
    required this.localDisplayName,
    required this.localPhotoUrl,
    required this.localRoleLabel,
    required this.remoteDisplayName,
    required this.remotePhotoUrl,
    required this.remoteRoleLabel,
  });

  final String roomId;
  final String url;
  final String token;
  final String roomName;
  final String localDisplayName;
  final String localPhotoUrl;
  final String localRoleLabel;
  final String remoteDisplayName;
  final String remotePhotoUrl;
  final String remoteRoleLabel;

  @override
  State<LiveKitCallScreen> createState() => _LiveKitCallScreenState();
}

class _LiveKitCallScreenState extends State<LiveKitCallScreen>
    with SingleTickerProviderStateMixin {
  late final Room _room;
  late final EventsListener<RoomEvent> _listener;
  late final AnimationController _pulseController;

  Timer? _clockTimer;
  Timer? _liveStatusTimer;
  DateTime? _connectedAt;

  bool _connecting = true;
  bool _connected = false;
  bool _micEnabled = true;
  bool _speakerEnabled = true;
  bool _closing = false;
  String? _error;

  String? _remoteIdentity;
  bool _hadRemoteParticipant = false;
  bool _localSpeaking = false;
  bool _remoteSpeaking = false;
  _SpeakerRole _dominantSpeaker = _SpeakerRole.none;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
      ),
    );
    _listener = _room.createListener();
    _listener
      ..on<RoomDisconnectedEvent>((_) {
        if (!mounted || _closing) return;
        _liveStatusTimer?.cancel();
        setState(() {
          _connected = false;
          _connecting = false;
          _localSpeaking = false;
          _remoteSpeaking = false;
          _dominantSpeaker = _SpeakerRole.none;
        });
        _closeScreen(stopSessionOnReturn: false);
      })
      ..on<RoomReconnectingEvent>((_) {
        if (!mounted) return;
        setState(() => _connecting = true);
      })
      ..on<RoomReconnectedEvent>((_) {
        if (!mounted) return;
        setState(() => _connecting = false);
      })
      ..on<ParticipantConnectedEvent>((event) {
        if (!mounted) return;
        setState(() {
          _hadRemoteParticipant = true;
          _remoteIdentity = event.participant.identity;
        });
        _recomputeSpeakingFromRoom();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        if (!mounted) return;
        setState(() {
          if (_remoteIdentity == event.participant.identity) {
            _remoteIdentity = null;
          }
          if (_room.remoteParticipants.isNotEmpty) {
            _hadRemoteParticipant = true;
            _remoteIdentity = _room.remoteParticipants.keys.first;
          }
        });
        if (_hadRemoteParticipant && _room.remoteParticipants.isEmpty) {
          unawaited(_endByRemoteHangup());
          return;
        }
        _recomputeSpeakingFromRoom();
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        _applyActiveSpeakers(event.speakers);
      });

    unawaited(_connect());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _liveStatusTimer?.cancel();
    _pulseController.dispose();
    _listener.dispose();
    unawaited(_room.disconnect());
    _room.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      await _room.connect(
        widget.url,
        widget.token,
        fastConnectOptions: FastConnectOptions(
          microphone: TrackOption(enabled: true),
          camera: TrackOption(enabled: false),
        ),
      );

      await _room.localParticipant?.setMicrophoneEnabled(true);
      await _room.localParticipant?.setCameraEnabled(false);
      await Hardware.instance.setSpeakerphoneOn(true);

      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = true;
        _micEnabled = true;
        _speakerEnabled = true;
        _error = null;
        if (_room.remoteParticipants.isNotEmpty) {
          _hadRemoteParticipant = true;
          _remoteIdentity = _room.remoteParticipants.keys.first;
        }
      });
      _connectedAt = DateTime.now();
      _startElapsedClock();
      _startLiveStatusWatcher();
      _recomputeSpeakingFromRoom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = false;
        _error = 'Unable to connect to call server.';
      });
    }
  }

  void _startElapsedClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _connectedAt == null || !_connected) return;
      setState(() {
        _elapsed = DateTime.now().difference(_connectedAt!);
      });
    });
  }

  void _startLiveStatusWatcher() {
    _liveStatusTimer?.cancel();
    _liveStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_checkLiveSessionStillActive());
    });
  }

  Future<void> _checkLiveSessionStillActive() async {
    if (!mounted || _closing || !_connected) return;
    final session = await context.read<ChatProvider>().fetchLiveStatus(
      widget.roomId,
    );
    if (!mounted || _closing || session == null) return;
    final status = ((session['status'] as String?) ?? 'idle').toLowerCase();
    if (status == 'active') return;
    await _endByRemoteHangup();
  }

  RemoteParticipant? get _remoteParticipant {
    if (_remoteIdentity != null) {
      final current = _room.remoteParticipants[_remoteIdentity!];
      if (current != null) return current;
    }
    if (_room.remoteParticipants.isNotEmpty) {
      return _room.remoteParticipants.values.first;
    }
    return null;
  }

  void _recomputeSpeakingFromRoom() {
    _applyActiveSpeakers(_room.activeSpeakers);
  }

  void _applyActiveSpeakers(List<Participant> speakers) {
    final local = _room.localParticipant;
    final remote = _remoteParticipant;

    var localSpeaking = false;
    var remoteSpeaking = false;
    var dominant = _SpeakerRole.none;

    for (final p in speakers) {
      if (local != null && p.identity == local.identity) {
        localSpeaking = true;
        dominant = dominant == _SpeakerRole.none ? _SpeakerRole.local : dominant;
        continue;
      }

      final isCurrentRemote = remote != null && p.identity == remote.identity;
      final isKnownRemote = _room.remoteParticipants.containsKey(p.identity);
      if (isCurrentRemote || isKnownRemote) {
        remoteSpeaking = true;
        dominant = dominant == _SpeakerRole.none ? _SpeakerRole.remote : dominant;
        if (_remoteIdentity != p.identity) {
          _remoteIdentity = p.identity;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _localSpeaking = localSpeaking;
      _remoteSpeaking = remoteSpeaking;
      _dominantSpeaker = dominant;
    });
  }

  Future<void> _toggleMic() async {
    final target = !_micEnabled;
    try {
      await _room.localParticipant?.setMicrophoneEnabled(target);
      if (!mounted) return;
      setState(() => _micEnabled = target);
    } catch (_) {}
  }

  Future<void> _toggleSpeaker() async {
    final target = !_speakerEnabled;
    try {
      await Hardware.instance.setSpeakerphoneOn(target);
      if (!mounted) return;
      setState(() => _speakerEnabled = target);
    } catch (_) {}
  }

  Future<void> _hangup() async {
    if (_closing) return;
    _closing = true;
    _liveStatusTimer?.cancel();
    try {
      await _room.disconnect();
    } catch (_) {}
    _closeScreen(stopSessionOnReturn: true);
  }

  Future<void> _endByRemoteHangup() async {
    if (_closing) return;
    _closing = true;
    _liveStatusTimer?.cancel();
    try {
      await _room.disconnect();
    } catch (_) {}
    _closeScreen(stopSessionOnReturn: true);
  }

  void _closeScreen({required bool stopSessionOnReturn}) {
    if (!mounted) return;
    Navigator.of(context).maybePop(stopSessionOnReturn);
  }

  String get _statusText {
    if (_error != null) return _error!;
    if (_connecting) return 'Connecting...';
    if (!_connected) return 'Disconnected';
    if (_remoteParticipant == null) return 'Connected - waiting for participant';
    if (_dominantSpeaker == _SpeakerRole.local) {
      return '${widget.localDisplayName} is speaking';
    }
    if (_dominantSpeaker == _SpeakerRole.remote) {
      return '${widget.remoteDisplayName} is speaking';
    }
    return 'Connected';
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgTop = isDark ? const Color(0xFF061725) : const Color(0xFFE8F5FF);
    final bgBottom = isDark ? const Color(0xFF0B2F45) : const Color(0xFFCFE8F9);
    final statusColor = _error != null
        ? const Color(0xFFE53935)
        : (_connecting ? const Color(0xFFFFA726) : const Color(0xFF11A77F));

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: _hangup,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.roomName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFE9F4FF)
                                  : const Color(0xFF143A55),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_connected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.5),
                          ),
                        ),
                        child: Text(
                          _formatDuration(_elapsed),
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFEAF3FA)
                                : const Color(0xFF143A55),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulse = 0.75 + 0.25 * math.sin(_pulseController.value * math.pi * 2);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ParticipantBadge(
                            name: widget.remoteDisplayName,
                            role: widget.remoteRoleLabel,
                            imageUrl: widget.remotePhotoUrl,
                            speaking: _remoteSpeaking,
                            dominant: _dominantSpeaker == _SpeakerRole.remote,
                            pulseValue: pulse,
                            online: _remoteParticipant != null,
                          ),
                          const SizedBox(height: 34),
                          _ParticipantBadge(
                            name: widget.localDisplayName,
                            role: widget.localRoleLabel,
                            imageUrl: widget.localPhotoUrl,
                            speaking: _localSpeaking,
                            dominant: _dominantSpeaker == _SpeakerRole.local,
                            pulseValue: pulse,
                            online: _connected,
                            isLocal: true,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _ActionPillButton(
                        icon: _micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                        label: _micEnabled ? 'Mute' : 'Unmute',
                        onPressed: _connected ? _toggleMic : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionPillButton(
                        icon: _speakerEnabled
                            ? Icons.volume_up_rounded
                            : Icons.hearing_rounded,
                        label: _speakerEnabled ? 'Speaker' : 'Earpiece',
                        onPressed: _connected ? _toggleSpeaker : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _hangup,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.call_end_rounded),
                    label: const Text(
                      'Hang up',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantBadge extends StatelessWidget {
  const _ParticipantBadge({
    required this.name,
    required this.role,
    required this.imageUrl,
    required this.speaking,
    required this.dominant,
    required this.pulseValue,
    required this.online,
    this.isLocal = false,
  });

  final String name;
  final String role;
  final String imageUrl;
  final bool speaking;
  final bool dominant;
  final double pulseValue;
  final bool online;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanName = name.trim().isEmpty ? (isLocal ? 'You' : 'Participant') : name.trim();
    final glow = speaking
        ? const Color(0xFF14C9A0).withValues(alpha: 0.34 * pulseValue)
        : Colors.black.withValues(alpha: isDark ? 0.14 : 0.07);
    final borderColor = dominant
        ? const Color(0xFF14C9A0)
        : Colors.white.withValues(alpha: isDark ? 0.20 : 0.70);

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      scale: speaking ? 1.03 : 1.0,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 152,
            height: 152,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: dominant ? 3 : 2),
              boxShadow: [
                BoxShadow(
                  color: glow,
                  blurRadius: speaking ? 28 : 12,
                  spreadRadius: speaking ? 2.5 : 0.5,
                ),
              ],
            ),
            child: ClipOval(
              child: imageUrl.trim().isEmpty
                  ? _InitialAvatar(name: cleanName)
                  : Image.network(
                      imageUrl.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) =>
                          _InitialAvatar(name: cleanName),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cleanName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? const Color(0xFFE8F3FD) : const Color(0xFF11344D),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.09),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.65),
              ),
            ),
            child: Text(
              speaking
                  ? '$role • speaking'
                  : '$role • ${online ? 'listening' : 'offline'}',
              style: TextStyle(
                color: isDark ? const Color(0xFFD9EBF9) : const Color(0xFF244963),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E8EC0), Color(0xFF11A77F)],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 58,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: isDark ? const Color(0xFFE9F4FF) : const Color(0xFF1A4663),
          ),
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: isDark ? 0.12 : 0.72),
        foregroundColor: isDark ? const Color(0xFFE7F4FF) : const Color(0xFF0F3D58),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
