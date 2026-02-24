import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'app_settings_provider.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _initialize();
  }

  final AuthService _authService;

  bool _isLoading = true;
  String? _errorMessage;
  AppUser? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AppUser? get currentUser => _currentUser;

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.restoreSession();
    } catch (_) {
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String phoneNumber,
    required String password,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(
        phoneNumber: phoneNumber.trim(),
        password: password,
      );
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _errorMessage = _mapAuthError(error);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String name,
    required String phoneNumber,
    required String password,
    required UserRole role,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.signUp(
        name: name.trim(),
        phoneNumber: phoneNumber.trim(),
        password: password,
        role: role,
      );
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _errorMessage = _mapAuthError(error);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfilePhoto(File imageFile) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateProfilePhotoFromFile(imageFile);
      await _refreshCurrentUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _mapAuthError(error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDoctorProfile({
    required String specialty,
    required String hospitalName,
    required int experienceYears,
    required int studyYears,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateDoctorProfile(
        specialty: specialty,
        hospitalName: hospitalName,
        experienceYears: experienceYears,
        studyYears: studyYears,
      );
      await _refreshCurrentUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _mapAuthError(error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _mapAuthError(error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _refreshCurrentUser() async {
    _currentUser = await _authService.fetchCurrentUser();
  }

  String _mapAuthError(Object error) {
    String tr(String ar, String fr) => AppSettingsProvider.trGlobal(ar, fr);

    if (error is FormatException) {
      if (error.message == 'invalid-phone-number') {
        return tr('رقم الهاتف غير صحيح.', 'Numero de telephone invalide.');
      }
      if (error.message == 'invalid-photo-file') {
        return tr(
          'تعذر قراءة الصورة المختارة.',
          'Impossible de lire l\'image selectionnee.',
        );
      }
      if (error.message == 'doctor-profile-required-fields') {
        return tr(
          'أدخل التخصص واسم المستشفى.',
          'Renseignez la specialite et l\'hopital.',
        );
      }
      if (error.message == 'doctor-profile-invalid-years') {
        return tr(
          'تأكد من أن عدد السنوات صحيح.',
          'Verifiez que le nombre d\'annees est valide.',
        );
      }
    }

    if (error is ApiException) {
      switch (error.code) {
        case 'invalid-credential':
          return tr('بيانات الدخول غير صحيحة.', 'Identifiants invalides.');
        case 'phone-already-in-use':
          return tr('هذا الرقم مستخدم من قبل.', 'Ce numero est deja utilise.');
        case 'wrong-password':
          return tr(
            'كلمة المرور الحالية غير صحيحة.',
            'Mot de passe actuel incorrect.',
          );
        case 'weak-password':
          return tr(
            'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.',
            'Mot de passe faible, utilisez au moins 6 caracteres.',
          );
        case 'account-disabled':
          return tr(
            'تم تعطيل هذا الحساب من الإدارة.',
            'Ce compte a ete desactive par l\'administration.',
          );
        case 'network-error':
          return tr(
            'تعذر الاتصال بالخادم المحلي. تأكد أن Backend يعمل.',
            'Connexion au serveur impossible. Verifiez que le backend fonctionne.',
          );
        case 'request-timeout':
          return tr(
            'انتهت مهلة الطلب. أعد المحاولة.',
            'Le delai de la requete a expire. Reessayez.',
          );
        default:
          return error.message;
      }
    }

    if (error is SocketException) {
      return tr(
        'لا يمكن الوصول إلى الخادم. تحقق من عنوان API.',
        'Impossible de joindre le serveur. Verifiez l\'adresse API.',
      );
    }

    if (error is StateError) {
      return error.message;
    }

    return tr(
      'تعذر تنفيذ الطلب، حاول مرة أخرى.',
      'Operation impossible, reessayez.',
    );
  }
}
