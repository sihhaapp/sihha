import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import 'app_settings_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._chatService);

  final ChatService _chatService;

  bool _isBusy = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage == null
      ? null
      : AppSettingsProvider.normalizeText(_errorMessage!);

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
