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
    return ChatRoom(
      id: id,
      patientId: (map['patientId'] as String?) ?? '',
      patientName: (map['patientName'] as String?) ?? 'Patient',
      patientPhotoUrl: _normalizePhotoUrl(map['patientPhotoUrl']),
      doctorId: (map['doctorId'] as String?) ?? '',
      doctorName: (map['doctorName'] as String?) ?? 'Doctor',
      doctorPhotoUrl: _normalizePhotoUrl(map['doctorPhotoUrl']),
      participantIds: (map['participantIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      lastMessage: (map['lastMessage'] as String?) ?? '',
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(map['createdAt']),
      lastUpdatedAt: _parseDate(map['lastUpdatedAt']),
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

String _normalizePhotoUrl(dynamic value) {
  final raw = (value as String?)?.trim() ?? '';
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
    defaultValue: 'http://10.0.2.2:3000/api',
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
