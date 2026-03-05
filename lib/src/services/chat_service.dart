import 'dart:async';
import 'dart:io';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/consultation_request.dart';
import '../models/medical_record.dart';
import '../utils/api_response_helpers.dart';
import 'api_service.dart';

class ChatService {
  ChatService(this._apiService);

  final ApiService _apiService;

  Stream<List<AppUser>> doctorsStream() {
    return _poll<List<AppUser>>(
      _fetchDoctors,
      interval: const Duration(seconds: 5),
    );
  }

  Stream<List<ChatRoom>> chatRoomsForUser({
    required String userId,
    required UserRole role,
    Duration interval = const Duration(seconds: 3),
  }) {
    return _poll<List<ChatRoom>>(_fetchRooms, interval: interval);
  }

  Stream<List<ChatMessage>> messagesForRoom(
    String roomId, {
    Duration interval = const Duration(seconds: 2),
  }) {
    return _poll<List<ChatMessage>>(
      () => _fetchMessages(roomId),
      interval: interval,
    );
  }

  Future<ChatRoom> createOrGetRoom({
    required AppUser patient,
    required AppUser doctor,
  }) async {
    final body = await _apiService.post(
      '/rooms/create-or-get',
      body: {'doctorId': doctor.id},
    );
    final map = readMap(body);
    final roomMap = readMap(map['room']);
    return ChatRoom.fromMap((roomMap['id'] as String?) ?? '', roomMap);
  }

  Future<ChatRoom?> findRoomWithDoctor(String doctorId) async {
    final body = await _apiService.get('/rooms/with-doctor/$doctorId');
    final map = readMap(body);
    final rawRoom = map['room'];
    if (rawRoom == null) return null;
    final roomMap = readMap(rawRoom);
    final roomId = (roomMap['id'] as String?)?.trim() ?? '';
    if (roomId.isEmpty) return null;
    return ChatRoom.fromMap(roomId, roomMap);
  }

  Future<ChatRoom?> getRoomById(String roomId) async {
    final body = await _apiService.get('/rooms/$roomId');
    final map = readMap(body);
    final rawRoom = map['room'];
    if (rawRoom == null) return null;
    final roomMap = readMap(rawRoom);
    final resolvedId = (roomMap['id'] as String?)?.trim() ?? roomId;
    return ChatRoom.fromMap(resolvedId, roomMap);
  }

