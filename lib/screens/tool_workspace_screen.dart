import 'dart:typed_data';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:signature/signature.dart';
import '../models/picked_file_data.dart';
import '../models/tool_item.dart';
import '../services/ai_background_service.dart';
import '../services/history_service.dart';
import '../services/image_tools_service.dart';
import '../services/office_convert_service.dart';
import '../services/pdf_core_service.dart';
import '../theme/app_theme.dart';
import '../widgets/checkerboard_preview.dart';

class ToolWorkspaceScreen extends StatefulWidget {
  final ToolItem tool;
  final VoidCallback? onFileSaved;
  final BackgroundStyleMode? initialBgMode;
  final Color? initialBgColor;

  const ToolWorkspaceScreen({
    super.key,
    required this.tool,
    this.onFileSaved,
    this.initialBgMode,
    this.initialBgColor,
  });

  @override
  State<ToolWorkspaceScreen> createState() => _ToolWorkspaceScreenState();
}

class _ToolWorkspaceScreenState extends State<ToolWorkspaceScreen> {
  final List<PickedFileData> _files = [];
  int _pdfPageCount = 0;

  // Processing state
  bool _isProcessing = false;
  String _progressStep = '';
  ProcessResult? _result;
  String? _savedPath;

  // --- AI Background state ---
  late BackgroundStyleMode _bgMode;
  late Color _solidBgColor;
  StudioGradientPreset _selectedGradient = kStudioGradients.first;
  PickedFileData? _customBgImage;
  int _customBgBlur = 0;
  double _aiThreshold = 0.50;
  double _aiSoftness = 0.18;
  String _aiOutputFormat = 'png';

  // --- Image tools state ---
  String _targetImageFormat = 'jpg';
  int _imageQuality = 92;
  String _heicTargetFormat = 'jpg';
  int _upscaleFactor = 2;
  bool _upscaleSharpen = true;
  String _resizeMode = 'preset'; // 'pixel', 'percent', 'preset'
  final TextEditingController _resizeWCtrl = TextEditingController(text: '1080');
  final TextEditingController _resizeHCtrl = TextEditingController(text: '1080');
  bool _resizeLockRatio = true;
  int _resizePercent = 50;
  String _resizePresetKey = 'fullhd';
  String _resizeOutputExt = 'jpg';

  // --- PDF Manage state ---
  bool _splitEveryPageZip = false;
  final TextEditingController _pageRangeCtrl = TextEditingController(text: '1');
  final Set<int> _selectedPageSet = {1};
  bool _extractAsZip = false;
  List<PagePlanItem> _organizePlan = [];
  int _rotateAngle = 90;
  bool _rotateAllPages = true;

  // --- Optimize & Convert state ---
  String _compressLevel = 'seimbang';
  String _jpgToPdfSize = 'A4';
  bool _jpgToPdfLandscape = false;
  double _jpgToPdfMargin = 20;
  String _pdfToImgFormat = 'jpg';
  double _pdfToImgDpi = 200;
  final TextEditingController _htmlCodeCtrl = TextEditingController();

  // --- Edit, Sign & Security state ---
  String _pageNumFormat = 'of_total';
  String _pageNumPosition = 'bottom_center';
  double _pageNumFontSize = 11;

  final TextEditingController _watermarkCtrl = TextEditingController(text: 'RAHASIA');
  double _watermarkAngle = -45;
  double _watermarkOpacity = 0.25;
  Color _watermarkColor = AppTheme.pdfRed;

  double _cropTopMm = 10;
  double _cropRightMm = 10;
  double _cropBottomMm = 10;
  double _cropLeftMm = 10;

  final TextEditingController _annotateCtrl = TextEditingController();
  int _targetSinglePage = 1;
  String _annotatePos = 'top';
  bool _annotateHighlight = true;

  late final SignatureController _sigCtrl;
  bool _signUseTyped = false;
  final TextEditingController _typedSigCtrl = TextEditingController();
  String _signCorner = 'bottom_right';
  double _signWidthPt = 160;
  bool _signIncludeDate = true;
  final Color _sigPenColor = AppTheme.navyDeep;

  final TextEditingController _redactKeywordsCtrl = TextEditingController();
  bool _redactManualBlock = false;
  double _redactManualTop = 25;
  double _redactManualHeight = 10;

  final TextEditingController _passwordCtrl = TextEditingController();
  bool _lockAllowPrint = true;
  bool _lockAllowCopy = false;

  bool _metaStripAll = false;
  final TextEditingController _metaTitleCtrl = TextEditingController();
  final TextEditingController _metaAuthorCtrl = TextEditingController();
  final TextEditingController _metaSubjectCtrl = TextEditingController();
  String _metaStamp = 'Tanpa Cap';

  static const List<(String, Color)> _studioColors = [
    ('Pas Foto Merah', Color(0xFFB71C1C)),
    ('Pas Foto Biru', Color(0xFF0D47A1)),
    ('Studio Putih', Color(0xFFFFFFFF)),
    ('Abu Minimalis', Color(0xFFE5E7EB)),
    ('Cream Editorial', Color(0xFFF5EFE6)),
    ('Navy Korporat', Color(0xFF163653)),
    ('Hijau Sage', Color(0xFF2E5E4E)),
    ('Hitam Studio', Color(0xFF121212)),
  ];

  static const Map<String, (String, int, int)> _resizePresets = {
    'fullhd': ('Full HD (1920×1080)', 1920, 1080),
    'square': ('Instagram (1080×1080)', 1080, 1080),
    'pas34': ('Pas Foto 3×4 (354×472)', 354, 472),
    'pas46': ('Pas Foto 4×6 (472×709)', 472, 709),
    'thumb': ('Ringkas (800×600)', 800, 600),
  };

  @override
  void initState() {
    super.initState();
    _bgMode = widget.initialBgMode ??
        (widget.tool.id == 'ai_remove_bg'
            ? BackgroundStyleMode.transparent
            : BackgroundStyleMode.solid);
    _solidBgColor = widget.initialBgColor ?? const Color(0xFFB71C1C);
    _sigCtrl = SignatureController(
      penStrokeWidth: 3.2,
      penColor: _sigPenColor,
      exportBackgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _resizeWCtrl.dispose();
    _resizeHCtrl.dispose();
    _pageRangeCtrl.dispose();
    _htmlCodeCtrl.dispose();
    _watermarkCtrl.dispose();
    _annotateCtrl.dispose();
    _sigCtrl.dispose();
    _typedSigCtrl.dispose();
    _redactKeywordsCtrl.dispose();
    _passwordCtrl.dispose();
    _metaTitleCtrl.dispose();
    _metaAuthorCtrl.dispose();
    _metaSubjectCtrl.dispose();
    super.dispose();
  }

  bool get _canRunProcess {
    if (_isProcessing) return false;
    if (widget.tool.id == 'html_to_pdf') {
      return _files.isNotEmpty || _htmlCodeCtrl.text.trim().isNotEmpty;
    }
    if (widget.tool.id == 'pdf_merge' || widget.tool.id == 'pdf_compare') {
      return _files.length >= 2;
    }
    return _files.isNotEmpty;
  }

  Future<void> _pickFromCameraOrGallery(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source);
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    final name = xFile.name;
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : 'jpg';
    final picked = PickedFileData(name: name, bytes: bytes, extension: ext, path: xFile.path);
    _acceptPickedFiles([picked]);
  }

