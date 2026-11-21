import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:pdf_studio_pro/data/tools_catalog.dart';
import 'package:pdf_studio_pro/main.dart';
import 'package:pdf_studio_pro/models/picked_file_data.dart';
import 'package:pdf_studio_pro/services/image_tools_service.dart';
import 'package:pdf_studio_pro/services/office_convert_service.dart';
import 'package:pdf_studio_pro/services/pdf_core_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

Future<PickedFileData> _makeSamplePdf(String name, List<String> pagesText) async {
  final doc = PdfDocument();
  final font = PdfStandardFont(PdfFontFamily.helvetica, 14);
  for (final txt in pagesText) {
    final page = doc.pages.add();
    page.graphics.drawString(
      txt,
      font,
      bounds: const Rect.fromLTWH(30, 30, 450, 200),
    );
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return PickedFileData(name: name, bytes: bytes, extension: 'pdf');
}

PickedFileData _makeSamplePng(String name, {int width = 80, int height = 60}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(22, 54, 83, 255));
  final bytes = Uint8List.fromList(img.encodePng(image));
  return PickedFileData(name: name, bytes: bytes, extension: 'png');
}

void main() {
  test('Catalog contains all 33 unique tools across 7 sections', () {
    expect(kAllTools.length, 33);
    expect(kToolSections.length, 7);
    final ids = kAllTools.map((t) => t.id).toSet();
    expect(ids.length, 33);
  });

  testWidgets('App boots and displays PDF Studio Pro home & tabs', (tester) async {
    await tester.pumpWidget(const PdfStudioProApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PDF Studio Pro'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('AI Studio'), findsOneWidget);
    expect(find.text('Berkas Saya'), findsOneWidget);
  });

  group('PDF Core Engine (18 tools)', () {
    test('Merge, Split, Delete, Extract, Organize, Rotate work accurately', () async {
      final pdf1 = await _makeSamplePdf('doc1.pdf', ['Page A1', 'Page A2']);
      final pdf2 = await _makeSamplePdf('doc2.pdf', ['Page B1']);

      // Merge
      final merged = await PdfCoreService.mergePdfs([pdf1, pdf2]);
      expect(PdfCoreService.getPageCount(merged.bytes), 3);

      final mergedFile = PickedFileData(
        name: 'merged.pdf',
        bytes: merged.bytes,
        extension: 'pdf',
      );

      // Split range
      final splitRange = await PdfCoreService.splitPdf(
        mergedFile,
        splitEveryPageToZip: false,
        pageRange: '1-2',
      );
      expect(PdfCoreService.getPageCount(splitRange.bytes), 2);

      // Split all to ZIP
      final splitZip = await PdfCoreService.splitPdf(
        mergedFile,
        splitEveryPageToZip: true,
      );
      expect(splitZip.extension, 'zip');
      final zipFiles = ZipDecoder().decodeBytes(splitZip.bytes).files;
      expect(zipFiles.length, 3);

      // Delete page 2
      final deleted = await PdfCoreService.deletePages(
        mergedFile,
        pagesToDelete: {2},
      );
      expect(PdfCoreService.getPageCount(deleted.bytes), 2);

      // Extract pages 1 and 3
      final extracted = await PdfCoreService.extractPages(
        mergedFile,
        selectedPages: [1, 3],
        asZipArchive: false,
      );
      expect(PdfCoreService.getPageCount(extracted.bytes), 2);

      // Organize (reorder + duplicate + rotate)
      final organized = await PdfCoreService.organizePages(
        mergedFile,
        plan: [
          PagePlanItem(sourcePageNumber: 3, rotationDegrees: 90),
          PagePlanItem(sourcePageNumber: 1),
          PagePlanItem(sourcePageNumber: 1),
        ],
      );
      expect(PdfCoreService.getPageCount(organized.bytes), 3);

      // Rotate
      final rotated = await PdfCoreService.rotatePdf(
        mergedFile,
        angleDegrees: 180,
      );
      expect(PdfCoreService.getPageCount(rotated.bytes), 3);
    });

    test('Compress, Repair, Page Numbers, Watermark, Crop, Annotate, Sign, Redact, Lock/Unlock, Metadata, Compare', () async {
      final pdfA = await _makeSamplePdf(
        'contract_v1.pdf',
        ['Kontrak Rahasia NIK 1234567890', 'Halaman Kedua'],
      );
      final pdfB = await _makeSamplePdf(
        'contract_v2.pdf',
        ['Kontrak Rahasia NIK 1234567890', 'Halaman Kedua Revisi Baru'],
      );

      // Compress (lossless path)
      final comp = await PdfCoreService.compressPdf(pdfA, level: 'ringan');
      expect(PdfCoreService.getPageCount(comp.bytes), 2);

      // Repair
      final repaired = await PdfCoreService.repairPdf(pdfA);
      expect(PdfCoreService.getPageCount(repaired.bytes), 2);

      // Page Numbers
      final numbered = await PdfCoreService.addPageNumbers(
        pdfA,
        formatStyle: 'of_total',
        position: 'bottom_center',
      );
      expect(PdfCoreService.getPageCount(numbered.bytes), 2);

      // Watermark
      final wm = await PdfCoreService.addWatermark(pdfA, text: 'INTERNAL');
      expect(PdfCoreService.getPageCount(wm.bytes), 2);

      // Crop
      final cropped = await PdfCoreService.cropMargins(pdfA, topMm: 8, leftMm: 8);
      expect(PdfCoreService.getPageCount(cropped.bytes), 2);

      // Annotate
      final annotated = await PdfCoreService.annotatePdf(
        pdfA,
        noteText: 'Disetujui',
        pageNumber: 1,
        verticalPos: 'top',
      );
      expect(PdfCoreService.getPageCount(annotated.bytes), 2);

      // Sign (typed)
      final signed = await PdfCoreService.signPdf(
        pdfA,
        typedSignature: 'Ridwan',
        pageNumber: 1,
        corner: 'bottom_right',
      );
      expect(PdfCoreService.getPageCount(signed.bytes), 2);

      // Redact
      final redacted = await PdfCoreService.redactPdf(
        pdfA,
        keywordsCsv: '1234567890',
        addManualBlock: true,
      );
      expect(PdfCoreService.getPageCount(redacted.bytes), 2);

      // Lock & Unlock roundtrip
      final locked = await PdfCoreService.lockPdf(pdfA, password: 'secret123');
      final lockedFile = PickedFileData(
        name: 'locked.pdf',
        bytes: locked.bytes,
        extension: 'pdf',
      );
      final unlocked = await PdfCoreService.unlockPdf(
        lockedFile,
        password: 'secret123',
      );
      expect(PdfCoreService.getPageCount(unlocked.bytes), 2);

      // Metadata
      final meta = await PdfCoreService.updateMetadata(
        pdfA,
        stripAllMetadata: false,
        title: 'Dokumen Resmi',
        author: 'PDF Studio Pro',
        classificationStamp: 'RAHASIA',
      );
      expect(PdfCoreService.getPageCount(meta.bytes), 2);

      // Compare
      final cmp = await PdfCoreService.comparePdfs(pdfA, pdfB);
      expect(cmp.reportText, contains('Halaman Kedua Revisi Baru'));
      expect(PdfCoreService.getPageCount(cmp.bytes), greaterThanOrEqualTo(1));
    });
  });

  group('Image & Office Conversion Engines', () {
    test('Image convert, upscale, resize & imagesToPdf work', () async {
      final png = _makeSamplePng('sample.png', width: 60, height: 40);

      final jpg = await ImageToolsService.convertFormat(
        png,
        targetExt: 'jpg',
        quality: 90,
      );
      expect(jpg.extension, 'jpg');
      expect(jpg.bytes.isNotEmpty, true);

      final upscaled = await ImageToolsService.upscaleImage(png, scaleFactor: 2);
      final decodedUp = img.decodePng(upscaled.bytes)!;
      expect(decodedUp.width, 120);
      expect(decodedUp.height, 80);

      final resized = await ImageToolsService.resizeImage(
        png,
        mode: 'pixel',
        targetWidth: 30,
        lockAspectRatio: true,
      );
      final decodedRes = img.decodeImage(resized.bytes)!;
      expect(decodedRes.width, 30);
      expect(decodedRes.height, 20);

      final pdfFromImg = await OfficeConvertService.imagesToPdf([png]);
      expect(PdfCoreService.getPageCount(pdfFromImg.bytes), 1);
    });

    test('PDF <-> Word (.docx) & PDF <-> Excel (.xlsx) & CSV -> PDF roundtrips', () async {
      final pdf = await _makeSamplePdf(
        'laporan.pdf',
        ['Laporan Bulanan\nItem A   1000\nItem B   2000'],
      );

      // PDF -> DOCX -> PDF
      final docxRes = await OfficeConvertService.pdfToWord(pdf);
      expect(docxRes.extension, 'docx');
      final docxFile = PickedFileData(
        name: 'laporan.docx',
        bytes: docxRes.bytes,
        extension: 'docx',
      );
      final wordPdf = await OfficeConvertService.wordToPdf(docxFile);
      expect(PdfCoreService.getPageCount(wordPdf.bytes), greaterThanOrEqualTo(1));

      // PDF -> XLSX -> PDF
      final xlsxRes = await OfficeConvertService.pdfToExcel(pdf);
      expect(xlsxRes.extension, 'xlsx');
      final xlsxFile = PickedFileData(
        name: 'laporan.xlsx',
        bytes: xlsxRes.bytes,
        extension: 'xlsx',
      );
      final excelPdf = await OfficeConvertService.excelToPdf(xlsxFile);
      expect(PdfCoreService.getPageCount(excelPdf.bytes), greaterThanOrEqualTo(1));

      // CSV -> PDF
      final csvBytes = Uint8List.fromList(utf8.encode('Nama,Nilai\nAndi,95\nBudi,88'));
      final csvFile = PickedFileData(name: 'nilai.csv', bytes: csvBytes, extension: 'csv');
      final csvPdf = await OfficeConvertService.excelToPdf(csvFile);
      expect(PdfCoreService.getPageCount(csvPdf.bytes), 1);
    });
  });
}
