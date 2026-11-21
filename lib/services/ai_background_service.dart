import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/picked_file_data.dart';
import '../models/tool_item.dart';

enum BackgroundStyleMode {
  transparent,
  solid,
  gradient,
  customImage,
}

class StudioGradientPreset {
  final String name;
  final Color start;
  final Color end;
  final bool diagonal;

  const StudioGradientPreset({
    required this.name,
    required this.start,
    required this.end,
    this.diagonal = true,
  });
}

const List<StudioGradientPreset> kStudioGradients = [
  StudioGradientPreset(
    name: 'Navy Studio',
    start: Color(0xFF0E2438),
    end: Color(0xFF285C8A),
  ),
  StudioGradientPreset(
    name: 'Golden Warmth',
    start: Color(0xFFF6D365),
    end: Color(0xFFFDA085),
  ),
  StudioGradientPreset(
    name: 'Sky Pastel',
    start: Color(0xFF89F7FE),
    end: Color(0xFF66A6FF),
  ),
  StudioGradientPreset(
    name: 'Soft Lavender',
    start: Color(0xFFD9A7C7),
    end: Color(0xFFFFFCDC),
  ),
  StudioGradientPreset(
    name: 'Emerald Mist',
    start: Color(0xFF134E5E),
    end: Color(0xFF71B280),
  ),
  StudioGradientPreset(
    name: 'Crimson Studio',
    start: Color(0xFF8E0E00),
    end: Color(0xFF1F1C18),
  ),
];

