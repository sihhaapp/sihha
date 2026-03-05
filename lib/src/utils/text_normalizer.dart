import 'dart:convert';

// Repairs common mojibake patterns caused by latin1/cp1252 UTF-8 mis-decoding.
String normalizePossiblyMojibake(String text) {
  var repaired = text;
  for (var i = 0; i < 4; i++) {
    if (!_mojibakeHint.hasMatch(repaired) &&
        !repaired.contains('\u00EF\u00BB\u00BF')) {
      break;
    }

    final decoded = _decodeLegacyMojibake(repaired);
    if (decoded == repaired) {
      break;
    }
    repaired = decoded;
  }

  return repaired
      .replaceAll('\u00C2 ', ' ')
      .replaceAll('\u00C2', '')
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u00EF\u00BB\u00BF', '')
      .replaceAll('\uFFFD', '');
}

final RegExp _mojibakeHint = RegExp(
  r'[\u00C3\u00C2\u00D8\u00D9\u00E2\u00EF\u0153\u017D\u017E\u02DC\u2122\uFFFD]',
);

const Map<int, int> _cp1252CodePointToByte = <int, int>{
  0x20AC: 0x80,
  0x201A: 0x82,
  0x0192: 0x83,
  0x201E: 0x84,
  0x2026: 0x85,
  0x2020: 0x86,
  0x2021: 0x87,
  0x02C6: 0x88,
  0x2030: 0x89,
  0x0160: 0x8A,
  0x2039: 0x8B,
  0x0152: 0x8C,
  0x017D: 0x8E,
  0x2018: 0x91,
  0x2019: 0x92,
  0x201C: 0x93,
  0x201D: 0x94,
  0x2022: 0x95,
  0x2013: 0x96,
  0x2014: 0x97,
  0x02DC: 0x98,
  0x2122: 0x99,
  0x0161: 0x9A,
  0x203A: 0x9B,
  0x0153: 0x9C,
  0x017E: 0x9E,
  0x0178: 0x9F,
};

String _decodeLegacyMojibake(String value) {
  final bytes = <int>[];
  for (final rune in value.runes) {
    if (rune <= 0xFF) {
      bytes.add(rune);
      continue;
    }

    final mapped = _cp1252CodePointToByte[rune];
    if (mapped == null) {
      return value;
    }
    bytes.add(mapped);
  }

  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return value;
  }
}
