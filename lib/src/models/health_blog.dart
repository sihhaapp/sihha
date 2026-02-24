class HealthBlog {
  const HealthBlog({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorId,
    required this.authorName,
    required this.publishedAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String category;
  final String authorId;
  final String authorName;
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
      publishedAt: _parseDate(map['publishedAt']),
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
