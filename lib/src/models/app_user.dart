import '../utils/text_normalizer.dart';
import '../utils/media_url_normalizer.dart';

enum UserRole {
  patient,
  doctor;

  static UserRole fromValue(String? value) {
    if (value == 'doctor') {
      return UserRole.doctor;
    }
    return UserRole.patient;
  }

  String get value => this == UserRole.doctor ? 'doctor' : 'patient';

  String label({required bool isArabic}) {
    if (this == UserRole.doctor) {
      return isArabic ? '\u0637\u0628\u064a\u0628' : 'Medecin';
    }
    return isArabic ? '\u0645\u0631\u064a\u0636' : 'Patient';
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.role,
    required this.createdAt,
    required this.photoUrl,
    this.isAdmin = false,
    this.isDisabled = false,
    this.specialty = '',
    this.hospitalName = '',
    this.experienceYears = 0,
    this.studyYears = 0,
    this.disabledAt,
    this.lastSeenAt,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final UserRole role;
  final DateTime createdAt;
  final String photoUrl;
  final bool isAdmin;
  final bool isDisabled;
  final String specialty;
  final String hospitalName;
  final int experienceYears;
  final int studyYears;
  final DateTime? disabledAt;
  final DateTime? lastSeenAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'role': role.value,
      'createdAt': createdAt.toIso8601String(),
      'photoUrl': photoUrl,
      'isAdmin': isAdmin,
      'isDisabled': isDisabled,
      'specialty': specialty,
      'hospitalName': hospitalName,
      'experienceYears': experienceYears,
      'studyYears': studyYears,
      'disabledAt': disabledAt?.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? normalizePossiblyMojibake((map['name'] as String).trim())
          : 'User',
      phoneNumber: _readPhoneNumber(map),
      role: UserRole.fromValue(map['role'] as String?),
      createdAt: _parseDate(map['createdAt']),
      photoUrl: _normalizePhotoUrl(map['photoUrl']),
      isAdmin: _readBool(map['isAdmin']),
      isDisabled: _readBool(map['isDisabled']),
      specialty: normalizePossiblyMojibake(
        (map['specialty'] as String?)?.trim() ?? '',
      ),
      hospitalName: normalizePossiblyMojibake(
        (map['hospitalName'] as String?)?.trim() ?? '',
      ),
      experienceYears: _readInt(map['experienceYears']),
      studyYears: _readInt(map['studyYears']),
      disabledAt: _readNullableDate(map['disabledAt']),
      lastSeenAt: _readNullableDate(map['lastSeenAt']),
    );
  }
}

DateTime _parseDate(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is Map<String, dynamic>) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
  }
  return DateTime.now();
}

DateTime? _readNullableDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isEmpty) {
    return null;
  }
  return _parseDate(value);
}

String _readPhoneNumber(Map<String, dynamic> map) {
  final direct = (map['phoneNumber'] as String?)?.trim() ?? '';
  if (direct.isNotEmpty) {
    return direct;
  }

  final email = (map['email'] as String?)?.trim() ?? '';
  final match = RegExp(r'^td(\d+)@sihha\.app$').firstMatch(email);
  if (match != null && match.groupCount >= 1) {
    return '+235${match.group(1)}';
  }

  return '';
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

String _normalizePhotoUrl(dynamic value) {
  return normalizeBackendMediaUrl(value);
}
