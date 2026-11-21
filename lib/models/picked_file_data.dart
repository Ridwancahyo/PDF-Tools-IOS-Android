import 'dart:typed_data';

class PickedFileData {
  final String name;
  final Uint8List bytes;
  final String extension;
  final String? path;

  const PickedFileData({
    required this.name,
    required this.bytes,
    required this.extension,
    this.path,
  });

  String get baseName {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String get formatUpper => extension.toUpperCase();

  bool get isImage {
    const imageExts = {'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic', 'heif'};
    return imageExts.contains(extension.toLowerCase());
  }

  String get sizeLabel => formatByteSize(bytes.length);

  static String formatByteSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
