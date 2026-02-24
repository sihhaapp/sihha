import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/consultation_request.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/voice_service.dart';
import 'app_settings_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._chatService, this._voiceService) {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _activeAudioUrl = null;
        notifyListeners();
      }
    });
  }

  final ChatService _chatService;
  final VoiceService _voiceService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isRecording = false;
  bool _isBusy = false;
  String? _errorMessage;
  String? _activeAudioUrl;
  DateTime? _recordStartedAt;

  bool get isRecording => _isRecording;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String? get activeAudioUrl => _activeAudioUrl;

  Stream<List<AppUser>> doctorsStream() {
    return _chatService.doctorsStream();
  }

  Stream<List<ChatRoom>> chatRoomsStream({
    required String userId,
    required UserRole role,
    bool liveMode = false,
  }) {
    return _chatService.chatRoomsForUser(
      userId: userId,
      role: role,
      interval: liveMode
          ? const Duration(milliseconds: 1200)
          : const Duration(seconds: 3),
    );
  }

  Stream<List<ChatMessage>> messagesStream(
    String roomId, {
    bool liveMode = false,
  }) {
    return _chatService.messagesForRoom(
      roomId,
      interval: liveMode
          ? const Duration(milliseconds: 800)
          : const Duration(seconds: 2),
    );
  }

  Future<ChatRoom> createOrGetRoom({
    required AppUser patient,
    required AppUser doctor,
  }) {
    return _chatService.createOrGetRoom(patient: patient, doctor: doctor);
  }

  Future<ChatRoom?> findRoomWithDoctor(String doctorId) async {
    try {
      return await _chatService.findRoomWithDoctor(doctorId);
    } catch (_) {
      return null;
    }
  }

  Future<ChatRoom?> getRoomById(String roomId) async {
    try {
      return await _chatService.getRoomById(roomId);
    } catch (_) {
      return null;
    }
  }

  Stream<List<ConsultationRequest>> myConsultationRequestsStream({
    bool liveMode = false,
  }) {
    return _chatService.myConsultationRequestsStream(
      interval: liveMode
          ? const Duration(milliseconds: 1200)
          : const Duration(seconds: 3),
    );
  }

  Stream<List<ConsultationRequest>> doctorConsultationInboxStream({
    bool liveMode = false,
  }) {
    return _chatService.doctorConsultationInboxStream(
      interval: liveMode
          ? const Duration(milliseconds: 1200)
          : const Duration(seconds: 3),
    );
  }

  Future<ConsultationRequest?> submitConsultationRequest({
    required String doctorId,
    required RequestSubjectType subjectType,
    required String subjectName,
    required int ageYears,
    required RequestGender gender,
    required double weightKg,
    required String stateCode,
    required SpokenLanguage spokenLanguage,
    required String symptoms,
  }) async {
    _errorMessage = null;
    notifyListeners();
    try {
      return await _chatService.submitConsultationRequest(
        doctorId: doctorId,
        subjectType: subjectType,
        subjectName: subjectName,
        ageYears: ageYears,
        gender: gender,
        weightKg: weightKg,
        stateCode: stateCode,
        spokenLanguage: spokenLanguage,
        symptoms: symptoms,
      );
    } catch (error) {
      _mapConsultationError(error);
      return null;
    }
  }

  Future<Map<String, dynamic>?> acceptConsultationRequest(String requestId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _chatService.acceptConsultationRequest(requestId);
      final request = ConsultationRequest.fromMap(
        response['request'] as Map<String, dynamic>,
      );
      final room = ChatRoom.fromMap(
        ((response['room'] as Map<String, dynamic>?)?['id'] as String?) ?? '',
        response['room'] as Map<String, dynamic>,
      );
      return {'request': request, 'room': room};
    } catch (error) {
      _mapConsultationError(error);
      return null;
    }
  }

  Future<ConsultationRequest?> rejectConsultationRequest(String requestId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      return await _chatService.rejectConsultationRequest(requestId);
    } catch (error) {
      _mapConsultationError(error);
      return null;
    }
  }

  Future<ConsultationRequest?> transferConsultationRequest({
    required String requestId,
    required String doctorId,
  }) async {
    _errorMessage = null;
    notifyListeners();
    try {
      return await _chatService.transferConsultationRequest(
        requestId: requestId,
        doctorId: doctorId,
      );
    } catch (error) {
      _mapConsultationError(error);
      return null;
    }
  }

  Future<void> sendTextMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    await _chatService.sendTextMessage(
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      text: text,
    );
  }

  Future<bool> sendImageMessage({
    required String roomId,
    required File imageFile,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      final imageUrl = await _chatService.uploadImageFile(file: imageFile);
      await _chatService.sendImageMessage(roomId: roomId, imageUrl: imageUrl);
      return true;
    } catch (_) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر إرسال الصورة.',
        'Impossible d\'envoyer l\'image.',
      );
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> setLiveMode({
    required String roomId,
    required bool enabled,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      if (enabled) {
        await _chatService.requestLiveSession(roomId);
      } else {
        await _chatService.stopLiveSession(roomId);
      }
    } catch (error) {
      if (error is ApiException && error.code == "live-peer-offline") {
        _errorMessage = AppSettingsProvider.trGlobal(
          'لا يمكن بدء المحادثة المباشرة قبل دخول الطرف الآخر للمحادثة.',
          'La conversation directe ne peut demarrer que si les deux participants sont en ligne.',
        );
      } else if (error is ApiException &&
          error.code == "live-request-pending-other") {
        _errorMessage = AppSettingsProvider.trGlobal(
          'يوجد طلب محادثة مباشرة معلّق من الطرف الآخر.',
          'Une demande de conversation directe est deja en attente.',
        );
      } else {
        _errorMessage = AppSettingsProvider.trGlobal(
          'تعذر تحديث حالة المحادثة المباشرة.',
          'Impossible de mettre a jour l\'etat de la conversation directe.',
        );
      }
      notifyListeners();
    }
  }

  Future<void> setPresence({
    required String roomId,
    required bool active,
  }) async {
    try {
      await _chatService.setPresence(roomId: roomId, active: active);
    } catch (_) {
      // Ignore presence update failures silently.
    }
  }

  Future<void> sendLivePulse(String roomId) async {
    try {
      await _chatService.sendLiveMessage(
        roomId: roomId,
        content: '[LIVE_SIGNAL]',
      );
    } catch (error) {
      if (error is ApiException && error.code == "live-peer-offline") {
        _errorMessage = AppSettingsProvider.trGlobal(
          'الطرف الآخر غير متصل الآن.',
          'L\'autre participant est hors ligne.',
        );
      } else if (error is ApiException && error.code == "live-not-active") {
        _errorMessage = AppSettingsProvider.trGlobal(
          'المحادثة المباشرة غير مفعلة بعد.',
          'La conversation directe n\'est pas encore active.',
        );
      } else {
        _errorMessage = AppSettingsProvider.trGlobal(
          'تعذر إرسال تحديث مباشر.',
          'Impossible d\'envoyer la mise a jour en direct.',
        );
      }
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchLiveStatus(String roomId) async {
    try {
      return await _chatService.fetchLiveStatus(roomId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestLiveConversation(String roomId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _chatService.requestLiveSession(roomId);
      return true;
    } catch (error) {
      _mapLiveError(error);
      return false;
    }
  }

  Future<bool> acceptLiveConversation(String roomId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _chatService.acceptLiveSession(roomId);
      return true;
    } catch (error) {
      _mapLiveError(error);
      return false;
    }
  }

  Future<bool> rejectLiveConversation(String roomId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _chatService.rejectLiveSession(roomId);
      return true;
    } catch (error) {
      _mapLiveError(error);
      return false;
    }
  }

  Future<bool> stopLiveConversation(String roomId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _chatService.stopLiveSession(roomId);
      return true;
    } catch (error) {
      _mapLiveError(error);
      return false;
    }
  }

  Future<Map<String, dynamic>?> joinLiveSession(String roomId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      return await _chatService.joinLiveSession(roomId);
    } catch (error) {
      _mapLiveError(error);
      return null;
    }
  }

  void _mapLiveError(Object error) {
    if (error is ApiException && error.code == "live-peer-offline") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'الطرف الآخر غير متصل الآن.',
        'L\'autre participant est hors ligne.',
      );
    } else if (error is ApiException && error.code == "live-not-active") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'لا توجد مكالمة نشطة الآن.',
        'Aucun appel actif pour le moment.',
      );
    } else if (error is ApiException &&
        error.code == "live-no-pending-request") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'لا يوجد طلب محادثة مباشرة قيد الانتظار.',
        'Aucune demande de conversation directe en attente.',
      );
    } else if (error is ApiException &&
        error.code == "live-cannot-accept-own") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'لا يمكنك قبول طلبك أنت.',
        'Vous ne pouvez pas accepter votre propre demande.',
      );
    } else if (error is ApiException &&
        error.code == "live-request-pending-other") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'يوجد طلب قيد الانتظار من الطرف الآخر.',
        'Une demande en attente existe deja.',
      );
    } else if (error is ApiException &&
        error.code == "livekit-not-configured") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'خادم المكالمات غير مهيأ بعد.',
        'Le serveur d\'appels n\'est pas encore configure.',
      );
    } else if (error is ApiException && error.code == "livekit-token-failed") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر إنشاء تصريح المكالمة. حاول مرة أخرى.',
        'Impossible de generer l\'acces a l\'appel. Reessayez.',
      );
    } else {
      _errorMessage = AppSettingsProvider.trGlobal(
        'حدث خطأ في المحادثة المباشرة.',
        'Une erreur est survenue dans la conversation directe.',
      );
    }
    notifyListeners();
  }

  void _mapConsultationError(Object error) {
    if (error is ApiException && error.code == "consultation-request-pending") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'لديك طلب استشارة قيد الانتظار مع هذا الطبيب.',
        'Vous avez deja une demande en attente avec ce medecin.',
      );
    } else if (error is ApiException && error.code == "consultation-room-exists") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'توجد محادثة قائمة بالفعل مع هذا الطبيب.',
        'Une discussion existe deja avec ce medecin.',
      );
    } else if (error is ApiException && error.code == "doctor-not-found") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'الطبيب غير موجود.',
        'Medecin introuvable.',
      );
    } else if (error is ApiException && error.code == "consultation-request-not-pending") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'هذا الطلب لم يعد قيد الانتظار.',
        'Cette demande n\'est plus en attente.',
      );
    } else if (error is ApiException && error.code == "consultation-transfer-same-doctor") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'لا يمكن التحويل إلى نفس الطبيب.',
        'Impossible de transferer vers le meme medecin.',
      );
    } else {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر تنفيذ طلب الاستشارة. حاول مرة أخرى.',
        'Impossible de traiter la demande de consultation. Reessayez.',
      );
    }
    notifyListeners();
  }

  Future<void> startRecording() async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _voiceService.startRecording();
      _recordStartedAt = DateTime.now();
      _isRecording = true;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
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

      final url = await _chatService.uploadAudioFile(
        roomId: roomId,
        senderId: senderId,
        file: File(filePath),
      );

      await _chatService.sendAudioMessage(
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        audioUrl: url,
        durationSeconds: duration,
      );
    } catch (_) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر إرسال الرسالة الصوتية.',
        'Impossible d\'envoyer le message vocal.',
      );
    } finally {
      _isRecording = false;
      _isBusy = false;
      _recordStartedAt = null;
      notifyListeners();
    }
  }

  Future<void> playOrPauseAudio(String url) async {
    if (_activeAudioUrl == url && _audioPlayer.playing) {
      await _audioPlayer.pause();
      _activeAudioUrl = null;
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      if (_activeAudioUrl != url) {
        await _audioPlayer.setUrl(url);
      }
      await _audioPlayer.play();
      _activeAudioUrl = url;
    } catch (_) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر تشغيل الرسالة الصوتية.',
        'Impossible de lire le message vocal.',
      );
      _activeAudioUrl = null;
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
    _audioPlayer.dispose();
    _voiceService.dispose();
    super.dispose();
  }
}