  Future<ConsultationRequest> submitConsultationRequest({
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
    final body = await _apiService.post(
      '/consultation-requests',
      body: {
        'doctorId': doctorId,
        'subjectType': subjectType.value,
        'subjectName': subjectName.trim(),
        'ageYears': ageYears,
        'gender': gender.value,
        'pregnancyStatus': pregnancyStatus.value,
        'weightKg': weightKg,
        'stateCode': stateCode,
        'spokenLanguage': spokenLanguage.value,
        'symptoms': symptoms.trim(),
        'symptomsVoiceUrl': symptomsVoiceUrl.trim(),
      },
    );
    final map = readMap(body);
    final requestMap = readMap(map['request']);
    return ConsultationRequest.fromMap(requestMap);
  }

  Stream<List<ConsultationRequest>> myConsultationRequestsStream({
    Duration interval = const Duration(seconds: 3),
  }) {
    return _poll<List<ConsultationRequest>>(
      _fetchMyConsultationRequests,
      interval: interval,
    );
  }

  Stream<List<ConsultationRequest>> doctorConsultationInboxStream({
    Duration interval = const Duration(seconds: 3),
  }) {
    return _poll<List<ConsultationRequest>>(
      _fetchDoctorConsultationInbox,
      interval: interval,
    );
  }

  Future<ConsultationRequest?> fetchConsultationRequestByRoom(
    String roomId,
  ) async {
    final body = await _apiService.get('/rooms/$roomId/consultation-request');
    final map = readMap(body);
    final reqRaw = map['request'];
    if (reqRaw == null) return null;
    return ConsultationRequest.fromMap(readMap(reqRaw));
  }

  Future<ConsultationRequest?> updateConsultationRequest({
    required String requestId,
    required Map<String, dynamic> payload,
  }) async {
    final body = await _apiService.put(
      '/consultation-requests/$requestId',
      body: payload,
    );
    final map = readMap(body);
    final reqRaw = map['request'];
    if (reqRaw == null) return null;
    return ConsultationRequest.fromMap(readMap(reqRaw));
  }

  Future<MedicalRecord?> fetchMedicalRecordByRoom(String roomId) async {
    final body = await _apiService.get('/rooms/$roomId/medical-record');
    final map = readMap(body);
    final rawRecord = map['record'];
    if (rawRecord == null) {
      return null;
    }
    return MedicalRecord.fromMap(readMap(rawRecord));
  }

  Future<MedicalRecord?> updateMedicalRecordByRoom({
    required String roomId,
    required Map<String, dynamic> payload,
  }) async {
    final body = await _apiService.put(
      '/rooms/$roomId/medical-record',
      body: payload,
    );
    final map = readMap(body);
    final rawRecord = map['record'];
    if (rawRecord == null) {
      return null;
    }
    return MedicalRecord.fromMap(readMap(rawRecord));
  }

  Future<ChatRoom> closeRoom(String roomId) async {
    final body = await _apiService.post('/rooms/$roomId/close');
    final map = readMap(body);
    final roomMap = readMap(map['room']);
    return ChatRoom.fromMap((roomMap['id'] as String?) ?? roomId, roomMap);
  }

  Future<Map<String, dynamic>> acceptConsultationRequest(
    String requestId,
  ) async {
    final body = await _apiService.post(
      '/consultation-requests/$requestId/accept',
    );
    final map = readMap(body);
    return map;
  }

  Future<ConsultationRequest> rejectConsultationRequest(
    String requestId,
  ) async {
    final body = await _apiService.post(
      '/consultation-requests/$requestId/reject',
    );
    final map = readMap(body);
    final requestMap = readMap(map['request']);
    return ConsultationRequest.fromMap(requestMap);
  }

  Future<ConsultationRequest> transferConsultationRequest({
    required String requestId,
    required String doctorId,
  }) async {
    final body = await _apiService.post(
      '/consultation-requests/$requestId/transfer',
      body: {'doctorId': doctorId},
    );
    final map = readMap(body);
    final requestMap = readMap(map['request']);
    return ConsultationRequest.fromMap(requestMap);
  }

  Future<void> sendTextMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final sanitized = text.trim();
    if (sanitized.isEmpty) {
      return;
    }
    await _apiService.post(
      '/rooms/$roomId/messages/text',
      body: {'text': sanitized},
    );
  }

  Future<String> uploadAudioFile({required File file}) async {
    final body = await _apiService.postMultipart(
      path: '/uploads/audio',
      fileField: 'audio',
      filePath: file.path,
    );
    final map = readMap(body);
    final audioUrl = (map['audioUrl'] as String?)?.trim();
    if (audioUrl == null || audioUrl.isEmpty) {
      throw const ApiException(
        code: 'invalid-response',
        message: 'Backend did not return a valid audio URL.',
      );
    }
    return audioUrl;
  }

