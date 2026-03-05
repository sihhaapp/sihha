import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/consultation_request.dart';
import '../models/medical_record.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/voice_service.dart';
import 'app_settings_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._chatService, this._voiceService) {
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
  final Map<String, ConsultationRequest> _consultationsByRoom =
      <String, ConsultationRequest>{};
  final Map<String, MedicalRecord> _medicalRecordsByRoom =
      <String, MedicalRecord>{};

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

  ConsultationRequest? getCachedConsultation(String roomId) =>
      _consultationsByRoom[roomId];
  MedicalRecord? getCachedMedicalRecord(String roomId) =>
      _medicalRecordsByRoom[roomId];

  void _cacheConsultation(String? roomId, ConsultationRequest request) {
    final key = (roomId ?? request.linkedRoomId)?.trim();
    if (key == null || key.isEmpty) {
      return;
    }
    _consultationsByRoom[key] = request;
  }

  void rememberConsultation(String roomId, ConsultationRequest request) {
    _cacheConsultation(roomId, request);
  }

  void _cacheMedicalRecord(String roomId, MedicalRecord record) {
    if (roomId.trim().isEmpty) return;
    _medicalRecordsByRoom[roomId] = record;
  }

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
  }) async* {
    final upstream = _chatService.messagesForRoom(
      roomId,
      interval: liveMode
          ? const Duration(milliseconds: 1200)
          : const Duration(seconds: 2),
    );

    List<ChatMessage>? previous;
    await for (final current in upstream) {
      final previousSnapshot = previous;
      if (previousSnapshot != null &&
          _sameMessageList(previousSnapshot, current)) {
        continue;
      }
      previous = List<ChatMessage>.unmodifiable(current);
      yield current;
    }
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
    required RequestPregnancyStatus pregnancyStatus,
    required double weightKg,
    required String stateCode,
    required SpokenLanguage spokenLanguage,
    required String symptoms,
    required String symptomsVoiceUrl,
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
        pregnancyStatus: pregnancyStatus,
        weightKg: weightKg,
        stateCode: stateCode,
        spokenLanguage: spokenLanguage,
        symptoms: symptoms,
        symptomsVoiceUrl: symptomsVoiceUrl,
      );
    } catch (error) {
      _mapConsultationError(error);
      return null;
    }
  }

  Future<Map<String, dynamic>?> acceptConsultationRequest(
    String requestId,
  ) async {
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
      _cacheConsultation(room.id, request);
      return {'request': request, 'room': room};
    } catch (error) {
      _mapConsultationError(error);
      return null;
    }
  }

  Future<ConsultationRequest?> rejectConsultationRequest(
    String requestId,
  ) async {
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
      final updated = await _chatService.transferConsultationRequest(
        requestId: requestId,
        doctorId: doctorId,
      );
      _cacheConsultation(updated.linkedRoomId, updated);
      return updated;
    } catch (error) {
      _mapConsultationError(error);
      return null;
    }
  }

  Future<ConsultationRequest?> fetchConsultationRequestByRoom(
    String roomId,
  ) async {
    try {
      final req = await _chatService.fetchConsultationRequestByRoom(roomId);
      if (req != null) {
        _cacheConsultation(roomId, req);
      }
      return req ?? getCachedConsultation(roomId);
    } catch (error) {
      return getCachedConsultation(roomId);
    }
  }

  Future<ConsultationRequest?> updateConsultationRequest({
    required String requestId,
    required Map<String, dynamic> payload,
  }) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await _chatService.updateConsultationRequest(
        requestId: requestId,
        payload: payload,
      );
      if (updated != null) {
        _cacheConsultation(updated.linkedRoomId, updated);
      }
      return updated;
    } catch (error) {
      _mapConsultationError(error);
      return null;
    }
  }

  Future<MedicalRecord?> fetchMedicalRecordByRoom(String roomId) async {
    try {
      final record = await _chatService.fetchMedicalRecordByRoom(roomId);
      if (record != null) {
        _cacheMedicalRecord(roomId, record);
      }
      return record ?? getCachedMedicalRecord(roomId);
    } catch (_) {
      return getCachedMedicalRecord(roomId);
    }
  }

  Future<MedicalRecord?> updateMedicalRecordByRoom({
    required String roomId,
    required Map<String, dynamic> payload,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      final updated = await _chatService.updateMedicalRecordByRoom(
        roomId: roomId,
        payload: payload,
      );
      if (updated != null) {
        _cacheMedicalRecord(roomId, updated);
      }
      return updated;
    } catch (error) {
      _mapMedicalRecordError(error);
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> uploadPrescriptionPdf(File file) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      return await _chatService.uploadPrescriptionPdf(file: file);
    } catch (error) {
      _mapMedicalRecordError(error);
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> sendTextMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      await _chatService.sendTextMessage(
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        text: text,
      );
    } catch (error) {
      _mapRoomError(error);
    }
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
    } catch (error) {
      _mapRoomError(error);
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

  void _mapRoomError(Object error) {
    if (error is ApiException && error.code == "room-closed") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تم إغلاق هذه الاستشارة. أرسل طلباً جديداً للطبيب.',
        'Cette consultation est cloturee. Envoyez une nouvelle demande au medecin.',
      );
    } else {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر إرسال الرسالة.',
        "Impossible d'envoyer le message.",
      );
    }
    notifyListeners();
  }

  void _mapMedicalRecordError(Object error) {
    if (error is ApiException &&
        error.code == 'prescription-pdf-invalid-type') {
      _errorMessage = AppSettingsProvider.trGlobal(
        'يجب رفع ملف PDF فقط.',
        'Veuillez choisir uniquement un fichier PDF.',
      );
    } else if (error is ApiException &&
        error.code == 'prescription-pdf-too-large') {
      _errorMessage = AppSettingsProvider.trGlobal(
        'حجم ملف الوصفة أكبر من الحد المسموح (10MB).',
        'Le fichier PDF depasse la taille maximale (10MB).',
      );
    } else if (error is ApiException &&
        error.code == 'medical-record-invalid-field') {
      _errorMessage = AppSettingsProvider.trGlobal(
        'إحدى خانات السجل الطبي طويلة جدًا.',
        'Un champ du dossier medical est trop long.',
      );
    } else if (error is ApiException &&
        error.code == 'medical-record-invalid-pdf-url') {
      _errorMessage = AppSettingsProvider.trGlobal(
        'رابط الوصفة الطبية غير صالح.',
        'L URL de l ordonnance est invalide.',
      );
    } else if (error is ApiException &&
        error.code == 'medical-record-empty-update') {
      _errorMessage = AppSettingsProvider.trGlobal(
        'لا توجد بيانات جديدة لحفظها.',
        'Aucune nouvelle donnee a enregistrer.',
      );
    } else {
      _errorMessage = AppSettingsProvider.trGlobal(
        'تعذر تحديث السجل الطبي.',
        'Impossible de mettre a jour le dossier medical.',
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
    } else if (error is ApiException &&
        error.code == "consultation-request-exists") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'هناك استشارة قائمة أو مقبولة مع هذا الطبيب.',
        'Une consultation existe deja avec ce medecin.',
      );
    } else if (error is ApiException &&
        error.code == "consultation-room-exists") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'توجد محادثة قائمة بالفعل مع هذا الطبيب.',
        'Une discussion existe deja avec ce medecin.',
      );
    } else if (error is ApiException && error.code == "doctor-not-found") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'الطبيب غير موجود.',
        'Medecin introuvable.',
      );
    } else if (error is ApiException &&
        error.code == "consultation-request-not-pending") {
      _errorMessage = AppSettingsProvider.trGlobal(
        'هذا الطلب لم يعد قيد الانتظار.',
        'Cette demande n\'est plus en attente.',
      );
    } else if (error is ApiException &&
        error.code == "consultation-transfer-same-doctor") {
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
      _mapRoomError(error);
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

  Future<bool> closeRoom(String roomId) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      await _chatService.closeRoom(roomId);
      _isBusy = false;
      notifyListeners();
      return true;
    } catch (error) {
      _mapRoomError(error);
      _isBusy = false;
      notifyListeners();
      return false;
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

  bool _sameMessageList(List<ChatMessage> a, List<ChatMessage> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.roomId != right.roomId ||
          left.senderId != right.senderId ||
          left.type != right.type ||
          left.content != right.content ||
          left.durationSeconds != right.durationSeconds ||
          left.sentAt != right.sentAt ||
          left.deliveredAt != right.deliveredAt ||
          left.readAt != right.readAt) {
        return false;
      }
    }
    return true;
  }
}
