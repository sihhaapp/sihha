import '../services/api_service.dart';

Map<String, dynamic> readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw const ApiException(
    code: 'invalid-response',
    message: 'Unexpected response from backend.',
  );
}

List<dynamic> readList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  throw const ApiException(
    code: 'invalid-response',
    message: 'Unexpected list payload from backend.',
  );
}

int readInt(dynamic value) {
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

bool readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

String firstNonEmptyString(Iterable<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

Map<String, dynamic> asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}
