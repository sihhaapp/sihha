import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'api_service.dart';

class AuthService {
  AuthService(this._apiService);

  static const String _countryCode = '235';
  static const String _adminLocalPhone = '00000000';
  static const String _tokenPrefKey = 'api_auth_token';

  final ApiService _apiService;

  Future<AppUser?> restoreSession() async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on MissingPluginException {
      _apiService.setAuthToken(null);
      return null;
    }
    final token = prefs.getString(_tokenPrefKey)?.trim();
    if (token == null || token.isEmpty) {
      _apiService.setAuthToken(null);
      return null;
    }

    _apiService.setAuthToken(token);
    try {
      return await fetchCurrentUser();
    } catch (_) {
      await _clearSession();
      return null;
    }
  }

  Future<AppUser> signIn({
    required String phoneNumber,
    required String password,
  }) async {
    final body = await _apiService.post(
      '/auth/signin',
      body: {'phoneNumber': _toDisplayPhone(phoneNumber), 'password': password},
    );
    return _consumeAuthResponse(body);
  }

  Future<AppUser> signUp({
    required String name,
    required String phoneNumber,
    required String password,
    required UserRole role,
  }) async {
    final body = await _apiService.post(
      '/auth/signup',
      body: {
        'name': name.trim(),
        'phoneNumber': _toDisplayPhone(phoneNumber),
        'password': password,
        'role': role.value,
      },
    );
    return _consumeAuthResponse(body);
  }

  Future<AppUser> fetchCurrentUser() async {
    final body = await _apiService.get('/auth/me');
    final map = _readMap(body);
    final userMap = _readMap(map['user']);
    return AppUser.fromMap((userMap['id'] as String?) ?? '', userMap);
  }

  Future<void> updateProfilePhotoFromFile(File imageFile) async {
    if (!await imageFile.exists()) {
      throw const FormatException('invalid-photo-file');
    }
    await _apiService.postMultipart(
      path: '/users/me/photo',
      fileField: 'photo',
      filePath: imageFile.path,
    );
  }

  Future<void> updateDoctorProfile({
    required String specialty,
    required String hospitalName,
    required int experienceYears,
    required int studyYears,
  }) async {
    await _apiService.put(
      '/users/me/doctor-profile',
      body: {
        'specialty': specialty.trim(),
        'hospitalName': hospitalName.trim(),
        'experienceYears': experienceYears,
        'studyYears': studyYears,
      },
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiService.post(
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> signOut() async {
    try {
      await _apiService.post('/auth/logout');
    } catch (_) {
      // Ignore network errors on logout and clear local session anyway.
    }
    await _clearSession();
  }

  Future<AppUser> _consumeAuthResponse(dynamic body) async {
    final map = _readMap(body);
    final token = (map['token'] as String?)?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'invalid-session',
        message: 'Backend did not return a valid token.',
      );
    }

    final userMap = _readMap(map['user']);
    final user = AppUser.fromMap((userMap['id'] as String?) ?? '', userMap);

    await _saveToken(token);
    _apiService.setAuthToken(token);
    return user;
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

  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenPrefKey, token);
    } on MissingPluginException {
      // Keep in-memory token only for current session.
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenPrefKey);
    } on MissingPluginException {
      // Ignore preference clearing in headless/background engines.
    }
    _apiService.setAuthToken(null);
  }

  String _toDisplayPhone(String phoneNumber) {
    final localDigits = _normalizeLocalPhoneDigits(phoneNumber);
    return '+$_countryCode$localDigits';
  }

  String _normalizeLocalPhoneDigits(String phoneNumber) {
    var digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith(_countryCode)) {
      digits = digits.substring(_countryCode.length);
    }
    if (digits == _adminLocalPhone) {
      return digits;
    }
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) {
      throw const FormatException('invalid-phone-number');
    }
    return digits;
  }
}
