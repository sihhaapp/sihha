import '../utils/date_parser.dart';
import '../utils/media_url_normalizer.dart';

class MedicalConsultationHistoryItem {
  const MedicalConsultationHistoryItem({
    required this.roomId,
    required this.doctorId,
    required this.doctorName,
    required this.startedAt,
    required this.lastUpdatedAt,
    required this.isClosed,
  });

  final String roomId;
  final String doctorId;
  final String doctorName;
  final DateTime startedAt;
  final DateTime lastUpdatedAt;
  final bool isClosed;

  factory MedicalConsultationHistoryItem.fromMap(Map<String, dynamic> map) {
    return MedicalConsultationHistoryItem(
      roomId: (map['roomId'] as String?)?.trim() ?? '',
      doctorId: (map['doctorId'] as String?)?.trim() ?? '',
      doctorName: (map['doctorName'] as String?)?.trim() ?? '',
      startedAt: parseDate(map['startedAt']),
      lastUpdatedAt: parseDate(map['lastUpdatedAt']),
      isClosed: map['isClosed'] == true || map['is_closed'] == 1,
    );
  }
}

class MedicalRecordEntry {
  const MedicalRecordEntry({
    required this.id,
    required this.patientId,
    required this.roomId,
    required this.doctorId,
    required this.doctorName,
    required this.diagnosis,
    required this.prescribedMedications,
    required this.secretNotes,
    required this.prescriptionPdfUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String patientId;
  final String roomId;
  final String doctorId;
  final String doctorName;
  final String diagnosis;
  final String prescribedMedications;
  final String secretNotes;
  final String prescriptionPdfUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasPrescriptionPdf => prescriptionPdfUrl.trim().isNotEmpty;

  factory MedicalRecordEntry.fromMap(Map<String, dynamic> map) {
    return MedicalRecordEntry(
      id: (map['id'] as String?)?.trim() ?? '',
      patientId: (map['patientId'] as String?)?.trim() ?? '',
      roomId: (map['roomId'] as String?)?.trim() ?? '',
      doctorId: (map['doctorId'] as String?)?.trim() ?? '',
      doctorName: (map['doctorName'] as String?)?.trim() ?? '',
      diagnosis: (map['diagnosis'] as String?)?.trim() ?? '',
      prescribedMedications:
          (map['prescribedMedications'] as String?)?.trim() ?? '',
      secretNotes: (map['secretNotes'] as String?)?.trim() ?? '',
      prescriptionPdfUrl: normalizeBackendMediaUrl(
        (map['prescriptionPdfUrl'] as String?)?.trim() ?? '',
      ),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class MedicalRecord {
  const MedicalRecord({
    required this.patientId,
    required this.allergies,
    required this.chronicDiseases,
    required this.consultationHistory,
    required this.previousDiagnoses,
    required this.prescribedMedications,
    required this.latestPrescriptionPdfUrl,
    required this.updatedAt,
    required this.entries,
  });

  final String patientId;
  final String allergies;
  final String chronicDiseases;
  final List<MedicalConsultationHistoryItem> consultationHistory;
  final List<String> previousDiagnoses;
  final List<String> prescribedMedications;
  final String? latestPrescriptionPdfUrl;
  final DateTime? updatedAt;
  final List<MedicalRecordEntry> entries;

  MedicalRecordEntry? latestEntryForDoctor(String doctorId) {
    for (final entry in entries) {
      if (entry.doctorId == doctorId) {
        return entry;
      }
    }
    return null;
  }

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    final historyRaw = map['consultationHistory'];
    final entriesRaw = map['entries'];

    return MedicalRecord(
      patientId: (map['patientId'] as String?)?.trim() ?? '',
      allergies: (map['allergies'] as String?)?.trim() ?? '',
      chronicDiseases: (map['chronicDiseases'] as String?)?.trim() ?? '',
      consultationHistory: historyRaw is List
          ? historyRaw
                .whereType<Map>()
                .map(
                  (item) => MedicalConsultationHistoryItem.fromMap(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const <MedicalConsultationHistoryItem>[],
      previousDiagnoses: _readStringList(map['previousDiagnoses']),
      prescribedMedications: _readStringList(map['prescribedMedications']),
      latestPrescriptionPdfUrl: _normalizeNullableAssetUrl(
        map['latestPrescriptionPdfUrl'],
      ),
      updatedAt: parseNullableDate(map['updatedAt']),
      entries: entriesRaw is List
          ? entriesRaw
                .whereType<Map>()
                .map(
                  (item) => MedicalRecordEntry.fromMap(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const <MedicalRecordEntry>[],
    );
  }
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  final seen = <String>{};
  final result = <String>[];
  for (final item in value) {
    final text = item?.toString().trim() ?? '';
    if (text.isEmpty || seen.contains(text)) {
      continue;
    }
    seen.add(text);
    result.add(text);
  }
  return result;
}

String? _normalizeNullableAssetUrl(dynamic value) {
  final raw = (value as String?)?.trim() ?? '';
  if (raw.isEmpty) return null;
  return normalizeBackendMediaUrl(raw);
}
