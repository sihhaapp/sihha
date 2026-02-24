import 'dart:async';

import '../models/app_user.dart';
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
    required AppUser author,
    required String title,
    required String content,
    required String category,
  }) async {
    await _apiService.post(
      '/blogs',
      body: {
        'title': title.trim(),
        'content': content.trim(),
        'category': category.trim(),
      },
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
