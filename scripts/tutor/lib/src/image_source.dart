import 'dart:typed_data';

class TutorImageAsset {
  const TutorImageAsset({
    required this.path,
    required this.bytes,
    required this.mediaType,
  });

  final String path;
  final Uint8List bytes;
  final String mediaType;
}

class TutorImageException implements Exception {
  TutorImageException(this.message);
  final String message;
  @override
  String toString() => message;
}

Uri quizImagePublicUri({
  required String supabaseUrl,
  required String imagePath,
}) {
  final trimmed = imagePath.trim();
  if (trimmed.contains('..') ||
      trimmed.startsWith('/') ||
      trimmed.startsWith('http://') ||
      trimmed.startsWith('https://')) {
    throw TutorImageException(
      'image path is not a quiz-images object: $trimmed',
    );
  }
  final base = Uri.parse(supabaseUrl);
  if (!base.hasScheme || base.host.isEmpty) {
    throw TutorImageException('SUPABASE_URL is not absolute');
  }
  return base.replace(
    pathSegments: [
      'storage',
      'v1',
      'object',
      'public',
      'quiz-images',
      ...trimmed.split('/').where((segment) => segment.isNotEmpty),
    ],
  );
}

String? mediaTypeForImagePath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return null;
}

String? normalizeImageContentType(String? header) {
  if (header == null) return null;
  final mime = header.split(';').first.trim().toLowerCase();
  return mime.isEmpty ? null : mime;
}

String? magicMediaType(Uint8List bytes) {
  if (_startsWith(bytes, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return 'image/png';
  }
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (_startsWith(bytes, const [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
      _startsWith(bytes, const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      _startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

bool _startsWith(Uint8List bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

/// Accepts an image only when path, Content-Type, and signature agree.
///
/// `application/octet-stream` and a missing Content-Type fail closed.
TutorImageAsset validateFetchedQuizImage({
  required String path,
  required int statusCode,
  required String? contentType,
  required Uint8List bytes,
}) {
  final expected = mediaTypeForImagePath(path);
  if (expected == null) {
    throw TutorImageException('unsupported image type for $path');
  }
  if (statusCode != 200) {
    throw TutorImageException(
      'image fetch failed for $path (HTTP $statusCode)',
    );
  }
  if (bytes.isEmpty) {
    throw TutorImageException('empty image for $path');
  }
  final mime = normalizeImageContentType(contentType);
  final signature = magicMediaType(bytes);
  if (mime == null ||
      mime == 'application/octet-stream' ||
      mime != expected ||
      signature != expected) {
    throw TutorImageException(
      'image validation failed for $path '
      '(content-type: ${mime ?? 'missing'}, signature: ${signature ?? 'unknown'})',
    );
  }
  return TutorImageAsset(path: path, bytes: bytes, mediaType: expected);
}

TutorImageAsset validateQuizImageAsset(TutorImageAsset asset) {
  return validateFetchedQuizImage(
    path: asset.path,
    statusCode: 200,
    contentType: asset.mediaType,
    bytes: asset.bytes,
  );
}

abstract class TutorImageSource {
  Future<TutorImageAsset> fetch(String imagePath);
}
