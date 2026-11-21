import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../models/picked_file_data.dart';
import '../models/tool_item.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';

class FilesTab extends StatefulWidget {
  const FilesTab({super.key});

  @override
  State<FilesTab> createState() => FilesTabState();
}

class FilesTabState extends State<FilesTab> {
  List<SavedFileEntry> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final list = await HistoryService.listSavedFiles();
      if (mounted) {
        setState(() {
          _files = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _extColor(String ext) {
    switch (ext) {
      case 'pdf':
        return AppTheme.pdfRed;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return AppTheme.gold;
      case 'docx':
        return AppTheme.officeBlue;
      case 'xlsx':
        return AppTheme.officeGreen;
      case 'pptx':
        return AppTheme.officeOrange;
      case 'zip':
        return AppTheme.studioViolet;
      default:
        return AppTheme.navy;
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} · $h:$min';
  }

  Future<void> _shareFile(SavedFileEntry entry) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(entry.path)]),
    );
  }

  Future<void> _deleteFile(SavedFileEntry entry) async {
    await HistoryService.deleteFile(entry.path);
    await reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berkas dihapus: ${entry.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.textMuted;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Berkas Saya',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: reload,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _files.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.navy.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.folder_open,
                            size: 46,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Berkas Tersimpan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hasil PDF, foto AI Studio, Word, Excel, dan PowerPoint yang Anda simpan akan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: mutedColor, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: _files.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = _files[index];
                      final badgeColor = _extColor(entry.extension);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                entry.extension.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${PickedFileData.formatByteSize(entry.sizeBytes)} · ${_formatDate(entry.modifiedAt)}',
                                    style: TextStyle(fontSize: 11.5, color: mutedColor),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Bagikan',
                              icon: Icon(CupertinoIcons.share, color: badgeColor, size: 20),
                              onPressed: () => _shareFile(entry),
                            ),
                            IconButton(
                              tooltip: 'Hapus',
                              icon: Icon(CupertinoIcons.trash, color: mutedColor, size: 19),
                              onPressed: () => _deleteFile(entry),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
