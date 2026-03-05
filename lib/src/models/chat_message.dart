import '../utils/text_normalizer.dart';

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
    final rawContent = normalizePossiblyMojibake(
      (map['content'] as String?) ?? '',
    );
    return ChatMessage(
      id: id,
      roomId: (map['roomId'] as String?) ?? '',
      senderId: (map['senderId'] as String?) ?? '',
      senderName: normalizePossiblyMojibake(
        (map['senderName'] as String?) ?? 'User',
      ),
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
  final apiBase = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sihha.space/api',
  ).trim();
  final apiUri = Uri.tryParse(apiBase);
  if (apiUri == null || apiUri.host.isEmpty) {
    return raw;
  }

  final normalizedPath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
  final isUploadsPath = normalizedPath.startsWith('/uploads/');
  final shouldRewriteHost = _isInternalOrLocalHost(host);
  final shouldRewriteScheme =
      host == apiUri.host.toLowerCase() &&
      apiUri.scheme.isNotEmpty &&
      uri.scheme != apiUri.scheme;
  final shouldRewritePort =
      host == apiUri.host.toLowerCase() &&
      ((uri.hasPort && !apiUri.hasPort) ||
          (!uri.hasPort && apiUri.hasPort) ||
          (uri.hasPort && apiUri.hasPort && uri.port != apiUri.port));

  final shouldRewriteUploadsOrigin =
      isUploadsPath && host != apiUri.host.toLowerCase();

  if (!shouldRewriteHost &&
      !shouldRewriteScheme &&
      !shouldRewritePort &&
      !shouldRewriteUploadsOrigin) {
    return raw;
  }

  final normalizedScheme = apiUri.scheme.isEmpty ? uri.scheme : apiUri.scheme;
  final normalized = apiUri.hasPort
      ? Uri(
          scheme: normalizedScheme,
          host: apiUri.host,
          port: apiUri.port,
          path: normalizedPath,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.hasFragment ? uri.fragment : null,
        )
      : Uri(
          scheme: normalizedScheme,
          host: apiUri.host,
          path: normalizedPath,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.hasFragment ? uri.fragment : null,
        );
  return normalized.toString();
}

bool _isInternalOrLocalHost(String host) {
  final normalized = host.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '10.0.2.2' ||
      normalized == '::1') {
    return true;
  }
  if (!normalized.contains('.') && !normalized.contains(':')) {
    return true;
  }

  final match = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  ).firstMatch(normalized);
  if (match == null) {
    return false;
  }

  final octets = <int>[
    int.tryParse(match.group(1) ?? '') ?? -1,
    int.tryParse(match.group(2) ?? '') ?? -1,
    int.tryParse(match.group(3) ?? '') ?? -1,
    int.tryParse(match.group(4) ?? '') ?? -1,
  ];
  if (octets.any((value) => value < 0 || value > 255)) {
    return false;
  }

  final first = octets[0];
  final second = octets[1];
  if (first == 10 || first == 127) {
    return true;
  }
  if (first == 192 && second == 168) {
    return true;
  }
  if (first == 172 && second >= 16 && second <= 31) {
    return true;
  }
  if (first == 169 && second == 254) {
    return true;
  }
  return false;
}
