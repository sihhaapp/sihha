import '../utils/media_url_normalizer.dart';

class HealthBlog {
  const HealthBlog({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorId,
    required this.authorName,
    required this.profileImageUrl,
    required this.expressiveImageUrl1,
    required this.expressiveImageUrl2,
    required this.expressiveImageUrl3,
    required this.reactionsCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.myReaction,
    required this.publishedAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String category;
  final String authorId;
  final String authorName;
  final String profileImageUrl;
  final String expressiveImageUrl1;
  final String expressiveImageUrl2;
  final String expressiveImageUrl3;
  final int reactionsCount;
  final int commentsCount;
  final int sharesCount;
  final String myReaction;
  final DateTime publishedAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'authorId': authorId,
      'authorName': authorName,
      'profileImageUrl': profileImageUrl,
      'expressiveImageUrl1': expressiveImageUrl1,
      'expressiveImageUrl2': expressiveImageUrl2,
      'expressiveImageUrl3': expressiveImageUrl3,
      'reactionsCount': reactionsCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'myReaction': myReaction,
      'publishedAt': publishedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HealthBlog.fromMap(String id, Map<String, dynamic> map) {
    return HealthBlog(
      id: id,
      title: (map['title'] as String?)?.trim() ?? '',
      content: (map['content'] as String?)?.trim() ?? '',
      category: (map['category'] as String?)?.trim() ?? '',
      authorId: (map['authorId'] as String?)?.trim() ?? '',
      authorName: (map['authorName'] as String?)?.trim() ?? 'Doctor',
      profileImageUrl: normalizeBackendMediaUrl(map['profileImageUrl']),
      expressiveImageUrl1: normalizeBackendMediaUrl(
        map['expressiveImageUrl1'],
      ),
      expressiveImageUrl2: normalizeBackendMediaUrl(
        map['expressiveImageUrl2'],
      ),
      expressiveImageUrl3: normalizeBackendMediaUrl(
        map['expressiveImageUrl3'],
      ),
      reactionsCount: _readInt(map['reactionsCount']),
      commentsCount: _readInt(map['commentsCount']),
      sharesCount: _readInt(map['sharesCount']),
      myReaction: (map['myReaction'] as String?)?.trim() ?? '',
      publishedAt: _parseDate(map['publishedAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  List<String> get imageUrls => [
    expressiveImageUrl1.trim(),
    expressiveImageUrl2.trim(),
    expressiveImageUrl3.trim(),
  ].where((url) => url.isNotEmpty).toList(growable: false);
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

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}