  Future<void> _pickFiles() async {
    final tool = widget.tool;
    final picked = <PickedFileData>[];

    if (tool.allowsMultiple) {
      final res = await FilePicker.pickFiles(
        type: tool.acceptsImages ? FileType.image : FileType.custom,
        allowedExtensions: tool.acceptsImages ? null : tool.allowedExtensions,
      );
      for (final file in res) {
        final bytes = await file.readAsBytes();
        picked.add(PickedFileData(
          name: file.name,
          bytes: bytes,
          extension: (file.extension ?? 'bin').toLowerCase(),
          path: file.path,
        ));
      }
    } else {
      final file = await FilePicker.pickFile(
        type: tool.acceptsImages ? FileType.image : FileType.custom,
        allowedExtensions: tool.acceptsImages ? null : tool.allowedExtensions,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        picked.add(PickedFileData(
          name: file.name,
          bytes: bytes,
          extension: (file.extension ?? 'bin').toLowerCase(),
          path: file.path,
        ));
      }
    }

    if (picked.isNotEmpty) {
      _acceptPickedFiles(picked);
    }
  }

  Future<void> _pickCustomBackgroundImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    final dot = xFile.name.lastIndexOf('.');
    final ext = dot > 0 ? xFile.name.substring(dot + 1).toLowerCase() : 'jpg';
    setState(() {
      _customBgImage = PickedFileData(
        name: xFile.name,
        bytes: bytes,
        extension: ext,
        path: xFile.path,
      );
      _bgMode = BackgroundStyleMode.customImage;
    });
  }

  void _acceptPickedFiles(List<PickedFileData> picked) {
    setState(() {
      if (!widget.tool.allowsMultiple) {
        _files.clear();
      }
      _files.addAll(picked);
      if (widget.tool.id == 'pdf_compare' && _files.length > 2) {
        _files.removeRange(0, _files.length - 2);
      }
      _result = null;
      _savedPath = null;
      _progressStep = '';

      if (_files.isNotEmpty && _files.first.extension == 'pdf') {
        _pdfPageCount = PdfCoreService.getPageCount(_files.first.bytes);
        _targetSinglePage = 1;
        _pageRangeCtrl.text = _pdfPageCount > 1 ? '1-${_pdfPageCount > 2 ? 2 : 1}' : '1';
        _selectedPageSet
          ..clear()
          ..add(1);
        _organizePlan = List<PagePlanItem>.generate(
          _pdfPageCount,
          (i) => PagePlanItem(sourcePageNumber: i + 1),
        );
      } else {
        _pdfPageCount = 0;
      }
    });
  }

  Future<void> _runProcess() async {
    if (!_canRunProcess) return;
    setState(() {
      _isProcessing = true;
      _progressStep = 'Memulai pemrosesan lokal di perangkat...';
      _result = null;
      _savedPath = null;
    });

    void step(String s) {
      if (mounted) setState(() => _progressStep = s);
    }

    try {
      late ProcessResult res;
      final id = widget.tool.id;

      switch (id) {
        // 01. AI Studio Background
        case 'ai_remove_bg':
          res = await AiBackgroundService.process(
            subjectImage: _files.first,
            mode: BackgroundStyleMode.transparent,
            threshold: _aiThreshold,
            edgeSoftness: _aiSoftness,
            outputFormat: _aiOutputFormat,
            onProgress: step,
          );
          break;
        case 'ai_replace_bg':
          if (_bgMode == BackgroundStyleMode.customImage && _customBgImage == null) {
            throw Exception('Pilih foto latar belakang custom terlebih dahulu.');
          }
          res = await AiBackgroundService.process(
            subjectImage: _files.first,
            mode: _bgMode == BackgroundStyleMode.transparent
                ? BackgroundStyleMode.solid
                : _bgMode,
            solidColor: _solidBgColor,
            gradient: _selectedGradient,
            customBgImage: _customBgImage,
            customBgBlur: _customBgBlur,
            threshold: _aiThreshold,
            edgeSoftness: _aiSoftness,
            outputFormat: _aiOutputFormat,
            onProgress: step,
          );
          break;

        // 02. Alat Gambar
        case 'img_convert':
          res = await ImageToolsService.convertFormat(
            _files.first,
            targetExt: _targetImageFormat,
            quality: _imageQuality,
            onProgress: step,
          );
          break;
        case 'heic_convert':
          res = await ImageToolsService.convertHeic(
            _files.first,
            targetFormat: _heicTargetFormat,
            quality: _imageQuality,
            onProgress: step,
          );
          break;
        case 'img_upscale':
          res = await ImageToolsService.upscaleImage(
            _files.first,
            scaleFactor: _upscaleFactor,
            sharpen: _upscaleSharpen,
            onProgress: step,
          );
          break;
        case 'img_resize':
          int w = int.tryParse(_resizeWCtrl.text.trim()) ?? 1080;
          int h = int.tryParse(_resizeHCtrl.text.trim()) ?? 1080;
          if (_resizeMode == 'preset') {
            final p = _resizePresets[_resizePresetKey]!;
            w = p.$2;
            h = p.$3;
          }
          res = await ImageToolsService.resizeImage(
            _files.first,
            mode: _resizeMode,
            targetWidth: w,
            targetHeight: h,
            lockAspectRatio: _resizeLockRatio,
            percent: _resizePercent,
            outputExt: _resizeOutputExt,
            onProgress: step,
          );
          break;

        // 03. Kelola PDF
        case 'pdf_merge':
          res = await PdfCoreService.mergePdfs(_files, onProgress: step);
          break;
        case 'pdf_split':
          res = await PdfCoreService.splitPdf(
            _files.first,
            splitEveryPageToZip: _splitEveryPageZip,
            pageRange: _pageRangeCtrl.text,
            onProgress: step,
          );
          break;
        case 'pdf_delete_pages':
          final deleteSet = _pdfPageCount > 0 && _pdfPageCount <= 30
              ? _selectedPageSet
              : PdfCoreService.parsePageRange(_pageRangeCtrl.text, _pdfPageCount).toSet();
          res = await PdfCoreService.deletePages(
            _files.first,
            pagesToDelete: deleteSet,
            onProgress: step,
          );
          break;
        case 'pdf_extract':
          final extractList = _pdfPageCount > 0 && _pdfPageCount <= 30
              ? (_selectedPageSet.toList()..sort())
              : PdfCoreService.parsePageRange(_pageRangeCtrl.text, _pdfPageCount);
          res = await PdfCoreService.extractPages(
            _files.first,
            selectedPages: extractList,
            asZipArchive: _extractAsZip,
            onProgress: step,
          );
          break;
        case 'pdf_organize':
          res = await PdfCoreService.organizePages(
            _files.first,
            plan: _organizePlan,
            onProgress: step,
          );
          break;
        case 'pdf_rotate':
          res = await PdfCoreService.rotatePdf(
            _files.first,
            angleDegrees: _rotateAngle,
            pageRange: _rotateAllPages ? '' : _pageRangeCtrl.text,
            onProgress: step,
          );
          break;

        // 04. Optimalkan & Perbaiki
        case 'pdf_compress':
          res = await PdfCoreService.compressPdf(
            _files.first,
            level: _compressLevel,
            onProgress: step,
          );
          break;
        case 'pdf_repair':
          res = await PdfCoreService.repairPdf(_files.first, onProgress: step);
          break;

        // 05. Konversi ke PDF
        case 'jpg_to_pdf':
          res = await OfficeConvertService.imagesToPdf(
            _files,
            pageSize: _jpgToPdfSize,
            landscape: _jpgToPdfLandscape,
            marginPt: _jpgToPdfMargin,
            onProgress: step,
          );
          break;
        case 'word_to_pdf':
          res = await OfficeConvertService.wordToPdf(_files.first, onProgress: step);
          break;
        case 'excel_to_pdf':
          res = await OfficeConvertService.excelToPdf(_files.first, onProgress: step);
          break;
        case 'ppt_to_pdf':
          res = await OfficeConvertService.pptToPdf(_files.first, onProgress: step);
          break;
        case 'html_to_pdf':
          res = await OfficeConvertService.htmlToPdf(
            file: _files.isNotEmpty ? _files.first : null,
            htmlCode: _htmlCodeCtrl.text,
            onProgress: step,
          );
          break;

        // 06. Konversi dari PDF
        case 'pdf_to_jpg':
          res = await OfficeConvertService.pdfToImages(
            _files.first,
            targetFormat: _pdfToImgFormat,
            dpi: _pdfToImgDpi,
            onProgress: step,
          );
          break;
        case 'pdf_to_word':
          res = await OfficeConvertService.pdfToWord(_files.first, onProgress: step);
          break;
        case 'pdf_to_excel':
          res = await OfficeConvertService.pdfToExcel(_files.first, onProgress: step);
          break;
        case 'pdf_to_ppt':
          res = await OfficeConvertService.pdfToPpt(_files.first, onProgress: step);
          break;

        // 07. Edit, Tanda Tangan & Keamanan
        case 'pdf_page_number':
          res = await PdfCoreService.addPageNumbers(
            _files.first,
            formatStyle: _pageNumFormat,
            position: _pageNumPosition,
            fontSize: _pageNumFontSize,
            onProgress: step,
          );
          break;
        case 'pdf_watermark':
          res = await PdfCoreService.addWatermark(
            _files.first,
            text: _watermarkCtrl.text,
            angle: _watermarkAngle,
            opacity: _watermarkOpacity,
            color: _watermarkColor,
            onProgress: step,
          );
          break;
        case 'pdf_crop':
          res = await PdfCoreService.cropMargins(
            _files.first,
            topMm: _cropTopMm,
            rightMm: _cropRightMm,
            bottomMm: _cropBottomMm,
            leftMm: _cropLeftMm,
            onProgress: step,
          );
          break;
        case 'pdf_annotate':
          res = await PdfCoreService.annotatePdf(
            _files.first,
            noteText: _annotateCtrl.text,
            pageNumber: _targetSinglePage,
            verticalPos: _annotatePos,
            withHighlightBox: _annotateHighlight,
            onProgress: step,
          );
          break;
        case 'pdf_sign':
          Uint8List? sigBytes;
          if (!_signUseTyped && _sigCtrl.isNotEmpty) {
            sigBytes = await _sigCtrl.toPngBytes();
          }
          res = await PdfCoreService.signPdf(
            _files.first,
            signaturePngBytes: sigBytes,
            typedSignature: _signUseTyped ? _typedSigCtrl.text : '',
            pageNumber: _targetSinglePage,
            corner: _signCorner,
            widthPt: _signWidthPt,
            includeDateStamp: _signIncludeDate,
            onProgress: step,
          );
          break;
        case 'pdf_redact':
          res = await PdfCoreService.redactPdf(
            _files.first,
            keywordsCsv: _redactKeywordsCtrl.text,
            addManualBlock: _redactManualBlock,
            manualPage: _targetSinglePage,
            manualTopPercent: _redactManualTop,
            manualHeightPercent: _redactManualHeight,
            onProgress: step,
          );
          break;
        case 'pdf_lock':
          res = await PdfCoreService.lockPdf(
            _files.first,
            password: _passwordCtrl.text,
            allowPrint: _lockAllowPrint,
            allowCopy: _lockAllowCopy,
            onProgress: step,
          );
          break;
        case 'pdf_unlock':
          res = await PdfCoreService.unlockPdf(
            _files.first,
            password: _passwordCtrl.text,
            onProgress: step,
          );
          break;
        case 'pdf_metadata':
          res = await PdfCoreService.updateMetadata(
            _files.first,
            stripAllMetadata: _metaStripAll,
            title: _metaTitleCtrl.text,
            author: _metaAuthorCtrl.text,
            subject: _metaSubjectCtrl.text,
            classificationStamp: _metaStamp,
            onProgress: step,
          );
          break;
        case 'pdf_compare':
          res = await PdfCoreService.comparePdfs(
            _files[0],
            _files[1],
            onProgress: step,
          );
          break;
        default:
          throw Exception('Alat $id tidak dikenali.');
      }

      if (mounted) {
        setState(() {
          _result = res;
          _progressStep = 'Selesai! Berkas siap disimpan atau dibagikan.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _progressStep = '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.pdfRed,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToDevice() async {
    if (_result == null) return;
    final savedFile = await HistoryService.saveResult(_result!);
    widget.onFileSaved?.call();
    if (mounted) {
      setState(() => _savedPath = savedFile.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.emerald,
          content: Text('Tersimpan di Berkas Saya: ${_result!.fullFileName}'),
        ),
      );
    }
  }

  Future<void> _shareResult() async {
    if (_result == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            _result!.bytes,
            name: _result!.fullFileName,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final border = isDark ? AppTheme.darkBorder : AppTheme.softBorder;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.textMuted;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.tool.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          // Header Tool Description Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.tool.accentColor.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.tool.accentColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.tool.accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.tool.icon, color: widget.tool.accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.tool.description,
                    style: TextStyle(fontSize: 12.5, color: titleColor, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. File Picker Dropzone
          _buildPickerSection(isDark, surface, border, titleColor, mutedColor),
          const SizedBox(height: 18),

          // 2. Tool-Specific Controls
          _buildToolControls(isDark, surface, border, titleColor, mutedColor),

          // 3. Live Progress Banner
          if (_progressStep.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: isDark ? 0.35 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const CupertinoActivityIndicator()
                  else
                    const Icon(CupertinoIcons.checkmark_circle_fill,
                        color: AppTheme.emerald, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _progressStep,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // 4. Primary Run Button
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? AppTheme.gold : AppTheme.navy,
                foregroundColor: isDark ? AppTheme.navyDeep : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _canRunProcess ? _runProcess : null,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.bolt_fill),
              label: Text(
                _isProcessing ? 'Memproses Lokal...' : 'Proses Sekarang',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),

          // 5. Result Card
          if (_result != null) ...[
            const SizedBox(height: 22),
            _buildResultCard(isDark, titleColor, mutedColor),
          ],
        ],
      ),
    );
  }

  Widget _buildPickerSection(
    bool isDark,
    Color surface,
    Color border,
    Color titleColor,
    Color mutedColor,
  ) {
    final tool = widget.tool;
    final String promptText;
    if (tool.id == 'pdf_compare') {
      promptText = _files.isEmpty
          ? 'Pilih 2 file PDF untuk dibandingkan'
          : (_files.length == 1
              ? '1 PDF dipilih — ketuk lagi untuk memilih PDF ke-2'
              : '2 PDF siap dibandingkan (ketuk untuk ganti)');
    } else if (tool.allowsMultiple) {
      promptText = _files.isEmpty
          ? 'Ketuk untuk memilih beberapa ${tool.acceptsImages ? "Gambar" : "Dokumen PDF"}'
          : '${_files.length} berkas dipilih (ketuk untuk menambah)';
    } else {
      final exts = tool.allowedExtensions.map((e) => '.${e.toUpperCase()}').join(', ');
      promptText = _files.isEmpty
          ? 'Ketuk untuk memilih berkas ($exts)'
          : '${_files.first.name} (ketuk untuk ganti)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _files.isEmpty ? border : tool.accentColor.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _pickFiles,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tool.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _files.isEmpty
                          ? CupertinoIcons.cloud_upload_fill
                          : CupertinoIcons.doc_checkmark_fill,
                      size: 30,
                      color: tool.accentColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    promptText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: titleColor,
                    ),
                  ),
                  if (_pdfPageCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$_pdfPageCount halaman · ${_files.first.sizeLabel}',
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Quick Gallery / Camera buttons for image tools
          if (tool.acceptsImages) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFromCameraOrGallery(ImageSource.gallery),
                    icon: const Icon(CupertinoIcons.photo, size: 16),
                    label: const Text('Galeri', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFromCameraOrGallery(ImageSource.camera),
                    icon: const Icon(CupertinoIcons.camera, size: 16),
                    label: const Text('Kamera', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(CupertinoIcons.folder, size: 16),
                    label: const Text('File', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ],

          // Selected image preview
          if (_files.isNotEmpty && _files.first.isImage && !tool.allowsMultiple) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _files.first.bytes,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 70,
                  alignment: Alignment.center,
                  child: Text(
                    'Pratinjau ${_files.first.formatUpper} siap diproses',
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],

          // Selected multi-file list with reorder & remove
          if (_files.isNotEmpty && tool.allowsMultiple) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...List.generate(_files.length, (i) {
              final f = _files[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: tool.accentColor.withValues(alpha: 0.16),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tool.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            '${f.formatUpper} · ${f.sizeLabel}',
                            style: TextStyle(fontSize: 11, color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                    if (i > 0)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(CupertinoIcons.arrow_up, size: 16),
                        onPressed: () {
                          setState(() {
                            final item = _files.removeAt(i);
                            _files.insert(i - 1, item);
                          });
                        },
                      ),
                    if (i < _files.length - 1)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(CupertinoIcons.arrow_down, size: 16),
                        onPressed: () {
                          setState(() {
                            final item = _files.removeAt(i);
                            _files.insert(i + 1, item);
                          });
                        },
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(CupertinoIcons.xmark_circle_fill,
                          size: 18, color: AppTheme.pdfRed),
                      onPressed: () => setState(() => _files.removeAt(i)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildToolControls(
    bool isDark,
    Color surface,
    Color border,
    Color titleColor,
    Color mutedColor,
  ) {
    final id = widget.tool.id;

    switch (id) {
      case 'ai_remove_bg':
      case 'ai_replace_bg':
        return _buildAiBackgroundPanel(isDark, surface, border, titleColor, mutedColor);

      case 'img_convert':
        return _panelCard(
          surface,
          border,
          'Pengaturan Konversi Gambar',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'jpg', label: Text('JPG')),
                  ButtonSegment(value: 'png', label: Text('PNG')),
                  ButtonSegment(value: 'jpeg', label: Text('JPEG')),
                ],
                selected: {_targetImageFormat},
                onSelectionChanged: (v) => setState(() => _targetImageFormat = v.first),
              ),
              if (_targetImageFormat != 'png') ...[
                const SizedBox(height: 14),
                Text('Kualitas Kompresi: $_imageQuality%',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _imageQuality.toDouble(),
                  min: 40,
                  max: 100,
                  divisions: 12,
                  onChanged: (v) => setState(() => _imageQuality = v.round()),
                ),
              ],
            ],
          ),
        );

      case 'heic_convert':
        return _panelCard(
          surface,
          border,
          'Format Tujuan HEIC iPhone',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'jpg', label: Text('JPG')),
                  ButtonSegment(value: 'png', label: Text('PNG')),
                  ButtonSegment(value: 'pdf', label: Text('PDF')),
                ],
                selected: {_heicTargetFormat},
                onSelectionChanged: (v) => setState(() => _heicTargetFormat = v.first),
              ),
              if (_heicTargetFormat == 'jpg') ...[
                const SizedBox(height: 12),
                Text('Kualitas JPG: $_imageQuality%'),
                Slider(
                  value: _imageQuality.toDouble(),
                  min: 60,
                  max: 100,
                  divisions: 8,
                  onChanged: (v) => setState(() => _imageQuality = v.round()),
                ),
              ],
            ],
          ),
        );

      case 'img_upscale':
        return _panelCard(
          surface,
          border,
          'Pengaturan Upscale HD',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('2× HD')),
                  ButtonSegment(value: 3, label: Text('3× Ultra')),
                  ButtonSegment(value: 4, label: Text('4× Max')),
                ],
                selected: {_upscaleFactor},
                onSelectionChanged: (v) => setState(() => _upscaleFactor = v.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Penajaman Tepi Adaptif', style: TextStyle(fontSize: 13.5)),
                subtitle: Text('Membuat detail teks & kontur lebih tajam',
                    style: TextStyle(fontSize: 11.5, color: mutedColor)),
                value: _upscaleSharpen,
                onChanged: (v) => setState(() => _upscaleSharpen = v),
              ),
            ],
          ),
        );

      case 'img_resize':
        return _panelCard(
          surface,
          border,
          'Pengaturan Ukuran Gambar',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'preset', label: Text('Preset')),
                  ButtonSegment(value: 'pixel', label: Text('Piksel')),
                  ButtonSegment(value: 'percent', label: Text('Persen')),
                ],
                selected: {_resizeMode},
                onSelectionChanged: (v) => setState(() => _resizeMode = v.first),
              ),
              const SizedBox(height: 14),
              if (_resizeMode == 'preset')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _resizePresets.entries.map((e) {
                    return ChoiceChip(
                      label: Text(e.value.$1, style: const TextStyle(fontSize: 12)),
                      selected: _resizePresetKey == e.key,
                      onSelected: (_) => setState(() => _resizePresetKey = e.key),
                    );
                  }).toList(),
                ),
              if (_resizeMode == 'pixel') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _resizeWCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Lebar (px)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _resizeHCtrl,
                        enabled: !_resizeLockRatio,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tinggi (px)'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kunci Rasio Aspek', style: TextStyle(fontSize: 13)),
                  value: _resizeLockRatio,
                  onChanged: (v) => setState(() => _resizeLockRatio = v),
                ),
              ],
              if (_resizeMode == 'percent') ...[
                Text('Skala Ukuran: $_resizePercent%',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _resizePercent.toDouble(),
                  min: 10,
                  max: 200,
                  divisions: 19,
                  onChanged: (v) => setState(() => _resizePercent = v.round()),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Format Output: ', style: TextStyle(fontSize: 12.5)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('JPG'),
                    selected: _resizeOutputExt == 'jpg',
                    onSelected: (_) => setState(() => _resizeOutputExt = 'jpg'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('PNG'),
                    selected: _resizeOutputExt == 'png',
                    onSelected: (_) => setState(() => _resizeOutputExt = 'png'),
                  ),
                ],
              ),
            ],
          ),
        );

      case 'pdf_split':
        return _panelCard(
          surface,
          border,
          'Opsi Pisahkan PDF',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Rentang Halaman')),
                  ButtonSegment(value: true, label: Text('Semua Halaman (ZIP)')),
                ],
                selected: {_splitEveryPageZip},
                onSelectionChanged: (v) => setState(() => _splitEveryPageZip = v.first),
              ),
              if (!_splitEveryPageZip) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _pageRangeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Rentang Halaman (contoh: 1-3, 5)',
                    helperText: _pdfPageCount > 0 ? 'Total: $_pdfPageCount halaman' : null,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'pdf_delete_pages':
      case 'pdf_extract':
        final isDelete = id == 'pdf_delete_pages';
        return _panelCard(
          surface,
          border,
          isDelete ? 'Pilih Halaman untuk Dihapus' : 'Pilih Halaman untuk Diekstrak',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pdfPageCount > 0 && _pdfPageCount <= 30) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_pdfPageCount, (i) {
                    final pageNum = i + 1;
                    final selected = _selectedPageSet.contains(pageNum);
                    return FilterChip(
                      label: Text('Hal $pageNum'),
                      selected: selected,
                      selectedColor: isDelete
                          ? AppTheme.pdfRed.withValues(alpha: 0.2)
                          : AppTheme.navy.withValues(alpha: 0.2),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedPageSet.add(pageNum);
                          } else {
                            _selectedPageSet.remove(pageNum);
                          }
                        });
                      },
                    );
                  }),
                ),
              ] else ...[
                TextField(
                  controller: _pageRangeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Halaman (contoh: 1-3, 5)',
                  ),
                ),
              ],
              if (!isDelete) ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pisahkan tiap halaman ke arsip ZIP',
                      style: TextStyle(fontSize: 13)),
                  value: _extractAsZip,
                  onChanged: (v) => setState(() => _extractAsZip = v),
                ),
              ],
            ],
          ),
        );

      case 'pdf_organize':
        if (_organizePlan.isEmpty) {
          return _panelCard(
            surface,
            border,
            'Ruang Kerja Atur Halaman',
            Text(
              'Pilih dokumen PDF terlebih dahulu untuk menata ulang urutan, memutar per halaman, duplikasi, atau menghapus halaman.',
              style: TextStyle(fontSize: 12.5, color: mutedColor),
            ),
          );
        }
        return _panelCard(
          surface,
          border,
          'Atur Halaman (${_organizePlan.where((e) => !e.deleted).length} aktif)',
          Column(
            children: List.generate(_organizePlan.length, (i) {
              final item = _organizePlan[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: item.deleted
                      ? AppTheme.pdfRed.withValues(alpha: 0.08)
                      : (isDark ? AppTheme.darkSurfaceElevated : AppTheme.creamBg),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      'Hal ${item.sourcePageNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: item.deleted ? TextDecoration.lineThrough : null,
                        color: item.deleted ? AppTheme.pdfRed : titleColor,
                      ),
                    ),
                    if (item.rotationDegrees != 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${item.rotationDegrees}°',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.gold),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      tooltip: 'Naik',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(CupertinoIcons.arrow_up, size: 16),
                      onPressed: i == 0
                          ? null
                          : () => setState(() {
                                final x = _organizePlan.removeAt(i);
                                _organizePlan.insert(i - 1, x);
                              }),
                    ),
                    IconButton(
                      tooltip: 'Turun',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(CupertinoIcons.arrow_down, size: 16),
                      onPressed: i == _organizePlan.length - 1
                          ? null
                          : () => setState(() {
                                final x = _organizePlan.removeAt(i);
                                _organizePlan.insert(i + 1, x);
                              }),
                    ),
                    IconButton(
                      tooltip: 'Putar 90°',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(CupertinoIcons.rotate_right, size: 16),
                      onPressed: () => setState(() {
                        item.rotationDegrees = (item.rotationDegrees + 90) % 360;
                      }),
                    ),
                    IconButton(
                      tooltip: 'Duplikasi',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(CupertinoIcons.plus_square, size: 16),
                      onPressed: () => setState(() {
                        _organizePlan.insert(
                          i + 1,
                          PagePlanItem(
                            sourcePageNumber: item.sourcePageNumber,
                            rotationDegrees: item.rotationDegrees,
                          ),
                        );
                      }),
                    ),
                    IconButton(
                      tooltip: item.deleted ? 'Pulihkan' : 'Hapus',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        item.deleted ? CupertinoIcons.arrow_uturn_left : CupertinoIcons.trash,
                        size: 16,
                        color: AppTheme.pdfRed,
                      ),
                      onPressed: () => setState(() => item.deleted = !item.deleted),
                    ),
                  ],
                ),
              );
            }),
          ),
        );

      case 'pdf_rotate':
        return _panelCard(
          surface,
          border,
          'Pengaturan Rotasi PDF',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 90, label: Text('90°')),
                  ButtonSegment(value: 180, label: Text('180°')),
                  ButtonSegment(value: 270, label: Text('270°')),
                ],
                selected: {_rotateAngle},
                onSelectionChanged: (v) => setState(() => _rotateAngle = v.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Terapkan ke semua halaman', style: TextStyle(fontSize: 13.5)),
                value: _rotateAllPages,
                onChanged: (v) => setState(() => _rotateAllPages = v),
              ),
              if (!_rotateAllPages)
                TextField(
                  controller: _pageRangeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Halaman tertentu (misal: 1, 3-5)',
                  ),
                ),
            ],
          ),
        );

      case 'pdf_compress':
        return _panelCard(
          surface,
          border,
          'Tingkat Kompresi PDF',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ringan', label: Text('Ringan')),
                  ButtonSegment(value: 'seimbang', label: Text('Seimbang')),
                  ButtonSegment(value: 'maksimal', label: Text('Maksimal')),
                ],
                selected: {_compressLevel},
                onSelectionChanged: (v) => setState(() => _compressLevel = v.first),
              ),
              const SizedBox(height: 10),
              Text(
                _compressLevel == 'ringan'
                    ? 'Lossless: mempertahankan teks vektor & ketajaman penuh.'
                    : (_compressLevel == 'seimbang'
                        ? 'Seimbang: optimasi 150 DPI untuk dokumen campuran gambar.'
                        : 'Maksimal: ukuran terkecil (105 DPI) ideal untuk kirim cepat.'),
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ],
          ),
        );

      case 'jpg_to_pdf':
        return _panelCard(
          surface,
          border,
          'Pengaturan Halaman PDF',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'A4', label: Text('A4')),
                  ButtonSegment(value: 'Letter', label: Text('Letter')),
                  ButtonSegment(value: 'Fit', label: Text('Pas Gambar')),
                ],
                selected: {_jpgToPdfSize},
                onSelectionChanged: (v) => setState(() => _jpgToPdfSize = v.first),
              ),
              if (_jpgToPdfSize != 'Fit')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Orientasi Lanskap', style: TextStyle(fontSize: 13)),
                  value: _jpgToPdfLandscape,
                  onChanged: (v) => setState(() => _jpgToPdfLandscape = v),
                ),
              const SizedBox(height: 6),
              Text('Margin Halaman: ${_jpgToPdfMargin.round()} pt'),
              Slider(
                value: _jpgToPdfMargin,
                min: 0,
                max: 48,
                divisions: 6,
                onChanged: (v) => setState(() => _jpgToPdfMargin = v),
              ),
            ],
          ),
        );

      case 'html_to_pdf':
        return _panelCard(
          surface,
          border,
          'Atau Tempel Kode HTML Langsung',
          TextField(
            controller: _htmlCodeCtrl,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '<h1>Judul Dokumen</h1><p>Tulis atau tempel kode HTML di sini...</p>',
              alignLabelWithHint: true,
            ),
          ),
        );

      case 'pdf_to_jpg':
        return _panelCard(
          surface,
          border,
          'Pengaturan Ekspor Gambar',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'jpg', label: Text('JPG')),
                  ButtonSegment(value: 'png', label: Text('PNG')),
                ],
                selected: {_pdfToImgFormat},
                onSelectionChanged: (v) => setState(() => _pdfToImgFormat = v.first),
              ),
              const SizedBox(height: 12),
              Text('Resolusi Render: ${_pdfToImgDpi.round()} DPI'),
              Slider(
                value: _pdfToImgDpi,
                min: 100,
                max: 300,
                divisions: 4,
                onChanged: (v) => setState(() => _pdfToImgDpi = v),
              ),
            ],
          ),
        );

      case 'pdf_page_number':
        return _panelCard(
          surface,
          border,
          'Gaya Penomoran Halaman',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'number', label: Text('1')),
                  ButtonSegment(value: 'halaman', label: Text('Halaman 1')),
                  ButtonSegment(value: 'of_total', label: Text('1 / N')),
                ],
                selected: {_pageNumFormat},
                onSelectionChanged: (v) => setState(() => _pageNumFormat = v.first),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ('bottom_center', 'Bawah Tengah'),
                  ('bottom_right', 'Bawah Kanan'),
                  ('bottom_left', 'Bawah Kiri'),
                  ('top_right', 'Atas Kanan'),
                ].map((pos) {
                  return ChoiceChip(
                    label: Text(pos.$2, style: const TextStyle(fontSize: 12)),
                    selected: _pageNumPosition == pos.$1,
                    onSelected: (_) => setState(() => _pageNumPosition = pos.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text('Ukuran Huruf: ${_pageNumFontSize.round()} pt'),
              Slider(
                value: _pageNumFontSize,
                min: 8,
                max: 18,
                divisions: 10,
                onChanged: (v) => setState(() => _pageNumFontSize = v),
              ),
            ],
          ),
        );

      case 'pdf_watermark':
        return _panelCard(
          surface,
          border,
          'Pengaturan Watermark PDF',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _watermarkCtrl,
                decoration: const InputDecoration(labelText: 'Teks Watermark'),
              ),
              const SizedBox(height: 12),
              Text('Transparansi: ${(_watermarkOpacity * 100).round()}%'),
              Slider(
                value: _watermarkOpacity,
                min: 0.1,
                max: 0.7,
                divisions: 12,
                onChanged: (v) => setState(() => _watermarkOpacity = v),
              ),
              const SizedBox(height: 6),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: -45, label: Text('Miring -45°')),
                  ButtonSegment(value: 0, label: Text('Datar 0°')),
                  ButtonSegment(value: 45, label: Text('Miring 45°')),
                ],
                selected: {_watermarkAngle},
                onSelectionChanged: (v) => setState(() => _watermarkAngle = v.first),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ('Merah', AppTheme.pdfRed),
                  ('Navy', AppTheme.navy),
                  ('Abu', Colors.grey),
                  ('Emas', AppTheme.gold),
                ].map((c) {
                  return ChoiceChip(
                    label: Text(c.$1),
                    avatar: CircleAvatar(backgroundColor: c.$2, radius: 7),
                    selected: _watermarkColor == c.$2,
                    onSelected: (_) => setState(() => _watermarkColor = c.$2),
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case 'pdf_crop':
        return _panelCard(
          surface,
          border,
          'Potong Margin Halaman (mm)',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mmSlider('Atas', _cropTopMm, (v) => setState(() => _cropTopMm = v)),
              _mmSlider('Bawah', _cropBottomMm, (v) => setState(() => _cropBottomMm = v)),
              _mmSlider('Kiri', _cropLeftMm, (v) => setState(() => _cropLeftMm = v)),
              _mmSlider('Kanan', _cropRightMm, (v) => setState(() => _cropRightMm = v)),
            ],
          ),
        );

      case 'pdf_annotate':
        return _panelCard(
          surface,
          border,
          'Catatan & Sorotan PDF',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _annotateCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Isi Catatan / Anotasi',
                  hintText: 'Contoh: Sudah diperiksa dan disetujui.',
                ),
              ),
              const SizedBox(height: 12),
              _pageNumberDropdown(),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'top', label: Text('Atas')),
                  ButtonSegment(value: 'middle', label: Text('Tengah')),
                  ButtonSegment(value: 'bottom', label: Text('Bawah')),
                ],
                selected: {_annotatePos},
                onSelectionChanged: (v) => setState(() => _annotatePos = v.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gunakan kotak sorotan kuning', style: TextStyle(fontSize: 13)),
                value: _annotateHighlight,
                onChanged: (v) => setState(() => _annotateHighlight = v),
              ),
            ],
          ),
        );

      case 'pdf_sign':
        return _panelCard(
          surface,
          border,
          'Kanvas Tanda Tangan Digital',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Goresan Jari')),
                  ButtonSegment(value: true, label: Text('Teks Elegan')),
                ],
                selected: {_signUseTyped},
                onSelectionChanged: (v) => setState(() => _signUseTyped = v.first),
              ),
              const SizedBox(height: 12),
              if (!_signUseTyped) ...[
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Signature(
                      controller: _sigCtrl,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _sigCtrl.clear(),
                      icon: const Icon(CupertinoIcons.clear, size: 16),
                      label: const Text('Bersihkan Kanvas'),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _typedSigCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tanda Tangan',
                    hintText: 'Contoh: Budi Santoso',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _pageNumberDropdown(),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'bottom_left', label: Text('Kiri')),
                  ButtonSegment(value: 'bottom_center', label: Text('Tengah')),
                  ButtonSegment(value: 'bottom_right', label: Text('Kanan')),
                ],
                selected: {_signCorner},
                onSelectionChanged: (v) => setState(() => _signCorner = v.first),
              ),
              const SizedBox(height: 8),
              Text('Lebar Tanda Tangan: ${_signWidthPt.round()} pt'),
              Slider(
                value: _signWidthPt,
                min: 90,
                max: 240,
                divisions: 10,
                onChanged: (v) => setState(() => _signWidthPt = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sertakan cap tanggal otomatis', style: TextStyle(fontSize: 13)),
                value: _signIncludeDate,
                onChanged: (v) => setState(() => _signIncludeDate = v),
              ),
            ],
          ),
        );

      case 'pdf_redact':
        return _panelCard(
          surface,
          border,
          'Pengaturan Sensor Permanen',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _redactKeywordsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kata Rahasia (pisahkan koma)',
                  hintText: 'Contoh: 3201123456, rahasia@email.com, Rp 50.000.000',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tambahkan Blok Sensor Manual', style: TextStyle(fontSize: 13)),
                subtitle: Text('Berguna untuk dokumen PDF hasil scan/foto',
                    style: TextStyle(fontSize: 11.5, color: mutedColor)),
                value: _redactManualBlock,
                onChanged: (v) => setState(() => _redactManualBlock = v),
              ),
              if (_redactManualBlock) ...[
                _pageNumberDropdown(),
                const SizedBox(height: 8),
                Text('Posisi Vertikal: ${_redactManualTop.round()}% dari atas'),
                Slider(
                  value: _redactManualTop,
                  min: 5,
                  max: 85,
                  onChanged: (v) => setState(() => _redactManualTop = v),
                ),
                Text('Tinggi Blok: ${_redactManualHeight.round()}% halaman'),
                Slider(
                  value: _redactManualHeight,
                  min: 4,
                  max: 35,
                  onChanged: (v) => setState(() => _redactManualHeight = v),
                ),
              ],
            ],
          ),
        );

      case 'pdf_lock':
      case 'pdf_unlock':
        final isLock = id == 'pdf_lock';
        return _panelCard(
          surface,
          border,
          isLock ? 'Enkripsi Kata Sandi AES-128' : 'Masukkan Kata Sandi PDF',
          Column(
            children: [
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isLock ? 'Kata Sandi Baru' : 'Kata Sandi Saat Ini',
                ),
              ),
              if (isLock) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Izinkan Cetak Dokumen', style: TextStyle(fontSize: 13)),
                  value: _lockAllowPrint,
                  onChanged: (v) => setState(() => _lockAllowPrint = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Izinkan Salin Teks', style: TextStyle(fontSize: 13)),
                  value: _lockAllowCopy,
                  onChanged: (v) => setState(() => _lockAllowCopy = v),
                ),
              ],
            ],
          ),
        );

      case 'pdf_metadata':
        return _panelCard(
          surface,
          border,
          'Metadata & Cap Klasifikasi',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bersihkan Semua Metadata Pribadi',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                value: _metaStripAll,
                onChanged: (v) => setState(() => _metaStripAll = v),
              ),
              if (!_metaStripAll) ...[
                TextField(
                  controller: _metaTitleCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Dokumen'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _metaAuthorCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Penulis'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _metaSubjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subjek / Topik'),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Cap Klasifikasi Sudut Kanan Atas:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Tanpa Cap', 'RAHASIA', 'INTERNAL', 'DRAFT'].map((s) {
                  return ChoiceChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    selected: _metaStamp == s,
                    onSelected: (_) => setState(() => _metaStamp = s),
                  );
                }).toList(),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAiBackgroundPanel(
    bool isDark,
    Color surface,
    Color border,
    Color titleColor,
    Color mutedColor,
  ) {
    final isReplace = widget.tool.id == 'ai_replace_bg';
    return _panelCard(
      surface,
      border,
      isReplace ? 'Studio Ganti Background AI' : 'Pengaturan Potong AI Studio',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReplace) ...[
            SegmentedButton<BackgroundStyleMode>(
              segments: const [
                ButtonSegment(value: BackgroundStyleMode.solid, label: Text('Warna')),
                ButtonSegment(value: BackgroundStyleMode.gradient, label: Text('Gradien')),
                ButtonSegment(value: BackgroundStyleMode.customImage, label: Text('Foto')),
              ],
              selected: {
                _bgMode == BackgroundStyleMode.transparent
                    ? BackgroundStyleMode.solid
                    : _bgMode
              },
              onSelectionChanged: (v) => setState(() => _bgMode = v.first),
            ),
            const SizedBox(height: 14),

            if (_bgMode == BackgroundStyleMode.solid ||
                _bgMode == BackgroundStyleMode.transparent) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _studioColors.map((pair) {
                  final selected = _solidBgColor == pair.$2;
                  return ChoiceChip(
                    label: Text(pair.$1, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    avatar: CircleAvatar(
                      backgroundColor: pair.$2,
                      radius: 8,
                    ),
                    onSelected: (_) => setState(() => _solidBgColor = pair.$2),
                  );
                }).toList(),
              ),
            ],

            if (_bgMode == BackgroundStyleMode.gradient) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kStudioGradients.map((g) {
                  final selected = _selectedGradient.name == g.name;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGradient = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [g.start, g.end]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppTheme.gold : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Text(
                        g.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (_bgMode == BackgroundStyleMode.customImage) ...[
              OutlinedButton.icon(
                onPressed: _pickCustomBackgroundImage,
                icon: const Icon(CupertinoIcons.photo_fill),
                label: Text(
                  _customBgImage == null
                      ? 'Pilih Foto Latar Belakang Custom'
                      : 'Ganti Foto Latar (${_customBgImage!.name})',
                ),
              ),
              if (_customBgImage != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_customBgImage!.bytes, height: 90, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 10),
              Text('Efek Bokeh / Blur Latar: $_customBgBlur'),
              Slider(
                value: _customBgBlur.toDouble(),
                min: 0,
                max: 14,
                divisions: 14,
                onChanged: (v) => setState(() => _customBgBlur = v.round()),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
          ],

          Text(
            'Sensitivitas Subjek: ${(_aiThreshold * 100).round()}%',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
          ),
          Slider(
            value: _aiThreshold,
            min: 0.25,
            max: 0.75,
            divisions: 10,
            onChanged: (v) => setState(() => _aiThreshold = v),
          ),
          Text(
            'Kehalusan Tepi Rambut (Feather): ${(_aiSoftness * 100).round()}%',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
          ),
          Slider(
            value: _aiSoftness,
            min: 0.05,
            max: 0.35,
            divisions: 6,
            onChanged: (v) => setState(() => _aiSoftness = v),
          ),
          const SizedBox(height: 8),
          Text('Format Ekspor Hasil:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: mutedColor)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'png', label: Text('PNG HD')),
              if (isReplace) const ButtonSegment(value: 'jpg', label: Text('JPG')),
              const ButtonSegment(value: 'pdf', label: Text('PDF')),
            ],
            selected: {(!isReplace && _aiOutputFormat == 'jpg') ? 'png' : _aiOutputFormat},
            onSelectionChanged: (v) => setState(() => _aiOutputFormat = v.first),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDark, Color titleColor, Color mutedColor) {
    final res = _result!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10241A) : const Color(0xFFEDF8F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.emerald, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_seal_fill,
                  color: AppTheme.emerald, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Berhasil Diproses!',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: AppTheme.emerald,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  res.extension.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: AppTheme.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${res.fullFileName} · ${PickedFileData.formatByteSize(res.bytes.length)}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: titleColor),
          ),
          if (res.summaryNote != null) ...[
            const SizedBox(height: 4),
            Text(res.summaryNote!, style: TextStyle(fontSize: 12, color: mutedColor)),
          ],

          // Transparent checkerboard preview for image outputs
          if (res.isImage) ...[
            const SizedBox(height: 14),
            CheckerboardBackground(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: Image.memory(res.bytes, fit: BoxFit.contain),
              ),
            ),
          ] else if (res.previewImages.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: res.previewImages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, idx) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(res.previewImages[idx], fit: BoxFit.cover),
                ),
              ),
            ),
          ],

          // Text comparison report viewer
          if (res.reportText != null && res.reportText!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  res.reportText!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: titleColor,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            onPressed: _saveToDevice,
            icon: Icon(
              _savedPath == null
                  ? CupertinoIcons.arrow_down_doc_fill
                  : CupertinoIcons.checkmark_alt,
            ),
            label: Text(
              _savedPath == null ? 'Simpan ke Berkas Saya' : 'Tersimpan di Berkas Saya',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            onPressed: _shareResult,
            icon: const Icon(CupertinoIcons.share),
            label: const Text('Bagikan / Ekspor (iOS & Android Share)'),
          ),
        ],
      ),
    );
  }

  Widget _panelCard(Color surface, Color border, String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _mmSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()} mm', style: const TextStyle(fontSize: 12.5)),
        Slider(value: value, min: 0, max: 60, divisions: 12, onChanged: onChanged),
      ],
    );
  }

  Widget _pageNumberDropdown() {
    final maxP = _pdfPageCount > 0 ? _pdfPageCount : 1;
    final current = _targetSinglePage.clamp(1, maxP);
    return Row(
      children: [
        const Text('Target Halaman:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: current,
          items: List.generate(
            maxP,
            (i) => DropdownMenuItem(value: i + 1, child: Text('Halaman ${i + 1}')),
          ),
          onChanged: (v) {
            if (v != null) setState(() => _targetSinglePage = v);
          },
        ),
      ],
    );
  }
}
