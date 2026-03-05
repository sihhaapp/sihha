import '../utils/text_normalizer.dart';

enum RequestSubjectType {
  self,
  other;

  String get value => this == RequestSubjectType.self ? 'self' : 'other';

  static RequestSubjectType fromValue(String? value) {
    if (value == 'other') return RequestSubjectType.other;
    return RequestSubjectType.self;
  }
}

enum RequestStatus {
  pending,
  accepted,
  rejected;

  String get value {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.accepted:
        return 'accepted';
      case RequestStatus.rejected:
        return 'rejected';
    }
  }

  static RequestStatus fromValue(String? value) {
    switch (value) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'rejected':
        return RequestStatus.rejected;
      default:
        return RequestStatus.pending;
    }
  }
}

enum RequestGender {
  male,
  female;

  String get value => this == RequestGender.male ? 'male' : 'female';

  static RequestGender fromValue(String? value) {
    if (value == 'female') return RequestGender.female;
    return RequestGender.male;
  }
}

enum RequestPregnancyStatus {
  notApplicable,
  pregnant,
  notPregnant,
  notSure;

  String get value {
    switch (this) {
      case RequestPregnancyStatus.notApplicable:
        return 'not_applicable';
      case RequestPregnancyStatus.pregnant:
        return 'pregnant';
      case RequestPregnancyStatus.notPregnant:
        return 'not_pregnant';
      case RequestPregnancyStatus.notSure:
        return 'not_sure';
    }
  }

  static RequestPregnancyStatus fromValue(String? value) {
    switch (value) {
      case 'pregnant':
        return RequestPregnancyStatus.pregnant;
      case 'not_pregnant':
        return RequestPregnancyStatus.notPregnant;
      case 'not_sure':
        return RequestPregnancyStatus.notSure;
      default:
        return RequestPregnancyStatus.notApplicable;
    }
  }
}

enum SpokenLanguage {
  ar,
  fr,
  bilingual;

  String get value {
    switch (this) {
      case SpokenLanguage.ar:
        return 'ar';
      case SpokenLanguage.fr:
        return 'fr';
      case SpokenLanguage.bilingual:
        return 'bilingual';
    }
  }

  static SpokenLanguage fromValue(String? value) {
    switch (value) {
      case 'fr':
        return SpokenLanguage.fr;
      case 'bilingual':
        return SpokenLanguage.bilingual;
      default:
        return SpokenLanguage.ar;
    }
  }
}

class ConsultationRequest {
  const ConsultationRequest({
    required this.id,
    required this.patientId,
    required this.targetDoctorId,
    required this.subjectType,
    required this.subjectName,
    required this.ageYears,
    required this.gender,
    required this.pregnancyStatus,
    required this.weightKg,
    required this.stateCode,
    required this.spokenLanguage,
    required this.symptoms,
    this.symptomsVoiceUrl = '',
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.respondedAt,
    this.respondedByDoctorId,
    this.transferredByDoctorId,
    this.linkedRoomId,
    this.patientName = '',
    this.patientPhotoUrl = '',
    this.targetDoctorName = '',
    this.targetDoctorPhotoUrl = '',
    this.respondedByDoctorName,
    this.transferredByDoctorName,
  });

  final String id;
  final String patientId;
  final String targetDoctorId;
  final RequestSubjectType subjectType;
  final String subjectName;
  final int ageYears;
  final RequestGender gender;
  final RequestPregnancyStatus pregnancyStatus;
  final double weightKg;
  final String stateCode;
  final SpokenLanguage spokenLanguage;
  final String symptoms;
  final String symptomsVoiceUrl;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? respondedAt;
  final String? respondedByDoctorId;
  final String? transferredByDoctorId;
  final String? linkedRoomId;
  final String patientName;
  final String patientPhotoUrl;
  final String targetDoctorName;
  final String targetDoctorPhotoUrl;
  final String? respondedByDoctorName;
  final String? transferredByDoctorName;

  bool get isPending => status == RequestStatus.pending;
  bool get isAccepted => status == RequestStatus.accepted;
  bool get isRejected => status == RequestStatus.rejected;