  Future<String> uploadImageFile({required File file}) async {
    final body = await _apiService.postMultipart(
      path: '/uploads/image',
      fileField: 'image',
      filePath: file.path,
    );
    final map = readMap(body);
    final imageUrl = (map['imageUrl'] as String?)?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const ApiException(
        code: 'invalid-response',
        message: 'Backend did not return a valid image URL.',
      );
    }
    return imageUrl;
  }

  Future<String> uploadPrescriptionPdf({required File file}) async {
    final body = await _apiService.postMultipart(
      path: '/uploads/prescription-pdf',
      fileField: 'pdf',
      filePath: file.path,
    );
    final map = readMap(body);
    final pdfUrl = (map['pdfUrl'] as String?)?.trim();
    if (pdfUrl == null || pdfUrl.isEmpty) {
      throw const ApiException(
        code: 'invalid-response',
        message: 'Backend did not return a valid PDF URL.',
      );
    }
    return pdfUrl;
  }

  Future<void> sendAudioMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String audioUrl,
    required int durationSeconds,
  }) async {
    await _apiService.post(
      '/rooms/$roomId/messages/audio',
      body: {'audioUrl': audioUrl, 'durationSeconds': durationSeconds},
    );
  }

  Future<void> sendImageMessage({
    required String roomId,
    required String imageUrl,
  }) async {
    await _apiService.post(
      '/rooms/$roomId/messages/image',
      body: {'imageUrl': imageUrl},
    );
  }

  Future<void> sendLiveMessage({
    required String roomId,
    required String content,
  }) async {
    final sanitized = content.trim();
    if (sanitized.isEmpty) {
      return;
    }
    await _apiService.post(
      '/rooms/$roomId/messages/live',
      body: {'content': sanitized},
    );
  }

  Future<void> setPresence({
    required String roomId,
    required bool active,
  }) async {
    await _apiService.post('/rooms/$roomId/presence', body: {'active': active});
  }

  Future<Map<String, dynamic>> fetchLiveStatus(String roomId) async {
    final body = await _apiService.get('/rooms/$roomId/live/status');
    final map = readMap(body);
    return readMap(map['session']);
  }

  Future<void> requestLiveSession(String roomId) async {
    await _apiService.post('/rooms/$roomId/live/request');
  }

  Future<void> acceptLiveSession(String roomId) async {
    await _apiService.post('/rooms/$roomId/live/accept');
  }

  Future<void> rejectLiveSession(String roomId) async {
    await _apiService.post('/rooms/$roomId/live/reject');
  }

  Future<void> startLiveSession(String roomId) async {
    await _apiService.post('/rooms/$roomId/live/start');
  }

  Future<void> stopLiveSession(String roomId) async {
    await _apiService.post('/rooms/$roomId/live/stop');
  }

  Future<Map<String, dynamic>> joinLiveSession(String roomId) async {
    final body = await _apiService.post('/rooms/$roomId/live/join');
    return readMap(body);
  }

  Future<List<AppUser>> _fetchDoctors() async {
    final body = await _apiService.get('/doctors');
    final map = readMap(body);
    final list = readList(map['doctors']);
    return list
        .map((raw) => readMap(raw))
        .map((raw) => AppUser.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Future<List<ChatRoom>> _fetchRooms() async {
    final body = await _apiService.get('/rooms');
    final map = readMap(body);
    final list = readList(map['rooms']);
    return list
        .map((raw) => readMap(raw))
        .map((raw) => ChatRoom.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Future<List<ConsultationRequest>> _fetchMyConsultationRequests() async {
    final body = await _apiService.get('/consultation-requests/mine');
    final map = readMap(body);
    final list = readList(map['requests']);
    return list
        .map((raw) => readMap(raw))
        .map(ConsultationRequest.fromMap)
        .toList();
  }

  Future<List<ConsultationRequest>> _fetchDoctorConsultationInbox() async {
    final body = await _apiService.get('/consultation-requests/inbox');
    final map = readMap(body);
    final list = readList(map['requests']);
    return list
        .map((raw) => readMap(raw))
        .map(ConsultationRequest.fromMap)
        .toList();
  }

  Future<List<ChatMessage>> _fetchMessages(String roomId) async {
    final body = await _apiService.get('/rooms/$roomId/messages');
    final map = readMap(body);
    final list = readList(map['messages']);
    return list
        .map((raw) => readMap(raw))
        .map((raw) => ChatMessage.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Stream<T> _poll<T>(
    Future<T> Function() fetch, {
    Duration interval = const Duration(seconds: 4),
  }) async* {
    yield await fetch();
    yield* Stream.periodic(interval).asyncMap((_) => fetch());
  }
}
