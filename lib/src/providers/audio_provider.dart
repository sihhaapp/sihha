import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../services/chat_service.dart';
import '../services/voice_service.dart';
import 'app_settings_provider.dart';

class AudioProvider extends ChangeNotifier {
  AudioProvider(this._chatService, this._voiceService) {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _activeAudioUrl = null;
        _activeAudioPosition = Duration.zero;
        _activeAudioDuration = Duration.zero;
        notifyListeners();
      }
    });
    _audioPositionSubscription = _audioPlayer.positionStream.listen((position) {
      if (_activeAudioUrl == null) return;
      if (position == _activeAudioPosition) return;
      final delta =
          (position.inMilliseconds - _activeAudioPosition.inMilliseconds).abs();
      if (delta < 70 && position != Duration.zero) return;
      _activeAudioPosition = position;
      notifyListeners();
    });
    _audioDurationSubscription = _audioPlayer.durationStream.listen((duration) {
      final resolved = duration ?? Duration.zero;
      if (resolved == _activeAudioDuration) return;
      _activeAudioDuration = resolved;
      if (_activeAudioUrl != null) {
        notifyListeners();
      }
    });
  }

  final ChatService _chatService;
  final VoiceService _voiceService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  bool _isRecording = false;
  bool _isBusy = false;
  String? _errorMessage;
  String? _activeAudioUrl;
  Duration _activeAudioPosition = Duration.zero;
  Duration _activeAudioDuration = Duration.zero;
  DateTime? _recordStartedAt;

  bool get isRecording => _isRecording;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage == null
      ? null
      : AppSettingsProvider.normalizeText(_errorMessage!);
  String? get activeAudioUrl => _activeAudioUrl;
  Duration get activeAudioPosition => _activeAudioPosition;
  Duration get activeAudioDuration => _activeAudioDuration;
  double get activeAudioProgress {
    final totalMs = _activeAudioDuration.inMilliseconds;
    if (totalMs <= 0) return 0;
    final positionMs = _activeAudioPosition.inMilliseconds.clamp(0, totalMs);
    return positionMs / totalMs;
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _voiceService.startRecording();
      _recordStartedAt = DateTime.now();
      _isRecording = true;
    } catch (error) {
      _errorMessage = AppSettingsProvider.normalizeText(
        error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> stopRecordingAndSend({
    required String roomId,
    required String senderId,
    required String senderName,
  }) async {
    if (!_isRecording) return;
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      final filePath = await _voiceService.stopRecording();
      if (filePath == null || filePath.isEmpty) {
        _isRecording = false;
        return;
      }

      final startedAt = _recordStartedAt ?? DateTime.now();
      final duration = DateTime.now()
          .difference(startedAt)
          .inSeconds
          .clamp(1, 300);

      final url = await _chatService.uploadAudioFile(file: File(filePath));

      await _chatService.sendAudioMessage(
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        audioUrl: url,
        durationSeconds: duration,
      );
    } catch (error) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر إرسال الرسالة.',
        "Impossible d'envoyer le message.",
      );
    } finally {
      _isRecording = false;
      _isBusy = false;
      _recordStartedAt = null;
      notifyListeners();
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      await _voiceService.stopRecording();
    } catch (_) {
      // Ignore recorder stop failures during cancel.
    } finally {
      _isRecording = false;
      _isBusy = false;
      _recordStartedAt = null;
      notifyListeners();
    }
  }

  Future<String?> uploadConsultationSymptomsAudio({required File file}) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      return await _chatService.uploadAudioFile(file: file);
    } catch (_) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر رفع التسجيل الصوتي للأعراض.',
        'Impossible de televerser le message vocal des symptomes.',
      );
      notifyListeners();
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> playOrPauseAudio(String url) async {
    if (_activeAudioUrl == url && _audioPlayer.playing) {
      await _audioPlayer.pause();
      _activeAudioUrl = null;
      _activeAudioPosition = Duration.zero;
      _activeAudioDuration = Duration.zero;
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      if (_activeAudioUrl != url) {
        await _audioPlayer.setUrl(url);
        _activeAudioPosition = Duration.zero;
        _activeAudioDuration = _audioPlayer.duration ?? Duration.zero;
      }
      await _audioPlayer.play();
      _activeAudioUrl = url;
    } catch (_) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر تشغيل الرسالة الصوتية.',
        'Impossible de lire le message vocal.',
      );
      _activeAudioUrl = null;
      _activeAudioPosition = Duration.zero;
      _activeAudioDuration = Duration.zero;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioPlayer.dispose();
    _voiceService.dispose();
    super.dispose();
  }
}
