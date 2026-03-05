import '../utils/media_url_normalizer.dart';

class BlogComment {
  const BlogComment({
    required this.id,
    required this.blogId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String blogId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BlogComment.fromMap(String id, Map<String, dynamic> map) {
    return BlogComment(
      id: id,
      blogId: (map['blogId'] as String?)?.trim() ?? '',
      userId: (map['userId'] as String?)?.trim() ?? '',
      userName: (map['userName'] as String?)?.trim() ?? '',
      userPhotoUrl: normalizeBackendMediaUrl(map['userPhotoUrl']),
      content: (map['content'] as String?)?.trim() ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
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
