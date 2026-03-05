import 'dart:convert';

import '../utils/api_response_helpers.dart';
import '../utils/date_parser.dart';
import '../utils/media_url_normalizer.dart';
import '../utils/text_normalizer.dart';

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientPhotoUrl,
    required this.doctorId,
    required this.doctorName,
    required this.doctorPhotoUrl,
    required this.participantIds,
    required this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.isClosed = false,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientPhotoUrl;
  final String doctorId;
  final String doctorName;
  final String doctorPhotoUrl;
  final List<String> participantIds;
  final String lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final bool isClosed;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhotoUrl': patientPhotoUrl,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorPhotoUrl': doctorPhotoUrl,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  factory ChatRoom.fromMap(String id, Map<String, dynamic> map) {
    final patientMap = asStringMap(map['patient']);
    final doctorMap = asStringMap(map['doctor']);
    final patientId = firstNonEmptyString([
      map['patientId'],
      map['patient_id'],
      patientMap['id'],
      patientMap['userId'],
      patientMap['user_id'],
    ]);
    final doctorId = firstNonEmptyString([
      map['doctorId'],
      map['doctor_id'],
      doctorMap['id'],
      doctorMap['userId'],
      doctorMap['user_id'],
    ]);

    return ChatRoom(
      id: id,
      patientId: patientId,
      patientName:
          _normalizeUiText(
            firstNonEmptyString([
              map['patientName'],
              map['patient_name'],
              patientMap['name'],
            ]),
          ).isNotEmpty
          ? _normalizeUiText(
              firstNonEmptyString([
                map['patientName'],
                map['patient_name'],
                patientMap['name'],
              ]),
            )
          : 'Patient',
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
      doctorId: doctorId,
      doctorName:
          _normalizeUiText(
            firstNonEmptyString([
              map['doctorName'],
              map['doctor_name'],
              doctorMap['name'],
            ]),
          ).isNotEmpty
          ? _normalizeUiText(
              firstNonEmptyString([
                map['doctorName'],
                map['doctor_name'],
                doctorMap['name'],
              ]),
            )
          : 'Doctor',
      doctorPhotoUrl: normalizeBackendMediaUrl(
        firstNonEmptyString([
          map['doctorPhotoUrl'],
          map['doctor_photo_url'],
          map['doctorPhoto'],
          map['doctor_photo'],
          doctorMap['photoUrl'],
          doctorMap['photo_url'],
        ]),
      ),
      participantIds: _readParticipantIds(
        map,
        patientId: patientId,
        doctorId: doctorId,
      ),
      lastMessage: _normalizeUiText(
        firstNonEmptyString([map['lastMessage'], map['last_message']]),
      ),
      unreadCount: readInt(map['unreadCount'] ?? map['unread_count']),
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      lastUpdatedAt: parseDate(
        map['lastUpdatedAt'] ??
            map['last_updated_at'] ??
            map['updatedAt'] ??
            map['updated_at'],
      ),
      isClosed:
          map['isClosed'] == true ||
          map['is_closed'] == true ||
          map['is_closed'] == 1 ||
          (map['is_closed'] is num && (map['is_closed'] as num) != 0) ||
          (map['isClosed'] is num && (map['isClosed'] as num) != 0),
    );
  }
}

String _normalizeUiText(String value) => normalizePossiblyMojibake(value);

List<String> _readParticipantIds(
  Map<String, dynamic> map, {
  required String patientId,
  required String doctorId,
}) {
  final raw =
      map['participantIds'] ?? map['participant_ids'] ?? map['participants'];
  final ids = <String>{};

  if (raw is List) {
    for (final item in raw) {
      final id = item?.toString().trim() ?? '';
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
  } else if (raw is String) {
    final source = raw.trim();
    if (source.startsWith('[') && source.endsWith(']')) {
      try {
        final decoded = jsonDecode(source);
        if (decoded is List) {
          for (final item in decoded) {
            final id = item?.toString().trim() ?? '';
            if (id.isNotEmpty) {
              ids.add(id);
            }
          }
        }
      } catch (_) {
        // Ignore malformed participant payload.
      }
    } else if (source.isNotEmpty) {
      for (final part in source.split(',')) {
        final id = part.trim();
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
  }

  if (patientId.isNotEmpty) {
    ids.add(patientId);
  }
  if (doctorId.isNotEmpty) {
    ids.add(doctorId);
  }
  return ids.toList(growable: false);
}
