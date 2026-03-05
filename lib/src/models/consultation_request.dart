import '../utils/api_response_helpers.dart';
import '../utils/date_parser.dart';
import '../utils/media_url_normalizer.dart';
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
    final patientMap = asStringMap(map['patient']);
    final doctorMap = asStringMap(map['targetDoctor'] ?? map['doctor']);
    return ConsultationRequest(
      id: (map['id'] as String?)?.trim() ?? '',
      patientId: firstNonEmptyString([
        map['patientId'],
        map['patient_id'],
        patientMap['id'],
        patientMap['userId'],
        patientMap['user_id'],
      ]),
      targetDoctorId: firstNonEmptyString([
        map['targetDoctorId'],
        map['target_doctor_id'],
        map['doctorId'],
        map['doctor_id'],
        doctorMap['id'],
        doctorMap['userId'],
        doctorMap['user_id'],
      ]),
      subjectType: RequestSubjectType.fromValue(
        firstNonEmptyString([map['subjectType'], map['subject_type']]),
      ),
      subjectName: _normalizeUiText(
        firstNonEmptyString([map['subjectName'], map['subject_name']]),
      ),
      ageYears: readInt(map['ageYears'] ?? map['age_years']),
      gender: RequestGender.fromValue(firstNonEmptyString([map['gender']])),
      pregnancyStatus: RequestPregnancyStatus.fromValue(
        firstNonEmptyString([map['pregnancyStatus'], map['pregnancy_status']]),
      ),
      weightKg: _toDouble(map['weightKg'] ?? map['weight_kg']),
      stateCode: firstNonEmptyString([map['stateCode'], map['state_code']]),
      spokenLanguage: SpokenLanguage.fromValue(
        firstNonEmptyString([map['spokenLanguage'], map['spoken_language']]),
      ),
      symptoms: _normalizeUiText(firstNonEmptyString([map['symptoms']])),
      symptomsVoiceUrl: normalizeBackendMediaUrl(
        firstNonEmptyString([
          map['symptomsVoiceUrl'],
          map['symptoms_voice_url'],
        ]),
      ),
      status: RequestStatus.fromValue(firstNonEmptyString([map['status']])),
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at']),
      respondedAt: parseNullableDate(map['respondedAt'] ?? map['responded_at']),
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
        firstNonEmptyString([
          map['patientName'],
          map['patient_name'],
          patientMap['name'],
        ]),
      ),
      patientPhotoUrl: normalizeBackendMediaUrl(
        firstNonEmptyString([
          map['patientPhotoUrl'],
          map['patient_photo_url'],
          map['patientPhoto'],
          map['patient_photo'],
          patientMap['photoUrl'],
          patientMap['photo_url'],
        ]),
      ),
      targetDoctorName: _normalizeUiText(
        firstNonEmptyString([
          map['targetDoctorName'],
          map['target_doctor_name'],
          map['doctorName'],
          map['doctor_name'],
          doctorMap['name'],
        ]),
      ),
      targetDoctorPhotoUrl: normalizeBackendMediaUrl(
        firstNonEmptyString([
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

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

String? _toNullableTrimmedString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return text;
}
