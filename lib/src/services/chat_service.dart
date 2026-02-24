import 'dart:async';
import 'dart:io';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/consultation_request.dart';
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
    final map = _readMap(body);
    final roomMap = _readMap(map['room']);
    return ChatRoom.fromMap((roomMap['id'] as String?) ?? '', roomMap);
  }

  Future<ChatRoom?> findRoomWithDoctor(String doctorId) async {
    final body = await _apiService.get('/rooms/with-doctor/$doctorId');
    final map = _readMap(body);
    final rawRoom = map['room'];
    if (rawRoom == null) return null;
    final roomMap = _readMap(rawRoom);
    final roomId = (roomMap['id'] as String?)?.trim() ?? '';
    if (roomId.isEmpty) return null;
    return ChatRoom.fromMap(roomId, roomMap);
  }

  Future<ChatRoom?> getRoomById(String roomId) async {
    final body = await _apiService.get('/rooms/$roomId');
    final map = _readMap(body);
    final rawRoom = map['room'];
    if (rawRoom == null) return null;
    final roomMap = _readMap(rawRoom);
    final resolvedId = (roomMap['id'] as String?)?.trim() ?? roomId;
    return ChatRoom.fromMap(resolvedId, roomMap);
  }

  Future<ConsultationRequest> submitConsultationRequest({
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
    final body = await _apiService.post(
      '/consultation-requests',
      body: {
        'doctorId': doctorId,
        'subjectType': subjectType.value,
        'subjectName': subjectName.trim(),
        'ageYears': ageYears,
        'gender': gender.value,
        'weightKg': weightKg,
        'stateCode': stateCode,
        'spokenLanguage': spokenLanguage.value,
        'symptoms': symptoms.trim(),
      },
    );
    final map = _readMap(body);
    final requestMap = _readMap(map['request']);
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

  Future<Map<String, dynamic>> acceptConsultationRequest(String requestId) async {
    final body = await _apiService.post('/consultation-requests/$requestId/accept');
    final map = _readMap(body);
    return map;
  }

  Future<ConsultationRequest> rejectConsultationRequest(String requestId) async {
    final body = await _apiService.post('/consultation-requests/$requestId/reject');
    final map = _readMap(body);
    final requestMap = _readMap(map['request']);
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
    final map = _readMap(body);
    final requestMap = _readMap(map['request']);
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

  Future<String> uploadAudioFile({
    required String roomId,
    required String senderId,
    required File file,
  }) async {
    final body = await _apiService.postMultipart(
      path: '/uploads/audio',
      fileField: 'audio',
      filePath: file.path,
    );
    final map = _readMap(body);
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
    final map = _readMap(body);
    final imageUrl = (map['imageUrl'] as String?)?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const ApiException(
        code: 'invalid-response',
        message: 'Backend did not return a valid image URL.',
      );
    }
    return imageUrl;
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
    final map = _readMap(body);
    return _readMap(map['session']);
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
    return _readMap(body);
  }

  Future<List<AppUser>> _fetchDoctors() async {
    final body = await _apiService.get('/doctors');
    final map = _readMap(body);
    final list = _readList(map['doctors']);
    return list
        .map((raw) => _readMap(raw))
        .map((raw) => AppUser.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Future<List<ChatRoom>> _fetchRooms() async {
    final body = await _apiService.get('/rooms');
    final map = _readMap(body);
    final list = _readList(map['rooms']);
    return list
        .map((raw) => _readMap(raw))
        .map((raw) => ChatRoom.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Future<List<ConsultationRequest>> _fetchMyConsultationRequests() async {
    final body = await _apiService.get('/consultation-requests/mine');
    final map = _readMap(body);
    final list = _readList(map['requests']);
    return list
        .map((raw) => _readMap(raw))
        .map(ConsultationRequest.fromMap)
        .toList();
  }

  Future<List<ConsultationRequest>> _fetchDoctorConsultationInbox() async {
    final body = await _apiService.get('/consultation-requests/inbox');
    final map = _readMap(body);
    final list = _readList(map['requests']);
    return list
        .map((raw) => _readMap(raw))
        .map(ConsultationRequest.fromMap)
        .toList();
  }

  Future<List<ChatMessage>> _fetchMessages(String roomId) async {
    final body = await _apiService.get('/rooms/$roomId/messages');
    final map = _readMap(body);
    final list = _readList(map['messages']);
    return list
        .map((raw) => _readMap(raw))
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

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw const ApiException(
      code: 'invalid-response',
      message: 'Unexpected response from backend.',
    );
  }

  List<dynamic> _readList(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    throw const ApiException(
      code: 'invalid-response',
      message: 'Unexpected list payload from backend.',
    );
  }
}
