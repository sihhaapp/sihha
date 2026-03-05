import 'dart:convert';

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
    final patientMap = _asStringMap(map['patient']);
    final doctorMap = _asStringMap(map['doctor']);
    final patientId = _firstNonEmptyString([
      map['patientId'],
      map['patient_id'],
      patientMap['id'],
      patientMap['userId'],
      patientMap['user_id'],
    ]);
    final doctorId = _firstNonEmptyString([
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
            _firstNonEmptyString([
              map['patientName'],
              map['patient_name'],
              patientMap['name'],
            ]),
          ).isNotEmpty
          ? _normalizeUiText(
              _firstNonEmptyString([
                map['patientName'],
                map['patient_name'],
                patientMap['name'],
              ]),
            )
          : 'Patient',
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
      doctorId: doctorId,
      doctorName:
          _normalizeUiText(
            _firstNonEmptyString([
              map['doctorName'],
              map['doctor_name'],
              doctorMap['name'],
            ]),
          ).isNotEmpty
          ? _normalizeUiText(
              _firstNonEmptyString([
                map['doctorName'],
                map['doctor_name'],
                doctorMap['name'],
              ]),
            )
          : 'Doctor',
      doctorPhotoUrl: _normalizePhotoUrl(
        _firstNonEmptyString([
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
        _firstNonEmptyString([map['lastMessage'], map['last_message']]),
      ),
      unreadCount: _toInt(map['unreadCount'] ?? map['unread_count']),
      createdAt: _parseDate(map['createdAt'] ?? map['created_at']),
      lastUpdatedAt: _parseDate(
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

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
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
