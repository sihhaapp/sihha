String normalizeBackendMediaUrl(dynamic value) {
  final raw = (value as String?)?.trim() ?? '';
  if (raw.isEmpty) {
    return '';
  }

  final apiBase = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sihha.space/api',
  ).trim();
  final apiUri = Uri.tryParse(apiBase);
  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return raw;
  }

  String normalizeUploadPath(String path) {
    if (path.startsWith('api/uploads/')) {
      return '/${path.replaceFirst('api/uploads/', 'uploads/')}';
    }
    if (path.startsWith('/api/uploads/')) {
      return path.replaceFirst('/api/uploads/', '/uploads/');
    }
    if (path.contains('api/uploads/')) {
      return '/${path.replaceFirst('api/uploads/', 'uploads/')}';
    }
    if (path.contains('/api/uploads/')) {
      return path.replaceFirst('/api/uploads/', '/uploads/');
    }
    final uploadsIndex = path.indexOf('/uploads/');
    if (uploadsIndex >= 0) {
      return path.substring(uploadsIndex);
    }
    final rawUploadsIndex = path.indexOf('uploads/');
    if (rawUploadsIndex >= 0) {
      return '/${path.substring(rawUploadsIndex)}';
    }
    return path;
  }

  bool isUploadsPath(String path) {
    return path.startsWith('/uploads/') ||
        path.startsWith('uploads/') ||
        path.contains('uploads/') ||
        path.contains('/uploads/') ||
        path.startsWith('api/uploads/') ||
        path.contains('api/uploads/') ||
        path.startsWith('/api/uploads/') ||
        path.contains('/api/uploads/');
  }

  if (isUploadsPath(uri.path) && apiUri != null && apiUri.host.isNotEmpty) {
    final normalizedPath = normalizeUploadPath(uri.path);
    if (uri.hasScheme) {
      return uri
          .replace(
            scheme: apiUri.scheme.isEmpty ? uri.scheme : apiUri.scheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
            path: normalizedPath,
          )
          .toString();
    }
    return apiUri
        .replace(
          path: normalizedPath,
          query: uri.query.isEmpty ? null : uri.query,
          fragment: uri.fragment.isEmpty ? null : uri.fragment,
        )
        .toString();
  }

  if (!uri.hasScheme) {
    return raw;
  }

  final host = uri.host.toLowerCase();
  final isLoopbackHost =
      host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
  if (!isLoopbackHost || apiUri == null || apiUri.host.isEmpty) {
    return raw;
  }

  final normalized = uri.replace(
    scheme: apiUri.scheme.isEmpty ? uri.scheme : apiUri.scheme,
    host: apiUri.host,
    port: apiUri.hasPort ? apiUri.port : uri.port,
  );
  return normalized.toString();
}
