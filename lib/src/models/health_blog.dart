import '../utils/api_response_helpers.dart';
import '../utils/date_parser.dart';
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
    String readMedia(List<String> keys) {
      for (final key in keys) {
        final value = normalizeBackendMediaUrl(map[key]);
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return HealthBlog(
      id: id,
      title: (map['title'] as String?)?.trim() ?? '',
      content: (map['content'] as String?)?.trim() ?? '',
      category: (map['category'] as String?)?.trim() ?? '',
      authorId: (map['authorId'] as String?)?.trim() ?? '',
      authorName: (map['authorName'] as String?)?.trim() ?? 'Doctor',
      profileImageUrl: readMedia([
        'profileImageUrl',
        'profile_image_url',
        'authorPhotoUrl',
        'author_photo_url',
      ]),
      expressiveImageUrl1: readMedia([
        'expressiveImageUrl1',
        'expressive_image_url1',
        'expressive_image_url_1',
        'imageUrl',
        'image_url',
      ]),
      expressiveImageUrl2: readMedia([
        'expressiveImageUrl2',
        'expressive_image_url2',
        'expressive_image_url_2',
        'imageUrl2',
        'image_url_2',
      ]),
      expressiveImageUrl3: readMedia([
        'expressiveImageUrl3',
        'expressive_image_url3',
        'expressive_image_url_3',
        'imageUrl3',
        'image_url_3',
      ]),
      reactionsCount: readInt(map['reactionsCount']),
      commentsCount: readInt(map['commentsCount']),
      sharesCount: readInt(map['sharesCount']),
      myReaction: (map['myReaction'] as String?)?.trim() ?? '',
      publishedAt: parseDate(map['publishedAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  List<String> get imageUrls => [
    expressiveImageUrl1.trim(),
    expressiveImageUrl2.trim(),
    expressiveImageUrl3.trim(),
  ].where((url) => url.isNotEmpty).toList(growable: false);
}