class AiBackgroundService {
  static Future<File> _writeTempImage(PickedFileData image) async {
    final dir = await getTemporaryDirectory();
    final ext = image.extension.isEmpty ? 'jpg' : image.extension.toLowerCase();
    final rawTemp = File(
      '${dir.path}${Platform.pathSeparator}ai_in_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    await rawTemp.writeAsBytes(image.bytes, flush: true);

    // Convert HEIC/HEIF to JPEG so both ML Kit and package:image decode reliably.
    if (ext == 'heic' || ext == 'heif') {
      final converted = await FlutterImageCompress.compressWithFile(
        rawTemp.absolute.path,
        format: CompressFormat.jpeg,
        quality: 96,
      );
      if (converted != null) {
        final jpgFile = File(
          '${dir.path}${Platform.pathSeparator}ai_heic_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await jpgFile.writeAsBytes(converted, flush: true);
        return jpgFile;
      }
    }
    return rawTemp;
  }

  /// Processes AI Remove Background or AI Change Background 100% locally on-device.
  static Future<ProcessResult> process({
    required PickedFileData subjectImage,
    required BackgroundStyleMode mode,
    Color solidColor = const Color(0xFFB71C1C),
    StudioGradientPreset? gradient,
    PickedFileData? customBgImage,
    int customBgBlur = 0,
    double threshold = 0.50,
    double edgeSoftness = 0.18,
    String outputFormat = 'png', // 'png', 'jpg', 'pdf'
    void Function(String step)? onProgress,
  }) async {
    onProgress?.call('Menyiapkan foto untuk segmentasi AI lokal...');
    final tempFile = await _writeTempImage(subjectImage);

    final segmenter = SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: true,
    );

    SegmentationMask? mask;
    try {
      onProgress?.call('Mendeteksi subjek & kontur tepi dengan ML Kit...');
      final inputImage = InputImage.fromFile(tempFile);
      mask = await segmenter.processImage(inputImage);
    } finally {
      await segmenter.close();
    }

    if (mask == null) {
      throw Exception(
        'Segmentasi AI tidak menemukan subjek yang jelas pada foto ini.',
      );
    }

    onProgress?.call('Mendekode piksel resolusi penuh...');
    final rawBytes = await tempFile.readAsBytes();
    final decodedOriginal = img.decodeImage(rawBytes);
    if (decodedOriginal == null) {
      throw Exception('Format foto tidak dapat dibaca.');
    }
    final original = img.bakeOrientation(decodedOriginal);
    final w = original.width;
    final h = original.height;

    // Prepare custom background image if needed
    img.Image? bgLayer;
    if (mode == BackgroundStyleMode.customImage && customBgImage != null) {
      onProgress?.call('Menyesuaikan foto latar belakang custom...');
      final bgTemp = await _writeTempImage(customBgImage);
      final decodedBg = img.decodeImage(await bgTemp.readAsBytes());
      if (decodedBg != null) {
        final orientedBg = img.bakeOrientation(decodedBg);
        bgLayer = _centerCropCover(orientedBg, w, h);
        if (customBgBlur > 0) {
          onProgress?.call('Menerapkan efek bokeh latar belakang...');
          bgLayer = img.gaussianBlur(bgLayer, radius: customBgBlur.clamp(1, 18));
        }
      }
    }

    onProgress?.call('Menghaluskan tepi rambut & menyusun komposisi studio...');
    final output = img.Image(width: w, height: h, numChannels: 4);
    final double scaleX = mask.width / w;
    final double scaleY = mask.height / h;
    final double lowEdge = (threshold - edgeSoftness).clamp(0.02, 0.95);
    final double highEdge = (threshold + edgeSoftness).clamp(lowEdge + 0.02, 0.99);

    final solidR = (solidColor.r * 255).round();
    final solidG = (solidColor.g * 255).round();
    final solidB = (solidColor.b * 255).round();

    final gStart = gradient?.start ?? const Color(0xFF0E2438);
    final gEnd = gradient?.end ?? const Color(0xFF285C8A);
    final gDiagonal = gradient?.diagonal ?? true;
    final gsr = gStart.r * 255.0;
    final gsg = gStart.g * 255.0;
    final gsb = gStart.b * 255.0;
    final ger = gEnd.r * 255.0;
    final geg = gEnd.g * 255.0;
    final geb = gEnd.b * 255.0;

    for (int y = 0; y < h; y++) {
      final double fy = y * scaleY;
      final int y0 = fy.floor().clamp(0, mask.height - 1);
      final int y1 = math.min(y0 + 1, mask.height - 1);
      final double wy = fy - y0;
      final int row0 = y0 * mask.width;
      final int row1 = y1 * mask.width;

      for (int x = 0; x < w; x++) {
        // Bilinear sample on ML Kit confidence mask for smooth contours
        final double fx = x * scaleX;
        final int x0 = fx.floor().clamp(0, mask.width - 1);
        final int x1 = math.min(x0 + 1, mask.width - 1);
        final double wx = fx - x0;

        final double c00 = mask.confidences[row0 + x0];
        final double c10 = mask.confidences[row0 + x1];
        final double c01 = mask.confidences[row1 + x0];
        final double c11 = mask.confidences[row1 + x1];

        final double top = c00 + (c10 - c00) * wx;
        final double bot = c01 + (c11 - c01) * wx;
        final double conf = top + (bot - top) * wy;

        // Smoothstep alpha for natural hair/shoulder anti-aliasing
        final double t = ((conf - lowEdge) / (highEdge - lowEdge)).clamp(0.0, 1.0);
        final double alpha = t * t * (3.0 - 2.0 * t);

        final p = original.getPixel(x, y);
        final double fgR = p.r.toDouble();
        final double fgG = p.g.toDouble();
        final double fgB = p.b.toDouble();

        if (mode == BackgroundStyleMode.transparent) {
          final int outA = (alpha * 255.0).round().clamp(0, 255);
          if (outA == 0) {
            output.setPixelRgba(x, y, 0, 0, 0, 0);
          } else {
            output.setPixelRgba(x, y, fgR.round(), fgG.round(), fgB.round(), outA);
          }
        } else {
          double bgR;
          double bgG;
          double bgB;

          if (mode == BackgroundStyleMode.solid) {
            bgR = solidR.toDouble();
            bgG = solidG.toDouble();
            bgB = solidB.toDouble();
          } else if (mode == BackgroundStyleMode.gradient) {
            final double gt = gDiagonal
                ? ((x / math.max(1, w - 1)) * 0.45 + (y / math.max(1, h - 1)) * 0.55)
                : (y / math.max(1, h - 1));
            bgR = gsr + (ger - gsr) * gt;
            bgG = gsg + (geg - gsg) * gt;
            bgB = gsb + (geb - gsb) * gt;
          } else if (bgLayer != null) {
            final bp = bgLayer.getPixel(x, y);
            bgR = bp.r.toDouble();
            bgG = bp.g.toDouble();
            bgB = bp.b.toDouble();
          } else {
            bgR = 255;
            bgG = 255;
            bgB = 255;
          }

          final double inv = 1.0 - alpha;
          final int outR = (fgR * alpha + bgR * inv).round().clamp(0, 255);
          final int outG = (fgG * alpha + bgG * inv).round().clamp(0, 255);
          final int outB = (fgB * alpha + bgB * inv).round().clamp(0, 255);
          output.setPixelRgba(x, y, outR, outG, outB, 255);
        }
      }
    }

    final base = subjectImage.baseName;
    final tag = mode == BackgroundStyleMode.transparent ? 'nobg' : 'studio_bg';
    final effectiveFmt =
        mode == BackgroundStyleMode.transparent && outputFormat == 'jpg'
            ? 'png'
            : outputFormat.toLowerCase();

    if (effectiveFmt == 'pdf') {
      onProgress?.call('Mengekspor hasil studio ke dokumen PDF...');
      final imgBytes = Uint8List.fromList(
        mode == BackgroundStyleMode.transparent
            ? img.encodePng(output)
            : img.encodeJpg(output, quality: 95),
      );
      final doc = PdfDocument();
      doc.pageSettings.margins.all = 16;
      final page = doc.pages.add();
      final clientSize = page.getClientSize();
      final pdfBmp = PdfBitmap(imgBytes);
      final fitted = _fitAspect(
        w.toDouble(),
        h.toDouble(),
        clientSize.width,
        clientSize.height,
      );
      page.graphics.drawImage(pdfBmp, fitted);
      final pdfBytes = Uint8List.fromList(await doc.save());
      doc.dispose();

      return ProcessResult(
        fileName: '${base}_$tag',
        extension: 'pdf',
        bytes: pdfBytes,
        originalBytesLength: subjectImage.bytes.length,
        previewImages: [imgBytes],
        summaryNote: 'Resolusi $w×$h px · Diekspor sebagai PDF Studio HD',
      );
    }

    onProgress?.call('Menyimpan gambar ${effectiveFmt.toUpperCase()} HD...');
    final Uint8List outBytes = effectiveFmt == 'jpg'
        ? Uint8List.fromList(img.encodeJpg(output, quality: 95))
        : Uint8List.fromList(img.encodePng(output));

    return ProcessResult(
      fileName: '${base}_$tag',
      extension: effectiveFmt,
      bytes: outBytes,
      originalBytesLength: subjectImage.bytes.length,
      summaryNote: mode == BackgroundStyleMode.transparent
          ? 'Transparan PNG HD ($w×$h px) · Tepi halus aktif'
          : 'Studio Background ${effectiveFmt.toUpperCase()} ($w×$h px)',
    );
  }

  static img.Image _centerCropCover(img.Image src, int targetW, int targetH) {
    final double srcAspect = src.width / src.height;
    final double dstAspect = targetW / targetH;
    int cropW = src.width;
    int cropH = src.height;
    int cropX = 0;
    int cropY = 0;

    if (srcAspect > dstAspect) {
      cropW = (src.height * dstAspect).round();
      cropX = ((src.width - cropW) / 2).round();
    } else {
      cropH = (src.width / dstAspect).round();
      cropY = ((src.height - cropH) / 2).round();
    }

    final cropped = img.copyCrop(
      src,
      x: cropX.clamp(0, src.width - 1),
      y: cropY.clamp(0, src.height - 1),
      width: cropW.clamp(1, src.width),
      height: cropH.clamp(1, src.height),
    );
    return img.copyResize(
      cropped,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.linear,
    );
  }

  static Rect _fitAspect(double imgW, double imgH, double maxW, double maxH) {
    final scale = math.min(maxW / imgW, maxH / imgH);
    final drawW = imgW * scale;
    final drawH = imgH * scale;
    final dx = (maxW - drawW) / 2;
    final dy = (maxH - drawH) / 2;
    return Rect.fromLTWH(dx, dy, drawW, drawH);
  }
}
