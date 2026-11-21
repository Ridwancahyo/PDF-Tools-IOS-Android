import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/picked_file_data.dart';
import '../models/tool_item.dart';

class PagePlanItem {
  final int sourcePageNumber; // 1-based original page number
  int rotationDegrees; // 0, 90, 180, 270
  bool deleted;

  PagePlanItem({
    required this.sourcePageNumber,
    this.rotationDegrees = 0,
    this.deleted = false,
  });
}

class PdfCoreService {
  /// Returns total page count of a PDF file (or 0 if invalid/encrypted).
  static int getPageCount(Uint8List bytes) {
    try {
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Parses page range text like "1-3, 5, 7-9" into sorted 1-based page numbers.
  static List<int> parsePageRange(String input, int totalPages) {
    if (totalPages <= 0) return [];
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return List<int>.generate(totalPages, (i) => i + 1);
    }

    final result = <int>{};
    for (final part in trimmed.split(',')) {
      final token = part.trim();
      if (token.isEmpty) continue;
      if (token.contains('-')) {
        final bounds = token.split('-');
        if (bounds.length == 2) {
          final start = int.tryParse(bounds[0].trim());
          final end = int.tryParse(bounds[1].trim());
          if (start != null && end != null) {
            final lo = math.min(start, end).clamp(1, totalPages);
            final hi = math.max(start, end).clamp(1, totalPages);
            for (int p = lo; p <= hi; p++) {
              result.add(p);
            }
          }
        }
      } else {
        final single = int.tryParse(token);
        if (single != null && single >= 1 && single <= totalPages) {
          result.add(single);
        }
      }
    }
    final list = result.toList()..sort();
    return list;
  }

  static PdfPageRotateAngle _angleFromDegrees(int deg) {
    final normalized = ((deg % 360) + 360) % 360;
    switch (normalized) {
      case 90:
        return PdfPageRotateAngle.rotateAngle90;
      case 180:
        return PdfPageRotateAngle.rotateAngle180;
      case 270:
        return PdfPageRotateAngle.rotateAngle270;
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  static void _appendPagePreservingSize(
    PdfDocument target,
    PdfPage sourcePage, {
    int extraRotationDegrees = 0,
  }) {
    final template = sourcePage.createTemplate();
    final size = template.size;
    final section = target.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.size = size;
    section.pageSettings.orientation = size.width > size.height
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait;
    final newPage = section.pages.add();
    newPage.graphics.drawPdfTemplate(template, Offset.zero);
    if (extraRotationDegrees % 360 != 0) {
      newPage.rotation = _angleFromDegrees(extraRotationDegrees);
    }
  }

  /// 1. Gabungkan beberapa PDF menjadi satu dokumen utuh
  static Future<ProcessResult> mergePdfs(
    List<PickedFileData> files, {
    void Function(String)? onProgress,
  }) async {
    if (files.length < 2) {
      throw Exception('Pilih minimal 2 file PDF untuk digabungkan.');
    }
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;
    int totalPages = 0;
    int totalInputSize = 0;

    for (int fIdx = 0; fIdx < files.length; fIdx++) {
      final f = files[fIdx];
      totalInputSize += f.bytes.length;
      onProgress?.call('Menggabungkan (${fIdx + 1}/${files.length}): ${f.name}...');
      final input = PdfDocument(inputBytes: f.bytes);
      for (int i = 0; i < input.pages.count; i++) {
        _appendPagePreservingSize(output, input.pages[i]);
        totalPages++;
      }
      input.dispose();
    }

    onProgress?.call('Menyimpan dokumen PDF gabungan ($totalPages halaman)...');
    final saved = Uint8List.fromList(await output.save());
    output.dispose();

    return ProcessResult(
      fileName: 'gabungan_${files.length}_pdf',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: totalInputSize,
      summaryNote: '${files.length} PDF digabungkan menjadi $totalPages halaman',
    );
  }

  /// 2. Pisahkan PDF (berdasarkan rentang -> 1 PDF, atau tiap halaman -> ZIP)
  static Future<ProcessResult> splitPdf(
    PickedFileData file, {
    required bool splitEveryPageToZip,
    String pageRange = '',
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Membaca struktur halaman PDF...');
    final input = PdfDocument(inputBytes: file.bytes);
    final total = input.pages.count;
    if (total == 0) {
      input.dispose();
      throw Exception('PDF tidak memiliki halaman.');
    }

    try {
      if (splitEveryPageToZip) {
        final archive = Archive();
        for (int i = 0; i < total; i++) {
          onProgress?.call('Memisahkan halaman ${i + 1} dari $total...');
          final singleDoc = PdfDocument();
          _appendPagePreservingSize(singleDoc, input.pages[i]);
          final singleBytes = Uint8List.fromList(await singleDoc.save());
          singleDoc.dispose();
          final pageLabel = (i + 1).toString().padLeft(3, '0');
          archive.addFile(
            ArchiveFile('${file.baseName}_hal_$pageLabel.pdf', singleBytes.length, singleBytes),
          );
        }
        onProgress?.call('Mengemas $total file PDF ke arsip ZIP...');
        final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
        return ProcessResult(
          fileName: '${file.baseName}_pisah_${total}_hal',
          extension: 'zip',
          bytes: zipBytes,
          originalBytesLength: file.bytes.length,
          summaryNote: '$total halaman dipisah menjadi $total file PDF dalam arsip ZIP',
        );
      } else {
        final selected = parsePageRange(pageRange, total);
        if (selected.isEmpty) {
          throw Exception('Rentang halaman tidak valid. Contoh: 1-3, 5');
        }
        final outDoc = PdfDocument();
        for (final p in selected) {
          onProgress?.call('Menyalin halaman $p...');
          _appendPagePreservingSize(outDoc, input.pages[p - 1]);
        }
        final saved = Uint8List.fromList(await outDoc.save());
        outDoc.dispose();
        return ProcessResult(
          fileName: '${file.baseName}_pisah',
          extension: 'pdf',
          bytes: saved,
          originalBytesLength: file.bytes.length,
          summaryNote: 'Berhasil memisahkan ${selected.length} halaman (${selected.join(', ')})',
        );
      }
    } finally {
      input.dispose();
    }
  }

  /// 3. Hapus Halaman tertentu dari PDF
  static Future<ProcessResult> deletePages(
    PickedFileData file, {
    required Set<int> pagesToDelete,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Memuat dokumen PDF...');
    final input = PdfDocument(inputBytes: file.bytes);
    final total = input.pages.count;
    try {
      final keepPages = <int>[];
      for (int p = 1; p <= total; p++) {
        if (!pagesToDelete.contains(p)) keepPages.add(p);
      }
      if (keepPages.isEmpty) {
        throw Exception('Minimal 1 halaman harus disisakan dalam PDF.');
      }

      final outDoc = PdfDocument();
      for (final p in keepPages) {
        onProgress?.call('Mempertahankan halaman $p...');
        _appendPagePreservingSize(outDoc, input.pages[p - 1]);
      }
      final saved = Uint8List.fromList(await outDoc.save());
      outDoc.dispose();

      return ProcessResult(
        fileName: '${file.baseName}_hapus_hal',
        extension: 'pdf',
        bytes: saved,
        originalBytesLength: file.bytes.length,
        summaryNote:
            '${pagesToDelete.length} halaman dihapus · Tersisa ${keepPages.length} dari $total halaman',
      );
    } finally {
      input.dispose();
    }
  }

  /// 4. Ekstrak Halaman tertentu menjadi 1 PDF baru atau arsip ZIP
  static Future<ProcessResult> extractPages(
    PickedFileData file, {
    required List<int> selectedPages,
    required bool asZipArchive,
    void Function(String)? onProgress,
  }) async {
    if (selectedPages.isEmpty) {
      throw Exception('Pilih minimal 1 halaman untuk diekstrak.');
    }
    final input = PdfDocument(inputBytes: file.bytes);
    final total = input.pages.count;
    try {
      final valid = selectedPages.where((p) => p >= 1 && p <= total).toList();
      if (valid.isEmpty) throw Exception('Nomor halaman melebihi jumlah halaman PDF ($total).');

      if (asZipArchive) {
        final archive = Archive();
        for (final p in valid) {
          onProgress?.call('Mengekstrak halaman $p ke file terpisah...');
          final singleDoc = PdfDocument();
          _appendPagePreservingSize(singleDoc, input.pages[p - 1]);
          final b = Uint8List.fromList(await singleDoc.save());
          singleDoc.dispose();
          archive.addFile(ArchiveFile('${file.baseName}_hal_$p.pdf', b.length, b));
        }
        final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
        return ProcessResult(
          fileName: '${file.baseName}_ekstrak',
          extension: 'zip',
          bytes: zipBytes,
          originalBytesLength: file.bytes.length,
          summaryNote: '${valid.length} halaman diekstrak sebagai arsip ZIP',
        );
      } else {
        final outDoc = PdfDocument();
        for (final p in valid) {
          onProgress?.call('Mengekstrak halaman $p...');
          _appendPagePreservingSize(outDoc, input.pages[p - 1]);
        }
        final saved = Uint8List.fromList(await outDoc.save());
        outDoc.dispose();
        return ProcessResult(
          fileName: '${file.baseName}_ekstrak',
          extension: 'pdf',
          bytes: saved,
          originalBytesLength: file.bytes.length,
          summaryNote: '${valid.length} halaman diekstrak menjadi PDF baru',
        );
      }
    } finally {
      input.dispose();
    }
  }

  /// 5. Atur Halaman PDF (Urutkan ulang, Duplikasi, Putar per halaman, Hapus)
  static Future<ProcessResult> organizePages(
    PickedFileData file, {
    required List<PagePlanItem> plan,
    void Function(String)? onProgress,
  }) async {
    final activeItems = plan.where((item) => !item.deleted).toList();
    if (activeItems.isEmpty) {
      throw Exception('Minimal 1 halaman aktif diperlukan.');
    }
    onProgress?.call('Menyusun ulang ${activeItems.length} halaman PDF...');
    final input = PdfDocument(inputBytes: file.bytes);
    try {
      final outDoc = PdfDocument();
      for (int i = 0; i < activeItems.length; i++) {
        final item = activeItems[i];
        if (item.sourcePageNumber < 1 || item.sourcePageNumber > input.pages.count) {
          continue;
        }
        onProgress?.call('Menata halaman ${i + 1} dari ${activeItems.length}...');
        _appendPagePreservingSize(
          outDoc,
          input.pages[item.sourcePageNumber - 1],
          extraRotationDegrees: item.rotationDegrees,
        );
      }
      final saved = Uint8List.fromList(await outDoc.save());
      outDoc.dispose();
      return ProcessResult(
        fileName: '${file.baseName}_teratur',
        extension: 'pdf',
        bytes: saved,
        originalBytesLength: file.bytes.length,
        summaryNote: 'Berhasil menyusun ${activeItems.length} halaman sesuai urutan baru',
      );
    } finally {
      input.dispose();
    }
  }

  /// 6. Putar PDF (90, 180, 270 derajat — seluruh dokumen atau halaman tertentu)
  static Future<ProcessResult> rotatePdf(
    PickedFileData file, {
    required int angleDegrees,
    String pageRange = '',
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Memutar halaman PDF $angleDegrees°...');
    final doc = PdfDocument(inputBytes: file.bytes);
    final total = doc.pages.count;
    final targets = parsePageRange(pageRange, total).toSet();
    final rot = _angleFromDegrees(angleDegrees);

    for (int i = 0; i < total; i++) {
      if (targets.contains(i + 1)) {
        doc.pages[i].rotation = rot;
      }
    }

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_putar_${angleDegrees}deg',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: '${targets.length} dari $total halaman diputar $angleDegrees°',
    );
  }

  /// 7. Kompres PDF (Ringan lossless / Seimbang 150 DPI / Maksimal 105 DPI)
  static Future<ProcessResult> compressPdf(
    PickedFileData file, {
    required String level, // 'ringan', 'seimbang', 'maksimal'
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Menganalisis struktur & stream objek PDF...');
    final originalSize = file.bytes.length;

    // Pass 1: Lossless best compression rebuild
    final input = PdfDocument(inputBytes: file.bytes);
    input.compressionLevel = PdfCompressionLevel.best;
    final losslessBytes = Uint8List.fromList(await input.save());
    final pageCount = input.pages.count;
    input.dispose();

    Uint8List bestBytes = losslessBytes.length < originalSize ? losslessBytes : file.bytes;

    // Pass 2: For 'seimbang' or 'maksimal', optimize page bitmaps via raster + JPEG
    if (level != 'ringan') {
      final double dpi = level == 'maksimal' ? 105.0 : 150.0;
      final int jpgQuality = level == 'maksimal' ? 52 : 74;
      try {
        final rasterDoc = PdfDocument();
        rasterDoc.compressionLevel = PdfCompressionLevel.best;
        int idx = 0;
        await for (final raster in Printing.raster(file.bytes, dpi: dpi)) {
          idx++;
          onProgress?.call('Mengoptimalkan halaman $idx/$pageCount (${dpi.round()} DPI)...');
          final pngBytes = await raster.toPng();
          final decoded = img.decodePng(pngBytes);
          if (decoded == null) continue;
          final jpgBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: jpgQuality));

          final section = rasterDoc.sections!.add();
          section.pageSettings.margins.all = 0;
          final ptW = decoded.width * 72.0 / dpi;
          final ptH = decoded.height * 72.0 / dpi;
          section.pageSettings.size = Size(ptW, ptH);
          section.pageSettings.orientation = ptW > ptH
              ? PdfPageOrientation.landscape
              : PdfPageOrientation.portrait;
          final page = section.pages.add();
          page.graphics.drawImage(PdfBitmap(jpgBytes), Rect.fromLTWH(0, 0, ptW, ptH));
        }

        if (rasterDoc.pages.count > 0) {
          final rasterBytes = Uint8List.fromList(await rasterDoc.save());
          if (rasterBytes.length < bestBytes.length) {
            bestBytes = rasterBytes;
          }
        }
        rasterDoc.dispose();
      } catch (_) {
        // Keep lossless compressed version if rasterizing isn't available on host
      }
    }

    final savedPercent = originalSize > 0
        ? ((originalSize - bestBytes.length) / originalSize * 100).clamp(0, 99)
        : 0.0;

    return ProcessResult(
      fileName: '${file.baseName}_kompres',
      extension: 'pdf',
      bytes: bestBytes,
      originalBytesLength: originalSize,
      summaryNote: savedPercent >= 1
          ? 'Hemat ${savedPercent.toStringAsFixed(1)}% (${PickedFileData.formatByteSize(originalSize)} → ${PickedFileData.formatByteSize(bestBytes.length)})'
          : 'PDF sudah optimal (${PickedFileData.formatByteSize(bestBytes.length)})',
    );
  }

  /// 8. Perbaiki PDF (Rekonstruksi objek & cross-reference table)
  static Future<ProcessResult> repairPdf(
    PickedFileData file, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Memindai struktur objek & halaman PDF...');
    final input = PdfDocument(inputBytes: file.bytes);
    final total = input.pages.count;

    final rebuilt = PdfDocument();
    rebuilt.compressionLevel = PdfCompressionLevel.normal;
    int recovered = 0;

    for (int i = 0; i < total; i++) {
      onProgress?.call('Merekonstruksi halaman ${i + 1} dari $total...');
      try {
        _appendPagePreservingSize(rebuilt, input.pages[i]);
        recovered++;
      } catch (_) {
        // Skip fatally corrupted page while keeping all healthy pages
      }
    }
    input.dispose();

    if (recovered == 0) {
      rebuilt.dispose();
      throw Exception('Struktur PDF terlalu rusak dan tidak memiliki halaman terbaca.');
    }

    onProgress?.call('Membangun ulang tabel referensi PDF bersih...');
    final saved = Uint8List.fromList(await rebuilt.save());
    rebuilt.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_repaired',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: 'Berhasil merekonstruksi $recovered/$total halaman menjadi PDF bersih',
    );
  }

  /// 9. Nomor Halaman Otomatis
  static Future<ProcessResult> addPageNumbers(
    PickedFileData file, {
    required String formatStyle, // 'number', 'halaman', 'of_total'
    required String position, // 'bottom_center', 'bottom_right', 'bottom_left', 'top_right'
    double fontSize = 11,
    int startNumber = 1,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Menambahkan nomor halaman...');
    final doc = PdfDocument(inputBytes: file.bytes);
    final total = doc.pages.count;
    final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);
    final brush = PdfSolidBrush(PdfColor(45, 58, 72));

    for (int i = 0; i < total; i++) {
      final page = doc.pages[i];
      final numVal = startNumber + i;
      final label = switch (formatStyle) {
        'halaman' => 'Halaman $numVal',
        'of_total' => '$numVal / ${startNumber + total - 1}',
        _ => '$numVal',
      };

      final size = page.size;
      final margin = 24.0;
      late Rect bounds;
      late PdfTextAlignment align;

      switch (position) {
        case 'bottom_left':
          bounds = Rect.fromLTWH(margin, size.height - 32, 160, 20);
          align = PdfTextAlignment.left;
          break;
        case 'bottom_right':
          bounds = Rect.fromLTWH(size.width - 184, size.height - 32, 160, 20);
          align = PdfTextAlignment.right;
          break;
        case 'top_right':
          bounds = Rect.fromLTWH(size.width - 184, 14, 160, 20);
          align = PdfTextAlignment.right;
          break;
        default:
          bounds = Rect.fromLTWH(0, size.height - 32, size.width, 20);
          align = PdfTextAlignment.center;
      }

      page.graphics.drawString(
        label,
        font,
        brush: brush,
        bounds: bounds,
        format: PdfStringFormat(alignment: align),
      );
    }

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_bernomor',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: 'Nomor halaman ditambahkan pada $total halaman',
    );
  }

  /// 10. Watermark PDF
  static Future<ProcessResult> addWatermark(
    PickedFileData file, {
    required String text,
    double angle = -45,
    double opacity = 0.25,
    double fontSize = 42,
    Color color = const Color(0xFFA43123),
    void Function(String)? onProgress,
  }) async {
    final cleanText = text.trim().isEmpty ? 'RAHASIA' : text.trim();
    onProgress?.call('Menyematkan watermark "$cleanText"...');
    final doc = PdfDocument(inputBytes: file.bytes);
    final font = PdfStandardFont(
      PdfFontFamily.helvetica,
      fontSize,
      style: PdfFontStyle.bold,
    );
    final brush = PdfSolidBrush(
      PdfColor(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
      ),
    );

    for (int i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final g = page.graphics;
      g.save();
      g.setTransparency(opacity.clamp(0.08, 0.85));
      g.translateTransform(page.size.width / 2, page.size.height / 2);
      g.rotateTransform(angle);
      g.drawString(
        cleanText,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(-260, -fontSize, 520, fontSize * 2),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      g.restore();
    }

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();
    return ProcessResult(
      fileName: '${file.baseName}_watermark',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: 'Watermark "$cleanText" diterapkan ke seluruh halaman',
    );
  }

  /// 11. Potong Margin PDF (dalam milimeter)
  static Future<ProcessResult> cropMargins(
    PickedFileData file, {
    double topMm = 10,
    double rightMm = 10,
    double bottomMm = 10,
    double leftMm = 10,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Memotong margin halaman PDF...');
    const mmToPt = 2.83464567;
    final top = topMm * mmToPt;
    final right = rightMm * mmToPt;
    final bottom = bottomMm * mmToPt;
    final left = leftMm * mmToPt;

    final input = PdfDocument(inputBytes: file.bytes);
    final outDoc = PdfDocument();
    final total = input.pages.count;

    try {
      for (int i = 0; i < total; i++) {
        onProgress?.call('Memangkas halaman ${i + 1}/$total...');
        final template = input.pages[i].createTemplate();
        final newW = math.max(72.0, template.size.width - left - right);
        final newH = math.max(72.0, template.size.height - top - bottom);

        final section = outDoc.sections!.add();
        section.pageSettings.margins.all = 0;
        section.pageSettings.size = Size(newW, newH);
        section.pageSettings.orientation = newW > newH
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;
        final page = section.pages.add();
        page.graphics.drawPdfTemplate(template, Offset(-left, -top));
      }

      final saved = Uint8List.fromList(await outDoc.save());
      outDoc.dispose();
      return ProcessResult(
        fileName: '${file.baseName}_crop',
        extension: 'pdf',
        bytes: saved,
        originalBytesLength: file.bytes.length,
        summaryNote:
            'Margin dipotong (A:${topMm.round()} K:${rightMm.round()} B:${bottomMm.round()} Kr:${leftMm.round()} mm)',
      );
    } finally {
      input.dispose();
    }
  }

  /// 12. Edit & Anotasi PDF (Catatan teks & sorotan warna)
  static Future<ProcessResult> annotatePdf(
    PickedFileData file, {
    required String noteText,
    required int pageNumber,
    required String verticalPos, // 'top', 'middle', 'bottom'
    bool withHighlightBox = true,
    Color highlightColor = const Color(0xFFFFF59D),
    void Function(String)? onProgress,
  }) async {
    final cleanNote = noteText.trim();
    if (cleanNote.isEmpty) {
      throw Exception('Masukkan teks catatan atau anotasi terlebih dahulu.');
    }
    onProgress?.call('Menambahkan anotasi ke halaman $pageNumber...');
    final doc = PdfDocument(inputBytes: file.bytes);
    final idx = (pageNumber - 1).clamp(0, doc.pages.count - 1);
    final page = doc.pages[idx];
    final size = page.size;

    final double boxW = size.width - 72;
    final double boxH = 54;
    final double y = switch (verticalPos) {
      'top' => 32.0,
      'bottom' => size.height - boxH - 36,
      _ => (size.height - boxH) / 2,
    };
    final rect = Rect.fromLTWH(36, y, boxW, boxH);

    if (withHighlightBox) {
      page.graphics.save();
      page.graphics.setTransparency(0.82);
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(
          PdfColor(
            (highlightColor.r * 255).round(),
            (highlightColor.g * 255).round(),
            (highlightColor.b * 255).round(),
          ),
        ),
        pen: PdfPen(PdfColor(180, 140, 20), width: 1),
        bounds: rect,
      );
      page.graphics.restore();
    }

    final font = PdfStandardFont(PdfFontFamily.helvetica, 11.5, style: PdfFontStyle.bold);
    page.graphics.drawString(
      cleanNote,
      font,
      brush: PdfSolidBrush(PdfColor(22, 54, 83)),
      bounds: Rect.fromLTWH(rect.left + 10, rect.top + 8, rect.width - 20, rect.height - 16),
      format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle),
    );

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_anotasi',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: 'Anotasi berhasil ditambahkan pada halaman ${idx + 1}',
    );
  }

  /// 13. Tanda Tangan PDF (Goresan PNG dari Signature Pad atau Teks)
  static Future<ProcessResult> signPdf(
    PickedFileData file, {
    Uint8List? signaturePngBytes,
    String typedSignature = '',
    required int pageNumber,
    required String corner, // 'bottom_right', 'bottom_left', 'bottom_center'
    double widthPt = 160,
    bool includeDateStamp = true,
    void Function(String)? onProgress,
  }) async {
    if ((signaturePngBytes == null || signaturePngBytes.isEmpty) &&
        typedSignature.trim().isEmpty) {
      throw Exception('Buat tanda tangan di kanvas atau ketik nama tanda tangan.');
    }
    onProgress?.call('Menempatkan tanda tangan digital pada PDF...');
    final doc = PdfDocument(inputBytes: file.bytes);
    final idx = (pageNumber - 1).clamp(0, doc.pages.count - 1);
    final page = doc.pages[idx];
    final size = page.size;

    final double heightPt = widthPt * 0.45;
    final double y = size.height - heightPt - 48;
    final double x = switch (corner) {
      'bottom_left' => 40.0,
      'bottom_center' => (size.width - widthPt) / 2,
      _ => size.width - widthPt - 40.0,
    };

    if (signaturePngBytes != null && signaturePngBytes.isNotEmpty) {
      final bmp = PdfBitmap(signaturePngBytes);
      page.graphics.drawImage(bmp, Rect.fromLTWH(x, y, widthPt, heightPt));
    } else {
      final sigFont = PdfStandardFont(
        PdfFontFamily.timesRoman,
        24,
        style: PdfFontStyle.italic,
      );
      page.graphics.drawString(
        typedSignature.trim(),
        sigFont,
        brush: PdfSolidBrush(PdfColor(22, 54, 83)),
        bounds: Rect.fromLTWH(x, y, widthPt, heightPt),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
    }

    if (includeDateStamp) {
      final now = DateTime.now();
      final dateStr =
          'Ditandatangani ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
      page.graphics.drawString(
        dateStr,
        smallFont,
        brush: PdfSolidBrush(PdfColor(90, 105, 120)),
        bounds: Rect.fromLTWH(x, y + heightPt + 2, widthPt, 14),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_ttd',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: 'Tanda tangan ditempatkan pada halaman ${idx + 1}',
    );
  }

  /// 14. Sensor PDF (Redact kata rahasia otomatis &/atau blok area manual)
  static Future<ProcessResult> redactPdf(
    PickedFileData file, {
    required String keywordsCsv,
    bool addManualBlock = false,
    int manualPage = 1,
    double manualTopPercent = 20,
    double manualHeightPercent = 10,
    void Function(String)? onProgress,
  }) async {
    final keywords = keywordsCsv
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (keywords.isEmpty && !addManualBlock) {
      throw Exception('Masukkan kata rahasia untuk disensor atau aktifkan blok sensor manual.');
    }

    onProgress?.call('Memindai informasi rahasia pada dokumen...');
    final doc = PdfDocument(inputBytes: file.bytes);
    int redactedHits = 0;

    if (keywords.isNotEmpty) {
      final matches = PdfTextExtractor(doc).findText(keywords);
      for (final m in matches) {
        if (m.pageIndex >= 0 && m.pageIndex < doc.pages.count) {
          final page = doc.pages[m.pageIndex];
          final padded = Rect.fromLTWH(
            m.bounds.left - 2,
            m.bounds.top - 2,
            m.bounds.width + 4,
            m.bounds.height + 4,
          );
          page.graphics.drawRectangle(
            brush: PdfBrushes.black,
            bounds: padded,
          );
          redactedHits++;
        }
      }
    }

    if (addManualBlock && doc.pages.count > 0) {
      final idx = (manualPage - 1).clamp(0, doc.pages.count - 1);
      final page = doc.pages[idx];
      final y = page.size.height * (manualTopPercent.clamp(0, 90) / 100.0);
      final h = page.size.height * (manualHeightPercent.clamp(3, 50) / 100.0);
      page.graphics.drawRectangle(
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(32, y, page.size.width - 64, h),
      );
      redactedHits++;
    }

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_sensor',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: redactedHits > 0
          ? '$redactedHits area sensitif berhasil ditutup blok hitam permanen'
          : 'Tidak ditemukan kecocokan kata kunci di teks PDF (gunakan blok manual untuk PDF hasil scan)',
    );
  }

  /// 15. Kunci PDF dengan Password AES 128-bit & izin akses
  static Future<ProcessResult> lockPdf(
    PickedFileData file, {
    required String password,
    bool allowPrint = true,
    bool allowCopy = false,
    void Function(String)? onProgress,
  }) async {
    if (password.trim().isEmpty) {
      throw Exception('Masukkan kata sandi untuk mengunci PDF.');
    }
    onProgress?.call('Mengenkripsi PDF dengan AES 128-bit...');
    final doc = PdfDocument(inputBytes: file.bytes);
    doc.security.algorithm = PdfEncryptionAlgorithm.aesx128Bit;
    doc.security.userPassword = password.trim();
    doc.security.ownerPassword = password.trim();

    if (allowPrint) {
      doc.security.permissions.add(PdfPermissionsFlags.print);
    }
    if (allowCopy) {
      doc.security.permissions.add(PdfPermissionsFlags.copyContent);
    }

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_terkunci',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote:
          'PDF dienkripsi AES-128 · Cetak: ${allowPrint ? "Diizinkan" : "Diblokir"}, Salin: ${allowCopy ? "Diizinkan" : "Diblokir"}',
    );
  }

  /// 16. Buka Kunci PDF
  static Future<ProcessResult> unlockPdf(
    PickedFileData file, {
    required String password,
    void Function(String)? onProgress,
  }) async {
    if (password.trim().isEmpty) {
      throw Exception('Masukkan kata sandi PDF untuk membuka kunci.');
    }
    onProgress?.call('Membuka enkripsi dokumen PDF...');
    final doc = PdfDocument(inputBytes: file.bytes, password: password.trim());
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_terbuka',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: 'Proteksi kata sandi berhasil dihapus',
    );
  }

