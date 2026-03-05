import 'dart:async';

import '../models/blog_comment.dart';
import '../models/health_blog.dart';
import 'api_service.dart';

class BlogService {
  BlogService(this._apiService);

  final ApiService _apiService;

  Stream<List<HealthBlog>> blogsStream() {
    return _poll<List<HealthBlog>>(
      _fetchBlogs,
      interval: const Duration(seconds: 6),
    );
  }

  Future<void> publishBlog({
    required String title,
    required String content,
    required String category,
    required String expressiveImageUrl1,
    required String expressiveImageUrl2,
    required String expressiveImageUrl3,
  }) async {
    await _apiService.post(
      '/blogs',
      body: {
        'title': title.trim(),
        'content': content.trim(),
        'category': category.trim(),
        'expressiveImageUrl1': expressiveImageUrl1.trim(),
        'expressiveImageUrl2': expressiveImageUrl2.trim(),
        'expressiveImageUrl3': expressiveImageUrl3.trim(),
      },
    );
  }

  Future<String> uploadBlogImage({required String filePath}) async {
    final body = await _apiService.postMultipart(
      path: '/uploads/image',
      fileField: 'image',
      filePath: filePath,
    );
    final map = _readMap(body);
    final imageUrl = (map['imageUrl'] as String?)?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const ApiException(
        code: 'invalid-response',
        message: 'Backend did not return a valid image URL.',
      );
    }
    return imageUrl;
  }

  Future<void> toggleReaction({
    required String blogId,
    required String reactionType,
  }) async {
    await _apiService.post(
      '/blogs/${blogId.trim()}/reactions',
      body: {'reactionType': reactionType.trim()},
    );
  }

  Future<List<BlogComment>> fetchComments({required String blogId}) async {
    final body = await _apiService.get('/blogs/${blogId.trim()}/comments');
    final map = _readMap(body);
    final list = _readList(map['comments']);
    return list
        .map((raw) => _readMap(raw))
        .map((raw) => BlogComment.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Future<void> addComment({
    required String blogId,
    required String content,
  }) async {
    await _apiService.post(
      '/blogs/${blogId.trim()}/comments',
      body: {'content': content.trim()},
    );
  }

  Future<void> registerShare({
    required String blogId,
    required String platform,
  }) async {
    await _apiService.post(
      '/blogs/${blogId.trim()}/shares',
      body: {'platform': platform.trim()},
    );
  }

  Future<List<HealthBlog>> _fetchBlogs() async {
    final body = await _apiService.get('/blogs');
    final map = _readMap(body);
    final list = _readList(map['blogs']);
    return list
        .map((raw) => _readMap(raw))
        .map((raw) => HealthBlog.fromMap((raw['id'] as String?) ?? '', raw))
        .toList();
  }

  Stream<T> _poll<T>(
    Future<T> Function() fetch, {
    Duration interval = const Duration(seconds: 5),
  }) async* {
    yield await fetch();
    yield* Stream.periodic(interval).asyncMap((_) => fetch());
  }

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw const ApiException(
      code: 'invalid-response',
      message: 'Unexpected response from backend.',
    );
  }

  List<dynamic> _readList(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    throw const ApiException(
      code: 'invalid-response',
      message: 'Unexpected list payload from backend.',
    );
  }
}
