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
      startedAt: _parseDate(map['startedAt']),
      lastUpdatedAt: _parseDate(map['lastUpdatedAt']),
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
      prescriptionPdfUrl: _normalizeAssetUrl(
        (map['prescriptionPdfUrl'] as String?)?.trim() ?? '',
      ),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
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
      updatedAt: _parseNullableDate(map['updatedAt']),
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

DateTime _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  return _parseDate(value);
}

String? _normalizeNullableAssetUrl(dynamic value) {
  final raw = (value as String?)?.trim() ?? '';
  if (raw.isEmpty) return null;
  return _normalizeAssetUrl(raw);
}

String _normalizeAssetUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) {
    return raw;
  }

  final host = uri.host.toLowerCase();
  final isLoopbackHost =
      host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
  if (!isLoopbackHost) {
    return raw;
  }

  final apiBase = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sihha.space/api',
  ).trim();
  final apiUri = Uri.tryParse(apiBase);
  if (apiUri == null || apiUri.host.isEmpty) {
    return raw;
  }

  final normalized = uri.replace(
    scheme: apiUri.scheme.isEmpty ? uri.scheme : apiUri.scheme,
    host: apiUri.host,
    port: apiUri.hasPort ? apiUri.port : uri.port,
  );
  return normalized.toString();
}
