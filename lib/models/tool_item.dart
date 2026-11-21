import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';

enum ToolInputKind {
  singlePdf,
  multiPdf,
  twoPdfs,
  singleImage,
  multiImage,
  officeDoc,
  htmlOrText,
}

class ToolItem {
  final String id;
  final String title;
  final String shortTitle;
  final String description;
  final String category;
  final IconData icon;
  final Color accentColor;
  final ToolInputKind inputKind;
  final List<String> allowedExtensions;
  final String? badge;
  final bool isFeatured;

  const ToolItem({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.inputKind,
    this.allowedExtensions = const ['pdf'],
    this.badge,
    this.isFeatured = false,
  });

  bool get acceptsImages =>
      inputKind == ToolInputKind.singleImage ||
      inputKind == ToolInputKind.multiImage;

  bool get allowsMultiple =>
      inputKind == ToolInputKind.multiPdf ||
      inputKind == ToolInputKind.multiImage ||
      inputKind == ToolInputKind.twoPdfs;
}

class ToolSection {
  final String number;
  final String title;
  final String subtitle;
  final String categoryKey;
  final Color accentColor;

  const ToolSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.categoryKey,
    required this.accentColor,
  });
}

class ProcessResult {
  final String fileName;
  final String extension;
  final Uint8List bytes;
  final String? summaryNote;
  final int? originalBytesLength;
  final List<Uint8List> previewImages;
  final String? reportText;

  const ProcessResult({
    required this.fileName,
    required this.extension,
    required this.bytes,
    this.summaryNote,
    this.originalBytesLength,
    this.previewImages = const [],
    this.reportText,
  });

  String get fullFileName => '$fileName.$extension';

  bool get isImage {
    final ext = extension.toLowerCase();
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';
  }
}

class SavedFileEntry {
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime modifiedAt;

  const SavedFileEntry({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  }
}
