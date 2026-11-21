import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';
import '../models/picked_file_data.dart';
import '../models/tool_item.dart';

class OfficeConvertService {
  static String _xmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Strips characters outside printable ASCII/Latin-1 that Helvetica PDF font cannot draw.
  static String _sanitizeForPdfFont(String input) {
    return input
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2022', '*')
        .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\xFF]'), ' ');
  }

  // ===========================================================================
  // KONVERSI KE PDF (5 alat)
  // ===========================================================================

  /// 1. JPG / PNG / WebP / HEIC ke PDF
  static Future<ProcessResult> imagesToPdf(
    List<PickedFileData> images, {
    String pageSize = 'A4', // 'A4', 'Letter', 'Fit'
    bool landscape = false,
    double marginPt = 20,
    void Function(String)? onProgress,
  }) async {
    if (images.isEmpty) {
      throw Exception('Pilih minimal 1 gambar untuk dikonversi ke PDF.');
    }

    final doc = PdfDocument();
    int totalInput = 0;

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      totalInput += image.bytes.length;
      onProgress?.call('Menambahkan gambar ${i + 1}/${images.length}: ${image.name}...');

      Uint8List? encodedBytes;
      final ext = image.extension.toLowerCase();
      if (ext == 'heic' || ext == 'heif') {
        final dir = await getTemporaryDirectory();
        final tmp = File(
          '${dir.path}${Platform.pathSeparator}j2p_${DateTime.now().microsecondsSinceEpoch}.$ext',
        );
        await tmp.writeAsBytes(image.bytes, flush: true);
        encodedBytes = await FlutterImageCompress.compressWithFile(
          tmp.absolute.path,
          format: CompressFormat.jpeg,
          quality: 92,
        );
      }
      if (encodedBytes == null) {
        final decoded = img.decodeImage(image.bytes);
        if (decoded == null) continue;
        encodedBytes = Uint8List.fromList(
          img.encodeJpg(img.bakeOrientation(decoded), quality: 92),
        );
      }

      final bmp = PdfBitmap(encodedBytes);
      final section = doc.sections!.add();
      section.pageSettings.margins.all = marginPt;

      if (pageSize == 'Fit') {
        final w = bmp.width.toDouble() + marginPt * 2;
        final h = bmp.height.toDouble() + marginPt * 2;
        section.pageSettings.size = Size(w, h);
        section.pageSettings.orientation =
            w > h ? PdfPageOrientation.landscape : PdfPageOrientation.portrait;
      } else {
        final baseSize = pageSize == 'Letter' ? PdfPageSize.letter : PdfPageSize.a4;
        section.pageSettings.size = baseSize;
        section.pageSettings.orientation = landscape
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;
      }

      final page = section.pages.add();
      final client = page.getClientSize();
      final scale = math.min(client.width / bmp.width, client.height / bmp.height);
      final drawW = bmp.width * scale;
      final drawH = bmp.height * scale;
      page.graphics.drawImage(
        bmp,
        Rect.fromLTWH(
          (client.width - drawW) / 2,
          (client.height - drawH) / 2,
          drawW,
          drawH,
        ),
      );
    }

    if (doc.pages.count == 0) {
      doc.dispose();
      throw Exception('Tidak ada gambar valid yang dapat dimasukkan ke PDF.');
    }

    onProgress?.call('Menyimpan dokumen PDF...');
    final saved = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: images.length == 1 ? images.first.baseName : 'foto_ke_pdf_${images.length}',
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: totalInput,
      summaryNote: '${images.length} gambar berhasil disusun menjadi PDF ($pageSize)',
    );
  }

  /// 2. Word (.docx / .txt / .md) ke PDF
  static Future<ProcessResult> wordToPdf(
    PickedFileData file, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Membaca isi dokumen ${file.name}...');
    final paragraphs = <String>[];

    if (file.extension.toLowerCase() == 'docx') {
      final archive = ZipDecoder().decodeBytes(file.bytes);
      final docEntry = archive.files.cast<ArchiveFile?>().firstWhere(
            (f) => f != null && f.name == 'word/document.xml',
            orElse: () => null,
          );
      if (docEntry == null) {
        throw Exception('File .docx tidak valid (word/document.xml tidak ditemukan).');
      }
      final xmlStr = utf8.decode(docEntry.content as List<int>, allowMalformed: true);
      final xmlDoc = XmlDocument.parse(xmlStr);
      for (final p in xmlDoc.findAllElements('w:p')) {
        final line = p.findAllElements('w:t').map((t) => t.innerText).join();
        paragraphs.add(line);
      }
    } else {
      final text = utf8.decode(file.bytes, allowMalformed: true);
      paragraphs.addAll(text.split(RegExp(r'\r?\n')));
    }

    final bodyText = _sanitizeForPdfFont(
      paragraphs.isEmpty ? '(Dokumen kosong)' : paragraphs.join('\n'),
    );

    onProgress?.call('Merender halaman PDF rapi...');
    final pdf = PdfDocument();
    pdf.pageSettings.size = PdfPageSize.a4;
    pdf.pageSettings.margins.all = 42;
    final page = pdf.pages.add();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 11);

    final element = PdfTextElement(
      text: bodyText,
      font: font,
      brush: PdfSolidBrush(PdfColor(25, 35, 45)),
    );
    element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    final pageCount = pdf.pages.count;
    final saved = Uint8List.fromList(await pdf.save());
    pdf.dispose();

    return ProcessResult(
      fileName: file.baseName,
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: 'Berhasil dikonversi dari ${file.formatUpper} ke PDF ($pageCount halaman)',
    );
  }

  /// 3. Excel (.xlsx / .csv) ke PDF tabel lanskap
  static Future<ProcessResult> excelToPdf(
    PickedFileData file, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Membaca data tabel ${file.name}...');
    final rows = <List<String>>[];

    if (file.extension.toLowerCase() == 'csv') {
      final raw = utf8.decode(file.bytes, allowMalformed: true);
      for (final line in raw.split(RegExp(r'\r?\n'))) {
        if (line.trim().isEmpty) continue;
        rows.add(_parseCsvRow(line));
      }
    } else if (file.extension.toLowerCase() == 'xlsx') {
      final archive = ZipDecoder().decodeBytes(file.bytes);
      final sharedStrings = <String>[];
      final ssFile = archive.files.cast<ArchiveFile?>().firstWhere(
            (f) => f != null && f.name == 'xl/sharedStrings.xml',
            orElse: () => null,
          );
      if (ssFile != null) {
        final ssXml = XmlDocument.parse(
          utf8.decode(ssFile.content as List<int>, allowMalformed: true),
        );
        for (final si in ssXml.findAllElements('si')) {
          sharedStrings.add(si.findAllElements('t').map((e) => e.innerText).join());
        }
      }

      final sheetFile = archive.files.cast<ArchiveFile?>().firstWhere(
            (f) => f != null && f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'),
            orElse: () => null,
          );
      if (sheetFile == null) {
        throw Exception('Worksheet tidak ditemukan dalam file .xlsx.');
      }

      final sheetXml = XmlDocument.parse(
        utf8.decode(sheetFile.content as List<int>, allowMalformed: true),
      );
      for (final rowEl in sheetXml.findAllElements('row')) {
        final rowCells = <String>[];
        for (final c in rowEl.findElements('c')) {
          final type = c.getAttribute('t');
          String val = '';
          if (type == 's') {
            final idx = int.tryParse(c.getElement('v')?.innerText ?? '') ?? -1;
            if (idx >= 0 && idx < sharedStrings.length) {
              val = sharedStrings[idx];
            }
          } else if (type == 'inlineStr') {
            val = c.findAllElements('t').map((e) => e.innerText).join();
          } else {
            val = c.getElement('v')?.innerText ?? '';
          }
          rowCells.add(val);
        }
        if (rowCells.any((e) => e.trim().isNotEmpty)) {
          rows.add(rowCells);
        }
      }
    } else {
      throw Exception('Format didukung: .xlsx dan .csv');
    }

    if (rows.isEmpty) {
      throw Exception('Tidak ada data tabel yang ditemukan pada file spreadsheet.');
    }

    final colCount = rows.fold<int>(1, (maxC, r) => math.max(maxC, r.length)).clamp(1, 20);
    onProgress?.call('Menyusun tabel PDF lanskap (${rows.length} baris × $colCount kolom)...');

    final pdf = PdfDocument();
    pdf.pageSettings.size = PdfPageSize.a4;
    pdf.pageSettings.orientation = PdfPageOrientation.landscape;
    pdf.pageSettings.margins.all = 28;
    final page = pdf.pages.add();

    final grid = PdfGrid();
    grid.columns.add(count: colCount);
    grid.style = PdfGridStyle(
      font: PdfStandardFont(PdfFontFamily.helvetica, 9),
      cellPadding: PdfPaddings(left: 5, right: 5, top: 4, bottom: 4),
    );

    final headerRow = grid.headers.add(1)[0];
    headerRow.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(PdfColor(22, 54, 83)),
      textBrush: PdfBrushes.white,
      font: PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold),
    );
    for (int c = 0; c < colCount; c++) {
      headerRow.cells[c].value =
          _sanitizeForPdfFont(c < rows.first.length ? rows.first[c] : '');
    }

    for (int r = 1; r < rows.length; r++) {
      final gridRow = grid.rows.add();
      if (r.isEven) {
        gridRow.style.backgroundBrush = PdfSolidBrush(PdfColor(248, 246, 240));
      }
      for (int c = 0; c < colCount; c++) {
        gridRow.cells[c].value =
            _sanitizeForPdfFont(c < rows[r].length ? rows[r][c] : '');
      }
    }

    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    final pagesCount = pdf.pages.count;
    final saved = Uint8List.fromList(await pdf.save());
    pdf.dispose();

    return ProcessResult(
      fileName: file.baseName,
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: '${rows.length} baris spreadsheet dikonversi ke PDF lanskap ($pagesCount halaman)',
    );
  }

  /// 4. PowerPoint (.pptx) ke PDF
  static Future<ProcessResult> pptToPdf(
    PickedFileData file, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Membaca slide presentasi ${file.name}...');
    final archive = ZipDecoder().decodeBytes(file.bytes);
    final slideFiles = archive.files
        .where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
        .toList();

    if (slideFiles.isEmpty) {
      throw Exception('Slide tidak ditemukan dalam file .pptx.');
    }

    slideFiles.sort((a, b) {
      final na = int.tryParse(RegExp(r'(\d+)').firstMatch(a.name)?.group(1) ?? '0') ?? 0;
      final nb = int.tryParse(RegExp(r'(\d+)').firstMatch(b.name)?.group(1) ?? '0') ?? 0;
      return na.compareTo(nb);
    });

    final pdf = PdfDocument();
    pdf.pageSettings.size = const Size(960, 540); // 16:9 widescreen slide
    pdf.pageSettings.orientation = PdfPageOrientation.landscape;
    pdf.pageSettings.margins.all = 0;

    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 14);
    final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 10);

    for (int i = 0; i < slideFiles.length; i++) {
      onProgress?.call('Mengonversi slide ${i + 1}/${slideFiles.length}...');
      final xmlDoc = XmlDocument.parse(
        utf8.decode(slideFiles[i].content as List<int>, allowMalformed: true),
      );
      final texts = <String>[];
      for (final p in xmlDoc.findAllElements('a:p')) {
        final line = p.findAllElements('a:t').map((t) => t.innerText).join().trim();
        if (line.isNotEmpty) texts.add(line);
      }

      final page = pdf.pages.add();
      final g = page.graphics;
      // Clean slide canvas + top accent bar
      g.drawRectangle(
        brush: PdfSolidBrush(PdfColor(250, 248, 242)),
        bounds: const Rect.fromLTWH(0, 0, 960, 540),
      );
      g.drawRectangle(
        brush: PdfSolidBrush(PdfColor(22, 54, 83)),
        bounds: const Rect.fromLTWH(0, 0, 960, 12),
      );

      final slideTitle = texts.isNotEmpty ? _sanitizeForPdfFont(texts.first) : 'Slide ${i + 1}';
      g.drawString(
        slideTitle,
        titleFont,
        brush: PdfSolidBrush(PdfColor(22, 54, 83)),
        bounds: const Rect.fromLTWH(48, 42, 864, 54),
      );

      if (texts.length > 1) {
        final body = _sanitizeForPdfFont(texts.sublist(1).map((e) => '• $e').join('\n\n'));
        g.drawString(
          body,
          bodyFont,
          brush: PdfSolidBrush(PdfColor(45, 58, 72)),
          bounds: const Rect.fromLTWH(56, 114, 848, 376),
        );
      }

      g.drawString(
        'Slide ${i + 1} / ${slideFiles.length}',
        footerFont,
        brush: PdfSolidBrush(PdfColor(110, 125, 140)),
        bounds: const Rect.fromLTWH(780, 504, 140, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
    }

    final saved = Uint8List.fromList(await pdf.save());
    pdf.dispose();

    return ProcessResult(
      fileName: file.baseName,
      extension: 'pdf',
      bytes: saved,
      originalBytesLength: file.bytes.length,
      summaryNote: '${slideFiles.length} slide PowerPoint berhasil diubah menjadi PDF 16:9',
    );
  }

  /// 5. HTML ke PDF (File .html atau kode HTML langsung)
  static Future<ProcessResult> htmlToPdf({
    PickedFileData? file,
    String htmlCode = '',
    void Function(String)? onProgress,
  }) async {
    final rawHtml = htmlCode.trim().isNotEmpty
        ? htmlCode.trim()
        : (file != null ? utf8.decode(file.bytes, allowMalformed: true) : '');

    if (rawHtml.isEmpty) {
      throw Exception('Pilih file HTML atau tempel kode HTML terlebih dahulu.');
    }

    onProgress?.call('Merender HTML menjadi dokumen PDF...');
    Uint8List pdfBytes;
    try {
      // ignore: deprecated_member_use
      pdfBytes = await Printing.convertHtml(html: rawHtml);
    } catch (_) {
      // Pure Dart fallback stripping tags into formatted PDF text
      final plain = rawHtml
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</p>|</div>|</h[1-6]>|</li>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<style[\s\S]*?</style>|<script[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .trim();

      final doc = PdfDocument();
      doc.pageSettings.margins.all = 36;
      final page = doc.pages.add();
      PdfTextElement(
        text: _sanitizeForPdfFont(plain.isEmpty ? rawHtml : plain),
        font: PdfStandardFont(PdfFontFamily.helvetica, 11),
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      );
      pdfBytes = Uint8List.fromList(await doc.save());
      doc.dispose();
    }

    return ProcessResult(
      fileName: file?.baseName ?? 'html_dokumen',
      extension: 'pdf',
      bytes: pdfBytes,
      originalBytesLength: file?.bytes.length ?? utf8.encode(rawHtml).length,
      summaryNote: 'Halaman HTML berhasil dikonversi ke PDF',
    );
  }

  // ===========================================================================
  // KONVERSI DARI PDF (4 alat)
  // ===========================================================================

  /// 6. PDF ke JPG / PNG HD (1 halaman langsung gambar, >1 halaman arsip ZIP + galeri)
  static Future<ProcessResult> pdfToImages(
    PickedFileData file, {
    required String targetFormat, // 'jpg' or 'png'
    double dpi = 200,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Merender halaman PDF (${dpi.round()} DPI)...');
    final images = <Uint8List>[];
    int pageNum = 0;

    await for (final raster in Printing.raster(file.bytes, dpi: dpi)) {
      pageNum++;
      onProgress?.call('Mengekspor halaman $pageNum ke ${targetFormat.toUpperCase()}...');
      final pngBytes = await raster.toPng();
      if (targetFormat == 'png') {
        images.add(pngBytes);
      } else {
        final decoded = img.decodePng(pngBytes);
        if (decoded != null) {
          images.add(Uint8List.fromList(img.encodeJpg(decoded, quality: 92)));
        } else {
          images.add(pngBytes);
        }
      }
    }

    if (images.isEmpty) {
      throw Exception('Gagal merender halaman PDF menjadi gambar.');
    }

    if (images.length == 1) {
      return ProcessResult(
        fileName: '${file.baseName}_hal_1',
        extension: targetFormat,
        bytes: images.first,
        originalBytesLength: file.bytes.length,
        previewImages: images,
        summaryNote: '1 halaman PDF diekspor ke ${targetFormat.toUpperCase()} (${dpi.round()} DPI)',
      );
    }

    onProgress?.call('Mengemas ${images.length} gambar ke arsip ZIP...');
    final archive = Archive();
    for (int i = 0; i < images.length; i++) {
      final numStr = (i + 1).toString().padLeft(3, '0');
      archive.addFile(
        ArchiveFile(
          '${file.baseName}_hal_$numStr.$targetFormat',
          images[i].length,
          images[i],
        ),
      );
    }
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    return ProcessResult(
      fileName: '${file.baseName}_${targetFormat}_hd',
      extension: 'zip',
      bytes: zipBytes,
      originalBytesLength: file.bytes.length,
      previewImages: images,
      summaryNote: '${images.length} halaman diekspor (${dpi.round()} DPI) dalam arsip ZIP',
    );
  }

  /// 7. PDF ke Word (.docx asli — valid OOXML!)
  static Future<ProcessResult> pdfToWord(
    PickedFileData file, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Mengekstrak teks dari setiap halaman PDF...');
    final doc = PdfDocument(inputBytes: file.bytes);
    final pageCount = doc.pages.count;
    final bodyXml = StringBuffer();

    for (int i = 0; i < pageCount; i++) {
      onProgress?.call('Memproses halaman ${i + 1}/$pageCount ke struktur Word...');
      final pageText = PdfTextExtractor(doc).extractText(startPageIndex: i, endPageIndex: i);
      final lines = pageText.split(RegExp(r'\r?\n'));
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        bodyXml.writeln(
          '<w:p><w:r><w:t xml:space="preserve">${_xmlEscape(line)}</w:t></w:r></w:p>',
        );
      }
      if (i < pageCount - 1) {
        bodyXml.writeln('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }
    doc.dispose();

    onProgress?.call('Membangun paket Microsoft Word (.docx)...');
    final archive = Archive();

    void addXml(String path, String xmlContent) {
      final data = utf8.encode(xmlContent);
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    addXml(
      '[Content_Types].xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''',
    );

    addXml(
      '_rels/.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''',
    );

    addXml(
      'word/document.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${bodyXml.isEmpty ? '<w:p><w:r><w:t>(Tidak ada teks terbaca - PDF mungkin berupa gambar scan)</w:t></w:r></w:p>' : bodyXml.toString()}
    <w:sectPr/>
  </w:body>
</w:document>''',
    );

    final docxBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    return ProcessResult(
      fileName: file.baseName,
      extension: 'docx',
      bytes: docxBytes,
      originalBytesLength: file.bytes.length,
      summaryNote: '$pageCount halaman PDF berhasil diekspor ke Microsoft Word (.docx)',
    );
  }

  /// 8. PDF ke Excel (.xlsx asli — valid OOXML!)
  static Future<ProcessResult> pdfToExcel(
    PickedFileData file, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Mengekstrak baris data dari dokumen PDF...');
    final doc = PdfDocument(inputBytes: file.bytes);
    final pageCount = doc.pages.count;
    final rows = <List<String>>[
      ['Halaman', 'Kolom 1', 'Kolom 2', 'Kolom 3', 'Kolom 4'],
    ];

    for (int i = 0; i < pageCount; i++) {
      onProgress?.call('Menyusun data halaman ${i + 1}/$pageCount...');
      final pageText = PdfTextExtractor(doc).extractText(startPageIndex: i, endPageIndex: i);
      for (final rawLine in pageText.split(RegExp(r'\r?\n'))) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        // Split columns when multiple spaces or tabs appear
        final cols = line.split(RegExp(r'\t+|\s{2,}')).map((e) => e.trim()).toList();
        rows.add(['Hal ${i + 1}', ...cols]);
      }
    }
    doc.dispose();

    onProgress?.call('Membangun file spreadsheet Excel (.xlsx)...');
    final sheetRowsXml = StringBuffer();
    for (int r = 0; r < rows.length; r++) {
      sheetRowsXml.write('<row r="${r + 1}">');
      for (int c = 0; c < rows[r].length; c++) {
        final colLetter = _excelColName(c);
        final val = _xmlEscape(rows[r][c]);
        sheetRowsXml.write(
          '<c r="$colLetter${r + 1}" t="inlineStr"><is><t>$val</t></is></c>',
        );
      }
      sheetRowsXml.writeln('</row>');
    }

    final archive = Archive();
    void addXml(String path, String xmlContent) {
      final data = utf8.encode(xmlContent);
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    addXml(
      '[Content_Types].xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''',
    );

    addXml(
      '_rels/.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''',
    );

    addXml(
      'xl/workbook.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Data PDF" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''',
    );

    addXml(
      'xl/_rels/workbook.xml.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''',
    );

    addXml(
      'xl/worksheets/sheet1.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    ${sheetRowsXml.toString()}
  </sheetData>
</worksheet>''',
    );

    final xlsxBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    return ProcessResult(
      fileName: file.baseName,
      extension: 'xlsx',
      bytes: xlsxBytes,
      originalBytesLength: file.bytes.length,
      summaryNote: '${rows.length - 1} baris data diekstrak ke Excel (.xlsx)',
    );
  }

  /// 9. PDF ke PowerPoint (.pptx asli — setiap halaman jadi slide visual HD!)
  static Future<ProcessResult> pdfToPpt(
    PickedFileData file, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Merender halaman PDF menjadi slide visual HD...');
    final slideImages = <Uint8List>[];
    int idx = 0;

    await for (final raster in Printing.raster(file.bytes, dpi: 150)) {
      idx++;
      onProgress?.call('Menyiapkan slide $idx...');
      final pngBytes = await raster.toPng();
      final decoded = img.decodePng(pngBytes);
      if (decoded != null) {
        slideImages.add(Uint8List.fromList(img.encodeJpg(decoded, quality: 88)));
      } else {
        slideImages.add(pngBytes);
      }
    }

    if (slideImages.isEmpty) {
      throw Exception('Gagal merender halaman PDF ke slide PowerPoint.');
    }

    onProgress?.call('Membangun paket PowerPoint (.pptx)...');
    final archive = Archive();
    void addXml(String path, String xmlContent) {
      final data = utf8.encode(xmlContent);
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    // 16:9 widescreen slide in EMUs (12192000 x 6858000 = 13.333" x 7.5")
    const int slideW = 12192000;
    const int slideH = 6858000;

    final overrides = StringBuffer();
    final presRels = StringBuffer();
    final sldIdLst = StringBuffer();

    for (int i = 0; i < slideImages.length; i++) {
      final n = i + 1;
      final imgBytes = slideImages[i];
      archive.addFile(ArchiveFile('ppt/media/image$n.jpg', imgBytes.length, imgBytes));

      overrides.writeln(
        '  <Override PartName="/ppt/slides/slide$n.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
      presRels.writeln(
        '  <Relationship Id="rId$n" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$n.xml"/>',
      );
      sldIdLst.writeln('    <p:sldId id="${255 + n}" r:id="rId$n"/>');

      addXml(
        'ppt/slides/_rels/slide$n.xml.rels',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$n.jpg"/>
</Relationships>''',
      );

      addXml(
        'ppt/slides/slide$n.xml',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:pic>
        <p:nvPicPr>
          <p:cNvPr id="2" name="PDF Page $n"/>
          <p:cNvPicPr/>
          <p:nvPr/>
        </p:nvPicPr>
        <p:blipFill>
          <a:blip r:embed="rId1"/>
          <a:stretch><a:fillRect/></a:stretch>
        </p:blipFill>
        <p:spPr>
          <a:xfrm><a:off x="0" y="0"/><a:ext cx="$slideW" cy="$slideH"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
      </p:pic>
    </p:spTree>
  </p:cSld>
</p:sld>''',
      );
    }

    addXml(
      '[Content_Types].xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
$overrides</Types>''',
    );

    addXml(
      '_rels/.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''',
    );

    addXml(
      'ppt/_rels/presentation.xml.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
$presRels</Relationships>''',
    );

    addXml(
      'ppt/presentation.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldIdLst>
$sldIdLst  </p:sldIdLst>
  <p:sldSz cx="$slideW" cy="$slideH" type="screen16x9"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''',
    );

    final pptxBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    return ProcessResult(
      fileName: file.baseName,
      extension: 'pptx',
      bytes: pptxBytes,
      originalBytesLength: file.bytes.length,
      previewImages: slideImages,
      summaryNote: '${slideImages.length} halaman PDF berhasil diubah menjadi presentasi .pptx',
    );
  }

  static List<String> _parseCsvRow(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if ((ch == ',' || ch == ';') && !inQuotes) {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }

  static String _excelColName(int zeroBased) {
    var n = zeroBased + 1;
    final chars = <String>[];
    while (n > 0) {
      final rem = (n - 1) % 26;
      chars.add(String.fromCharCode(65 + rem));
      n = (n - 1) ~/ 26;
    }
    return chars.reversed.join();
  }
}
