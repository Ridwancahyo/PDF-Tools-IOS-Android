import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/picked_file_data.dart';
import '../models/tool_item.dart';

class ImageToolsService {
  static Future<img.Image> _decodeSafely(PickedFileData file) async {
    final ext = file.extension.toLowerCase();
    Uint8List raw = file.bytes;
    if (ext == 'heic' || ext == 'heif') {
      final dir = await getTemporaryDirectory();
      final temp = File(
        '${dir.path}${Platform.pathSeparator}heic_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await temp.writeAsBytes(file.bytes, flush: true);
      final converted = await FlutterImageCompress.compressWithFile(
        temp.absolute.path,
        format: CompressFormat.jpeg,
        quality: 96,
      );
      if (converted != null) {
        raw = converted;
      }
    }
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw Exception('Format gambar ${file.formatUpper} tidak didukung.');
    }
    return img.bakeOrientation(decoded);
  }

  /// 1. Konversi format JPG / PNG / JPEG
  static Future<ProcessResult> convertFormat(
    PickedFileData file, {
    required String targetExt, // 'jpg', 'png', 'jpeg'
    required int quality,
    Color matteBg = Colors.white,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Membaca berkas gambar ${file.formatUpper}...');
    final decoded = await _decodeSafely(file);

    onProgress?.call('Mengonversi ke format ${targetExt.toUpperCase()}...');
    Uint8List outBytes;
    if (targetExt == 'png') {
      outBytes = Uint8List.fromList(img.encodePng(decoded));
    } else {
      // Flatten transparency onto matte background before JPEG encoding
      final flattened = _flattenAlpha(decoded, matteBg);
      outBytes = Uint8List.fromList(img.encodeJpg(flattened, quality: quality));
    }

    return ProcessResult(
      fileName: '${file.baseName}_converted',
      extension: targetExt,
      bytes: outBytes,
      originalBytesLength: file.bytes.length,
      summaryNote:
          '${file.formatUpper} → ${targetExt.toUpperCase()} (${decoded.width}×${decoded.height} px)',
    );
  }

  /// 2. Konversi HEIC iPhone ke JPG, PNG, atau PDF
  static Future<ProcessResult> convertHeic(
    PickedFileData file, {
    required String targetFormat, // 'jpg', 'png', 'pdf'
    int quality = 94,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Membaca foto iPhone (${file.formatUpper})...');
    final dir = await getTemporaryDirectory();
    final temp = File(
      '${dir.path}${Platform.pathSeparator}heic_src_${DateTime.now().microsecondsSinceEpoch}.${file.extension.isEmpty ? 'heic' : file.extension}',
    );
    await temp.writeAsBytes(file.bytes, flush: true);

    Uint8List? jpegBytes;
    try {
      jpegBytes = await FlutterImageCompress.compressWithFile(
        temp.absolute.path,
        format: CompressFormat.jpeg,
        quality: quality,
      );
    } catch (_) {
      jpegBytes = null;
    }

    if (jpegBytes == null) {
      final decoded = img.decodeImage(file.bytes);
      if (decoded == null) {
        throw Exception('Gagal mendekode foto HEIC/gambar.');
      }
      jpegBytes = Uint8List.fromList(
        img.encodeJpg(img.bakeOrientation(decoded), quality: quality),
      );
    }

    if (targetFormat == 'jpg') {
      return ProcessResult(
        fileName: '${file.baseName}_heic',
        extension: 'jpg',
        bytes: jpegBytes,
        originalBytesLength: file.bytes.length,
        summaryNote: 'Berhasil dikonversi dari ${file.formatUpper} ke JPG (kualitas $quality%)',
      );
    }

    if (targetFormat == 'png') {
      onProgress?.call('Menyusun berkas PNG lossless...');
      final decoded = img.decodeImage(jpegBytes);
      if (decoded == null) throw Exception('Gagal mengonversi ke PNG.');
      final pngBytes = Uint8List.fromList(img.encodePng(decoded));
      return ProcessResult(
        fileName: '${file.baseName}_heic',
        extension: 'png',
        bytes: pngBytes,
        originalBytesLength: file.bytes.length,
        summaryNote: 'Berhasil dikonversi ke PNG (${decoded.width}×${decoded.height} px)',
      );
    }

    // PDF export
    onProgress?.call('Menyusun halaman dokumen PDF...');
    final doc = PdfDocument();
    doc.pageSettings.margins.all = 18;
    final page = doc.pages.add();
    final pdfImg = PdfBitmap(jpegBytes);
    final client = page.getClientSize();
    final scale = math.min(
      client.width / pdfImg.width,
      client.height / pdfImg.height,
    );
    final w = pdfImg.width * scale;
    final h = pdfImg.height * scale;
    page.graphics.drawImage(
      pdfImg,
      Rect.fromLTWH((client.width - w) / 2, (client.height - h) / 2, w, h),
    );
    final pdfBytes = Uint8List.fromList(await doc.save());
    doc.dispose();

    return ProcessResult(
      fileName: '${file.baseName}_heic',
      extension: 'pdf',
      bytes: pdfBytes,
      originalBytesLength: file.bytes.length,
      previewImages: [jpegBytes],
      summaryNote: 'Foto ${file.formatUpper} berhasil diubah ke dokumen PDF',
    );
  }

  /// 3. Upscale Gambar HD (2x / 3x / 4x + adaptive sharpening)
  static Future<ProcessResult> upscaleImage(
    PickedFileData file, {
    required int scaleFactor,
    bool sharpen = true,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Membaca dimensi asli gambar...');
    final decoded = await _decodeSafely(file);

    // Cap extreme dimensions to protect mobile RAM (max 4800px edge)
    final maxDim = 4800;
    int targetW = decoded.width * scaleFactor;
    int targetH = decoded.height * scaleFactor;
    if (targetW > maxDim || targetH > maxDim) {
      final ratio = math.min(maxDim / targetW, maxDim / targetH);
      targetW = (targetW * ratio).round();
      targetH = (targetH * ratio).round();
    }

    onProgress?.call('Memperbesar resolusi $scaleFactor× ($targetW×$targetH px)...');
    var upscaled = img.copyResize(
      decoded,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.cubic,
    );

    if (sharpen) {
      onProgress?.call('Menerapkan penajaman tepi HD adaptif...');
      upscaled = img.convolution(
        upscaled,
        filter: [
          0, -0.35, 0,
          -0.35, 2.4, -0.35,
          0, -0.35, 0,
        ],
      );
    }

    onProgress?.call('Mengekspor gambar HD...');
    final outBytes = Uint8List.fromList(img.encodePng(upscaled));
    return ProcessResult(
      fileName: '${file.baseName}_${scaleFactor}x_hd',
      extension: 'png',
      bytes: outBytes,
      originalBytesLength: file.bytes.length,
      summaryNote:
          '${decoded.width}×${decoded.height} px → $targetW×$targetH px ($scaleFactor× HD)',
    );
  }

  /// 4. Resize Gambar (Piksel presisi, Persentase, atau Preset)
  static Future<ProcessResult> resizeImage(
    PickedFileData file, {
    required String mode, // 'pixel', 'percent', 'preset'
    int targetWidth = 1080,
    int targetHeight = 1080,
    bool lockAspectRatio = true,
    int percent = 50,
    String outputExt = 'jpg',
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Membaca ukuran gambar asli...');
    final decoded = await _decodeSafely(file);

    int outW;
    int outH;
    if (mode == 'percent') {
      final f = percent.clamp(10, 300) / 100.0;
      outW = math.max(16, (decoded.width * f).round());
      outH = math.max(16, (decoded.height * f).round());
    } else if (mode == 'pixel' && lockAspectRatio) {
      outW = targetWidth.clamp(16, 6000);
      outH = math.max(16, (outW * decoded.height / decoded.width).round());
    } else {
      outW = targetWidth.clamp(16, 6000);
      outH = targetHeight.clamp(16, 6000);
    }

    onProgress?.call('Mengubah dimensi ke $outW×$outH px...');
    final resized = img.copyResize(
      decoded,
      width: outW,
      height: outH,
      interpolation: img.Interpolation.cubic,
    );

    final ext = outputExt.toLowerCase() == 'png' ? 'png' : 'jpg';
    final outBytes = ext == 'png'
        ? Uint8List.fromList(img.encodePng(resized))
        : Uint8List.fromList(img.encodeJpg(_flattenAlpha(resized, Colors.white), quality: 92));

    return ProcessResult(
      fileName: '${file.baseName}_${outW}x$outH',
      extension: ext,
      bytes: outBytes,
      originalBytesLength: file.bytes.length,
      summaryNote:
          'Dimensi diubah: ${decoded.width}×${decoded.height} → $outW×$outH px',
    );
  }

  static img.Image _flattenAlpha(img.Image src, Color matte) {
    final out = img.Image(width: src.width, height: src.height, numChannels: 3);
    final mr = (matte.r * 255).round();
    final mg = (matte.g * 255).round();
    final mb = (matte.b * 255).round();
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final a = src.numChannels >= 4 ? (p.a / 255.0) : 1.0;
        final inv = 1.0 - a;
        out.setPixelRgb(
          x,
          y,
          (p.r * a + mr * inv).round().clamp(0, 255),
          (p.g * a + mg * inv).round().clamp(0, 255),
          (p.b * a + mb * inv).round().clamp(0, 255),
        );
      }
    }
    return out;
  }
}
