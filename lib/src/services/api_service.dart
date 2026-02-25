import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($code): $message';
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000/api',
          );

  static bool _loggedBaseUrl = false;

  final http.Client _client;
  final String baseUrl;
  String? _authToken;

  void logResolvedBaseUrl() {
    if (!kDebugMode || _loggedBaseUrl) {
      return;
    }
    _loggedBaseUrl = true;
    debugPrint('ApiService baseUrl=$baseUrl');
  }

  void setAuthToken(String? token) {
    _authToken = token?.trim();
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    logResolvedBaseUrl();
    return _sendRequest(
      () => _client.get(_uri(path, query), headers: _authHeaders()),
    );
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    logResolvedBaseUrl();
    return _sendRequest(
      () => _client.post(
        _uri(path),
        headers: _jsonHeaders(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    logResolvedBaseUrl();
    return _sendRequest(
      () => _client.put(
        _uri(path),
        headers: _jsonHeaders(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    logResolvedBaseUrl();
    return _sendRequest(
      () => _client.patch(
        _uri(path),
        headers: _jsonHeaders(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  Future<dynamic> delete(String path) async {
    logResolvedBaseUrl();
    return _sendRequest(
      () => _client.delete(
        _uri(path),
        headers: _authHeaders(),
      ),
    );
  }

  Future<dynamic> postMultipart({
    required String path,
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
  }) async {
    logResolvedBaseUrl();
    final uri = _uri(path);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders());
    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));

    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 25),
      );
      final response = await http.Response.fromStream(streamed);
      return _decodeAndValidateResponse(response);
    } on SocketException {
      throw const ApiException(
        code: 'network-error',
        message: 'Unable to connect to the backend server.',
      );
    } on TimeoutException {
      throw const ApiException(
        code: 'request-timeout',
        message: 'Request timed out while contacting the backend server.',
      );
    }
  }

  Future<dynamic> _sendRequest(Future<http.Response> Function() execute) async {
    try {
      final response = await execute().timeout(const Duration(seconds: 25));
      return _decodeAndValidateResponse(response);
    } on SocketException {
      throw const ApiException(
        code: 'network-error',
        message: 'Unable to connect to the backend server.',
      );
    } on TimeoutException {
      throw const ApiException(
        code: 'request-timeout',
        message: 'Request timed out while contacting the backend server.',
      );
    }
  }

  dynamic _decodeAndValidateResponse(http.Response response) {
    final bodyText = utf8.decode(response.bodyBytes);
    final hasBody = bodyText.trim().isNotEmpty;
    final decoded = hasBody ? jsonDecode(bodyText) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final code = (decoded['code'] as String?)?.trim();
      final message = (decoded['message'] as String?)?.trim();
      throw ApiException(
        code: code?.isNotEmpty == true ? code! : 'request-failed',
        message: message?.isNotEmpty == true
            ? message!
            : 'Request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      code: 'request-failed',
      message: 'Request failed with status ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath');
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _jsonHeaders() {
    return {'Content-Type': 'application/json', ..._authHeaders()};
  }

  Map<String, String> _authHeaders() {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      return const {};
    }
    return {'Authorization': 'Bearer $token'};
  }
}
