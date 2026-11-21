import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/tool_item.dart';

class HistoryService {
  static Future<Directory> getOutputDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final outDir = Directory('${docs.path}${Platform.pathSeparator}PDF_Studio_Pro');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }

  static Future<File> saveResult(ProcessResult result) async {
    final dir = await getOutputDirectory();
    final safeName = result.fileName
        .replaceAll(RegExp(r'[^\w\-. ]'), '_')
        .trim();
    final finalBase = safeName.isEmpty ? 'pdf_studio_output' : safeName;
    var candidate = File('${dir.path}${Platform.pathSeparator}$finalBase.${result.extension}');
    int counter = 1;
    while (await candidate.exists()) {
      candidate = File(
        '${dir.path}${Platform.pathSeparator}${finalBase}_$counter.${result.extension}',
      );
      counter++;
    }
    await candidate.writeAsBytes(result.bytes, flush: true);
    return candidate;
  }

  static Future<List<SavedFileEntry>> listSavedFiles() async {
    final dir = await getOutputDirectory();
    if (!await dir.exists()) return [];
    final entries = <SavedFileEntry>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        final name = entity.path.split(Platform.pathSeparator).last;
        entries.add(SavedFileEntry(
          name: name,
          path: entity.path,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ));
      }
    }
    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