  factory ConsultationRequest.fromMap(Map<String, dynamic> map) {
    final patientMap = _asStringMap(map['patient']);
    final doctorMap = _asStringMap(map['targetDoctor'] ?? map['doctor']);
    return ConsultationRequest(
      id: (map['id'] as String?)?.trim() ?? '',
      patientId: _firstNonEmptyString([
        map['patientId'],
        map['patient_id'],
        patientMap['id'],
        patientMap['userId'],
        patientMap['user_id'],
      ]),
      targetDoctorId: _firstNonEmptyString([
        map['targetDoctorId'],
        map['target_doctor_id'],
        map['doctorId'],
        map['doctor_id'],
        doctorMap['id'],
        doctorMap['userId'],
        doctorMap['user_id'],
      ]),
      subjectType: RequestSubjectType.fromValue(
        _firstNonEmptyString([map['subjectType'], map['subject_type']]),
      ),
      subjectName: _normalizeUiText(
        _firstNonEmptyString([map['subjectName'], map['subject_name']]),
      ),
      ageYears: _toInt(map['ageYears'] ?? map['age_years']),
      gender: RequestGender.fromValue(_firstNonEmptyString([map['gender']])),
      pregnancyStatus: RequestPregnancyStatus.fromValue(
        _firstNonEmptyString([map['pregnancyStatus'], map['pregnancy_status']]),
      ),
      weightKg: _toDouble(map['weightKg'] ?? map['weight_kg']),
      stateCode: _firstNonEmptyString([map['stateCode'], map['state_code']]),
      spokenLanguage: SpokenLanguage.fromValue(
        _firstNonEmptyString([map['spokenLanguage'], map['spoken_language']]),
      ),
      symptoms: _normalizeUiText(_firstNonEmptyString([map['symptoms']])),
      symptomsVoiceUrl: _normalizePhotoUrl(
        _firstNonEmptyString([
          map['symptomsVoiceUrl'],
          map['symptoms_voice_url'],
        ]),
      ),
      status: RequestStatus.fromValue(_firstNonEmptyString([map['status']])),
      createdAt: _toDateTime(map['createdAt'] ?? map['created_at']),
      updatedAt: _toDateTime(map['updatedAt'] ?? map['updated_at']),
      respondedAt: _toNullableDateTime(
        map['respondedAt'] ?? map['responded_at'],
      ),
      respondedByDoctorId: _toNullableTrimmedString(
        map['respondedByDoctorId'] ?? map['responded_by_doctor_id'],
      ),
      transferredByDoctorId: _toNullableTrimmedString(
        map['transferredByDoctorId'] ?? map['transferred_by_doctor_id'],
      ),
      linkedRoomId: _toNullableTrimmedString(
        map['linkedRoomId'] ??
            map['linked_room_id'] ??
            map['roomId'] ??
            map['room_id'],
      ),
      patientName: _normalizeUiText(
        _firstNonEmptyString([
          map['patientName'],
          map['patient_name'],
          patientMap['name'],
        ]),
      ),
      patientPhotoUrl: _normalizePhotoUrl(
        _firstNonEmptyString([
          map['patientPhotoUrl'],
          map['patient_photo_url'],
          map['patientPhoto'],
          map['patient_photo'],
          patientMap['photoUrl'],
          patientMap['photo_url'],
        ]),
      ),
      targetDoctorName: _normalizeUiText(
        _firstNonEmptyString([
          map['targetDoctorName'],
          map['target_doctor_name'],
          map['doctorName'],
          map['doctor_name'],
          doctorMap['name'],
        ]),
      ),
      targetDoctorPhotoUrl: _normalizePhotoUrl(
        _firstNonEmptyString([
          map['targetDoctorPhotoUrl'],
          map['target_doctor_photo_url'],
          map['doctorPhotoUrl'],
          map['doctor_photo_url'],
          doctorMap['photoUrl'],
          doctorMap['photo_url'],
        ]),
      ),
      respondedByDoctorName: _normalizeNullableUiText(
        _toNullableTrimmedString(
          map['respondedByDoctorName'] ?? map['responded_by_doctor_name'],
        ),
      ),
      transferredByDoctorName: _normalizeNullableUiText(
        _toNullableTrimmedString(
          map['transferredByDoctorName'] ?? map['transferred_by_doctor_name'],
        ),
      ),
    );
  }
}

String _normalizeUiText(String value) => normalizePossiblyMojibake(value);

String? _normalizeNullableUiText(String? value) {
  if (value == null) {
    return null;
  }
  return normalizePossiblyMojibake(value);
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

DateTime _toDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

DateTime? _toNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  return _toDateTime(value);
}

String? _toNullableTrimmedString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return text;
}

String _firstNonEmptyString(Iterable<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

String _normalizePhotoUrl(dynamic value) {
  final raw = (value as String?)?.trim() ?? '';
  if (raw.isEmpty) {
    return '';
  }

  final apiBase = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sihha.space/api',
  ).trim();
  final apiUri = Uri.tryParse(apiBase);
  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return raw;
  }

  String normalizeUploadPath(String path) {
    if (path.startsWith('/api/uploads/')) {
      return path.replaceFirst('/api/uploads/', '/uploads/');
    }
    if (path.contains('/api/uploads/')) {
      return path.replaceFirst('/api/uploads/', '/uploads/');
    }
    final uploadsIndex = path.indexOf('/uploads/');
    if (uploadsIndex >= 0) {
      return path.substring(uploadsIndex);
    }
    return path;
  }

  bool isUploadsPath(String path) {
    return path.startsWith('/uploads/') ||
        path.contains('/uploads/') ||
        path.startsWith('/api/uploads/') ||
        path.contains('/api/uploads/');
  }

  if (isUploadsPath(uri.path) && apiUri != null && apiUri.host.isNotEmpty) {
    final normalizedPath = normalizeUploadPath(uri.path);
    if (uri.hasScheme) {
      return uri
          .replace(
            scheme: apiUri.scheme.isEmpty ? uri.scheme : apiUri.scheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
            path: normalizedPath,
          )
          .toString();
    }
    return apiUri
        .replace(
          path: normalizedPath,
          query: uri.query.isEmpty ? null : uri.query,
          fragment: uri.fragment.isEmpty ? null : uri.fragment,
        )
        .toString();
  }

  if (!uri.hasScheme) {
    return raw;
  }

  final host = uri.host.toLowerCase();
  final isLoopbackHost =
      host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
  if (!isLoopbackHost || apiUri == null || apiUri.host.isEmpty) {
    return raw;
  }

  final normalized = uri.replace(
    scheme: apiUri.scheme.isEmpty ? uri.scheme : apiUri.scheme,
    host: apiUri.host,
    port: apiUri.hasPort ? apiUri.port : uri.port,
  );
  return normalized.toString();
}