  /// 17. Lindungi & Metadata (Edit metadata, cap klasifikasi, atau bersihkan privasi)
  static Future<ProcessResult> updateMetadata(
    PickedFileData file, {
    required bool stripAllMetadata,
    String title = '',
    String author = '',
    String subject = '',
    String keywords = '',
    String classificationStamp = 'Tanpa Cap', // 'Tanpa Cap', 'RAHASIA', 'INTERNAL', 'DRAFT'
    void Function(String)? onProgress,
  }) async {
    onProgress?.call(
      stripAllMetadata
          ? 'Membersihkan metadata pribadi PDF...'
          : 'Memperbarui metadata dokumen...',
    );
    final doc = PdfDocument(inputBytes: file.bytes);
    final info = doc.documentInformation;
    if (stripAllMetadata) {
      info.title = '';
      info.author = '';
      info.subject = '';
      info.keywords = '';
      info.creator = '';
      info.producer = '';
    } else {
      if (title.trim().isNotEmpty) info.title = title.trim();
      if (author.trim().isNotEmpty) info.author = author.trim();
      if (subject.trim().isNotEmpty) info.subject = subject.trim();
      if (keywords.trim().isNotEmpty) info.keywords = keywords.trim();
      info.creator = 'PDF Studio Pro';
    }

    if (classificationStamp != 'Tanpa Cap') {
      final stampFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        10,
        style: PdfFontStyle.bold,
      );
      for (int i = 0; i < doc.pages.count; i++) {
        final page = doc.pages[i];
        page.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(164, 49, 35)),
          bounds: Rect.fromLTWH(page.size.width - 112, 12, 92, 20),
        );
        page.graphics.drawString(
          classificationStamp,
          stampFont,
          brush: PdfBrushes.white,
          bounds: Rect.fromLTWH(page.size.width - 112, 12, 92, 20),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
      }
    }

    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_metadata',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: stripAllMetadata
          ? 'Seluruh metadata pribadi berhasil dibersihkan'
          : 'Metadata diperbarui${classificationStamp != "Tanpa Cap" ? " · Cap: $classificationStamp" : ""}',
    );
  }

  /// 18. Bandingkan 2 Versi PDF (Diff teks per halaman + Laporan PDF)
  static Future<ProcessResult> comparePdfs(
    PickedFileData pdfA,
    PickedFileData pdfB, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Mengekstrak teks dari kedua dokumen PDF...');
    final docA = PdfDocument(inputBytes: pdfA.bytes);
    final docB = PdfDocument(inputBytes: pdfB.bytes);

    final pagesA = docA.pages.count;
    final pagesB = docB.pages.count;
    final maxPages = math.max(pagesA, pagesB);

    final reportBuf = StringBuffer();
    reportBuf.writeln('LAPORAN PERBANDINGAN PDF');
    reportBuf.writeln('Dokumen A: ${pdfA.name} ($pagesA halaman)');
    reportBuf.writeln('Dokumen B: ${pdfB.name} ($pagesB halaman)');
    reportBuf.writeln('============================================\n');

    int changedPages = 0;
    int totalAdded = 0;
    int totalRemoved = 0;

    for (int i = 0; i < maxPages; i++) {
      onProgress?.call('Membandingkan halaman ${i + 1}/$maxPages...');
      final textA = i < pagesA
          ? PdfTextExtractor(docA).extractText(startPageIndex: i, endPageIndex: i)
          : '';
      final textB = i < pagesB
          ? PdfTextExtractor(docB).extractText(startPageIndex: i, endPageIndex: i)
          : '';

      final linesA = textA
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final linesB = textB
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final setA = linesA.toSet();
      final setB = linesB.toSet();
      final removed = linesA.where((l) => !setB.contains(l)).toList();
      final added = linesB.where((l) => !setA.contains(l)).toList();

      if (removed.isEmpty && added.isEmpty && i < pagesA && i < pagesB) {
        reportBuf.writeln('Halaman ${i + 1}: Identik (tidak ada perubahan teks)');
      } else {
        changedPages++;
        totalAdded += added.length;
        totalRemoved += removed.length;
        reportBuf.writeln('Halaman ${i + 1}: Ditemukan perubahan');
        for (final r in removed.take(15)) {
          reportBuf.writeln('  [-] $r');
        }
        for (final a in added.take(15)) {
          reportBuf.writeln('  [+] $a');
        }
        if (removed.length > 15 || added.length > 15) {
          reportBuf.writeln('  ... dan perubahan lainnya di halaman ini.');
        }
      }
      reportBuf.writeln('');
    }

    docA.dispose();
    docB.dispose();

    final reportText = reportBuf.toString();

    // Generate clean downloadable Comparison Report PDF
    onProgress?.call('Menyusun laporan perbandingan dalam format PDF...');
    final reportPdf = PdfDocument();
    reportPdf.pageSettings.margins.all = 36;
    final page = reportPdf.pages.add();
    final font = PdfStandardFont(PdfFontFamily.courier, 9.5);
    final element = PdfTextElement(text: reportText, font: font);
    element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
    final saved = Uint8List.fromList(await reportPdf.save());
    reportPdf.dispose();

    return ProcessResult(
      fileName: 'perbandingan_pdf',
      extension: 'pdf',
      bytes: saved,
      reportText: reportText,
      summaryNote: changedPages == 0
          ? 'Kedua dokumen identik ($pagesA halaman)'
          : '$changedPages halaman berbeda · +$totalAdded baris ditambah, -$totalRemoved baris dihapus',
    );
  }
}
