enum MessageType {
  text,
  audio,
  image,
  live;

  static MessageType fromValue(String? value) {
    if (value == 'image') {
      return MessageType.image;
    }
    if (value == 'live') {
      return MessageType.live;
    }
    if (value == 'audio') {
      return MessageType.audio;
    }
    return MessageType.text;
  }

  String get value {
    switch (this) {
      case MessageType.audio:
        return 'audio';
      case MessageType.image:
        return 'image';
      case MessageType.live:
        return 'live';
      case MessageType.text:
        return 'text';
    }
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    required this.durationSeconds,
    required this.deliveredAt,
    required this.readAt,
    required this.sentAt,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content;
  final int durationSeconds;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime sentAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.value,
      'content': content,
      'durationSeconds': durationSeconds,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'sentAt': sentAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    final type = MessageType.fromValue(map['type'] as String?);
    final rawContent = (map['content'] as String?) ?? '';
    return ChatMessage(
      id: id,
      roomId: (map['roomId'] as String?) ?? '',
      senderId: (map['senderId'] as String?) ?? '',
      senderName: (map['senderName'] as String?) ?? 'User',
      type: type,
      content: _normalizeMessageContent(type: type, content: rawContent),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      deliveredAt: _parseNullableDate(map['deliveredAt']),
      readAt: _parseNullableDate(map['readAt']),
      sentAt: _parseDate(map['sentAt']),
    );
  }
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) {
    return null;
  }
  final parsed = _parseDate(value);
  return parsed;
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

String _normalizeMessageContent({
  required MessageType type,
  required String content,
}) {
  if (type != MessageType.image && type != MessageType.audio) {
    return content;
  }
  return _normalizeMediaUrl(content);
}

String _normalizeMediaUrl(String value) {
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
