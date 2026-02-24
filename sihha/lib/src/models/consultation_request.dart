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
    required this.weightKg,
    required this.stateCode,
    required this.spokenLanguage,
    required this.symptoms,
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
  final double weightKg;
  final String stateCode;
  final SpokenLanguage spokenLanguage;
  final String symptoms;
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
    return ConsultationRequest(
      id: (map['id'] as String?)?.trim() ?? '',
      patientId: (map['patientId'] as String?)?.trim() ?? '',
      targetDoctorId: (map['targetDoctorId'] as String?)?.trim() ?? '',
      subjectType: RequestSubjectType.fromValue(map['subjectType'] as String?),
      subjectName: (map['subjectName'] as String?)?.trim() ?? '',
      ageYears: _toInt(map['ageYears']),
      gender: RequestGender.fromValue(map['gender'] as String?),
      weightKg: _toDouble(map['weightKg']),
      stateCode: (map['stateCode'] as String?)?.trim() ?? '',
      spokenLanguage: SpokenLanguage.fromValue(map['spokenLanguage'] as String?),
      symptoms: (map['symptoms'] as String?)?.trim() ?? '',
      status: RequestStatus.fromValue(map['status'] as String?),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      respondedAt: _toNullableDateTime(map['respondedAt']),
      respondedByDoctorId: (map['respondedByDoctorId'] as String?)?.trim(),
      transferredByDoctorId: (map['transferredByDoctorId'] as String?)?.trim(),
      linkedRoomId: (map['linkedRoomId'] as String?)?.trim(),
      patientName: (map['patientName'] as String?)?.trim() ?? '',
      patientPhotoUrl: (map['patientPhotoUrl'] as String?)?.trim() ?? '',
      targetDoctorName: (map['targetDoctorName'] as String?)?.trim() ?? '',
      targetDoctorPhotoUrl: (map['targetDoctorPhotoUrl'] as String?)?.trim() ?? '',
      respondedByDoctorName: (map['respondedByDoctorName'] as String?)?.trim(),
      transferredByDoctorName: (map['transferredByDoctorName'] as String?)?.trim(),
    );
  }
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
