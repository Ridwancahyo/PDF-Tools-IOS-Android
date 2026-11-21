import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import '../data/tools_catalog.dart';
import '../models/tool_item.dart';
import '../services/ai_background_service.dart';
import '../theme/app_theme.dart';
import 'tool_workspace_screen.dart';

class AiStudioTab extends StatelessWidget {
  final VoidCallback? onFileSaved;
  const AiStudioTab({super.key, this.onFileSaved});

  void _launch(
    BuildContext context,
    ToolItem tool, {
    BackgroundStyleMode? initialBgMode,
    Color? initialBgColor,
  }) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ToolWorkspaceScreen(
          tool: tool,
          onFileSaved: onFileSaved,
          initialBgMode: initialBgMode,
          initialBgColor: initialBgColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.textMuted;
    final imageTools =
        kAllTools.where((t) => t.category == 'Alat Gambar').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Studio Foto',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Main Remove Background Hero Card
          _StudioFeatureCard(
            badge: 'ML KIT ON-DEVICE · TRANSPARAN HD',
            title: 'AI Hapus Background',
            subtitle:
                'Hapus latar belakang foto otomatis 100% offline. Dilengkapi kontrol sensitivitas & penghalusan tepi rambut, ekspor PNG transparan atau PDF.',
            gradient: const [AppTheme.navyDeep, Color(0xFF1D4970)],
            icon: CupertinoIcons.wand_stars,
            buttonLabel: 'Mulai Hapus Background',
            onPressed: () => _launch(
              context,
              findToolById('ai_remove_bg'),
              initialBgMode: BackgroundStyleMode.transparent,
            ),
          ),
          const SizedBox(height: 14),

          // Main Change Background Hero Card
          _StudioFeatureCard(
            badge: 'STUDIO PRESET · GRADIEN · FOTO CUSTOM',
            title: 'AI Ganti Background',
            subtitle:
                'Ubah latar belakang foto ke pas foto Merah/Biru, warna studio, gradien estetik, atau gambar pilihan sendiri dengan efek bokeh.',
            gradient: const [Color(0xFF5A1E17), AppTheme.pdfRed],
            icon: CupertinoIcons.photo_on_rectangle,
            buttonLabel: 'Buka Studio Ganti Background',
            onPressed: () => _launch(
              context,
              findToolById('ai_replace_bg'),
              initialBgMode: BackgroundStyleMode.solid,
            ),
          ),
          const SizedBox(height: 22),

          Text(
            'Preset Cepat Pas Foto & Studio',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.25,
            children: [
              _QuickPresetTile(
                label: 'Pas Foto Merah',
                swatch: const Color(0xFFB71C1C),
                isDark: isDark,
                onTap: () => _launch(
                  context,
                  findToolById('ai_replace_bg'),
                  initialBgMode: BackgroundStyleMode.solid,
                  initialBgColor: const Color(0xFFB71C1C),
                ),
              ),
              _QuickPresetTile(
                label: 'Pas Foto Biru',
                swatch: const Color(0xFF0D47A1),
                isDark: isDark,
                onTap: () => _launch(
                  context,
                  findToolById('ai_replace_bg'),
                  initialBgMode: BackgroundStyleMode.solid,
                  initialBgColor: const Color(0xFF0D47A1),
                ),
              ),
              _QuickPresetTile(
                label: 'Studio Gradien',
                swatch: AppTheme.navy,
                isDark: isDark,
                icon: CupertinoIcons.sparkles,
                onTap: () => _launch(
                  context,
                  findToolById('ai_replace_bg'),
                  initialBgMode: BackgroundStyleMode.gradient,
                ),
              ),
              _QuickPresetTile(
                label: 'Foto Custom + Bokeh',
                swatch: AppTheme.gold,
                isDark: isDark,
                icon: CupertinoIcons.photo_fill,
                onTap: () => _launch(
                  context,
                  findToolById('ai_replace_bg'),
                  initialBgMode: BackgroundStyleMode.customImage,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'Alat Gambar Pendukung',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sempurnakan resolusi, ukuran pas foto, dan format foto iPhone HEIC.',
            style: TextStyle(fontSize: 12, color: mutedColor),
          ),
          const SizedBox(height: 12),

          ...imageTools.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _launch(context, tool),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tool.accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(tool.icon, color: tool.accentColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tool.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tool.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, color: mutedColor),
                              ),
                            ],
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right, size: 16, color: mutedColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioFeatureCard extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _StudioFeatureCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.gold, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.navyDeep,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: onPressed,
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPresetTile extends StatelessWidget {
  final String label;
  final Color swatch;
  final bool isDark;
  final IconData? icon;
  final VoidCallback onTap;

  const _QuickPresetTile({
    required this.label,
    required this.swatch,
    required this.isDark,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: swatch,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: icon != null
                    ? Icon(icon, size: 17, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
