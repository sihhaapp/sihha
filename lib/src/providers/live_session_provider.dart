import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/chat_service.dart';
import 'app_settings_provider.dart';

class LiveSessionProvider extends ChangeNotifier {
  LiveSessionProvider(this._chatService);

  final ChatService _chatService;

  String? _errorMessage;

  String? get errorMessage => _errorMessage == null
      ? null
      : AppSettingsProvider.normalizeText(_errorMessage!);

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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
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
}
