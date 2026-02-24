import 'package:flutter/foundation.dart';

import '../models/admin_dashboard.dart';
import '../models/app_user.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import 'app_settings_provider.dart';

class AdminProvider extends ChangeNotifier {
  AdminProvider(this._adminService);

  final AdminService _adminService;

  bool _isLoading = false;
  bool _isDashboardLoading = false;
  String? _errorMessage;
  List<AppUser> _users = const <AppUser>[];
  AdminDashboardData? _dashboard;

  bool get isLoading => _isLoading;
  bool get isDashboardLoading => _isDashboardLoading;
  String? get errorMessage => _errorMessage;
  List<AppUser> get users => _users;
  AdminDashboardData? get dashboard => _dashboard;

  int get totalUsers =>
      _dashboard?.summary.totalUsers ?? _users.where((u) => !u.isAdmin).length;
  int get doctorsCount =>
      _dashboard?.summary.doctorsCount ??
      _users.where((u) => u.role == UserRole.doctor && !u.isAdmin).length;
  int get patientsCount =>
      _dashboard?.summary.patientsCount ??
      _users.where((u) => u.role == UserRole.patient && !u.isAdmin).length;
  int get disabledUsersCount =>
      _dashboard?.summary.disabledUsersCount ??
      _users.where((u) => !u.isAdmin && u.isDisabled).length;

  AdminVisitorsStats get visitorsStats =>
      _dashboard?.visitors ??
      const AdminVisitorsStats(today: 0, month: 0, year: 0, currentOnline: 0);
  List<AdminDoctorKpi> get doctorStats => _dashboard?.doctors ?? const [];
  List<AdminCurrentVisitor> get currentVisitors =>
      _dashboard?.currentVisitors ?? const [];

  Future<void> refreshUsers({bool clearError = true}) async {
    if (clearError) {
      _errorMessage = null;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _users = await _adminService.fetchUsers();
    } catch (error) {
      _errorMessage = _mapError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDashboard({
    bool silent = false,
    bool clearError = true,
  }) async {
    if (clearError) {
      _errorMessage = null;
    }
    _isDashboardLoading = true;
    if (!silent) {
      notifyListeners();
    }
    try {
      _dashboard = await _adminService.fetchDashboard();
    } catch (error) {
      _errorMessage = _mapError(error);
    } finally {
      _isDashboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshUsers(clearError: true),
      refreshDashboard(silent: true, clearError: false),
    ]);
  }

  Future<bool> createUser({
    required String name,
    required String phoneNumber,
    required String password,
    required UserRole role,
    String specialty = '',
    String hospitalName = '',
    int experienceYears = 0,
    int studyYears = 0,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.createUser(
        name: name,
        phoneNumber: phoneNumber,
        password: password,
        role: role,
        specialty: specialty,
        hospitalName: hospitalName,
        experienceYears: experienceYears,
        studyYears: studyYears,
      );
      _users = await _adminService.fetchUsers();
      _dashboard = await _adminService.fetchDashboard();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _mapError(error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setUserDisabled({
    required String userId,
    required bool disabled,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final updated = await _adminService.setUserDisabled(
        userId: userId,
        disabled: disabled,
      );
      _users = _users
          .map((u) => u.id == updated.id ? updated : u)
          .toList(growable: false);
      _dashboard = await _adminService.fetchDashboard();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _mapError(error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _adminService.resetUserPassword(
        userId: userId,
        newPassword: newPassword,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _mapError(error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapError(Object error) {
    String tr(String ar, String fr) => AppSettingsProvider.trGlobal(ar, fr);

    if (error is FormatException) {
      if (error.message == 'invalid-phone-number') {
        return tr('رقم الهاتف غير صحيح.', 'Numero de telephone invalide.');
      }
    }
    if (error is ApiException) {
      switch (error.code) {
        case 'forbidden':
          return tr(
            'ليس لديك صلاحية الإدارة.',
            'Vous n\'avez pas les droits admin.',
          );
        case 'reserved-phone':
          return tr(
            'هذا الرقم محجوز للحساب الإداري.',
            'Ce numero est reserve au compte admin.',
          );
        case 'phone-already-in-use':
          return tr('هذا الرقم مستخدم من قبل.', 'Ce numero est deja utilise.');
        case 'invalid-name':
          return tr('الاسم قصير جدا.', 'Le nom est trop court.');
        case 'weak-password':
          return tr(
            'كلمة المرور قصيرة جدا.',
            'Le mot de passe est trop court.',
          );
        case 'account-disabled':
          return tr('هذا الحساب معطل حاليا.', 'Ce compte est desactive.');
        case 'cannot-disable-admin':
          return tr(
            'لا يمكن تعطيل حساب الأدمن.',
            'Le compte admin ne peut pas etre desactive.',
          );
        case 'cannot-disable-self':
          return tr(
            'لا يمكنك تعطيل حسابك الحالي.',
            'Vous ne pouvez pas desactiver votre propre compte.',
          );
        case 'user-not-found':
          return tr('المستخدم غير موجود.', 'Utilisateur introuvable.');
        default:
          return error.message;
      }
    }
    return tr('تعذر تنفيذ العملية.', 'Operation impossible.');
  }
}
