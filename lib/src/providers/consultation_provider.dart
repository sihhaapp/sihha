import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/chat_room.dart';
import '../models/consultation_request.dart';
import '../models/medical_record.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import 'app_settings_provider.dart';

class ConsultationProvider extends ChangeNotifier {
  ConsultationProvider(this._chatService);

  final ChatService _chatService;

  bool _isBusy = false;
  String? _errorMessage;
  final Map<String, ConsultationRequest> _consultationsByRoom =
      <String, ConsultationRequest>{};
  final Map<String, MedicalRecord> _medicalRecordsByRoom =
      <String, MedicalRecord>{};

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage == null
      ? null
      : AppSettingsProvider.normalizeText(_errorMessage!);

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

  void clearError() {
    _errorMessage = null;
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
}
