import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import '../data/tools_catalog.dart';
import '../models/tool_item.dart';
import '../theme/app_theme.dart';
import 'tool_workspace_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onFileSaved;
  const HomeScreen({super.key, this.onFileSaved});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'Semua Alat';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ToolItem> get _filteredTools {
    final q = _searchQuery.trim().toLowerCase();
    return kAllTools.where((tool) {
      final matchesCat =
          _selectedCategory == 'Semua Alat' || tool.category == _selectedCategory;
      final matchesQ = q.isEmpty ||
          tool.title.toLowerCase().contains(q) ||
          tool.description.toLowerCase().contains(q) ||
          tool.category.toLowerCase().contains(q);
      return matchesCat && matchesQ;
    }).toList();
  }

  Future<void> _openTool(ToolItem tool) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ToolWorkspaceScreen(
          tool: tool,
          onFileSaved: widget.onFileSaved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTools;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.textMuted;
    final featured = kAllTools.where((t) => t.isFeatured).toList();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            titleSpacing: 16,
            toolbarHeight: 64,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/app_logo.jpg',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'PDF Studio Pro',
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OFFLINE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.emerald,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '33 Alat PDF & AI Studio Background',
                        style: TextStyle(fontSize: 11.5, color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
                    ),
                  ),
                  child: Icon(
                    isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill,
                    size: 18,
                    color: isDark ? AppTheme.gold : AppTheme.navy,
                  ),
                ),
                onPressed: () {
                  AppTheme.themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Search + Category Filter Pills
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
                      ),
                    ),
                    child: CupertinoSearchTextField(
                      controller: _searchCtrl,
                      placeholder: 'Cari dari 33 alat PDF, gambar, atau AI Background...',
                      backgroundColor: Colors.transparent,
                      style: TextStyle(color: titleColor, fontSize: 14),
                      placeholderStyle: TextStyle(color: mutedColor, fontSize: 13.5),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = kCategories[index];
                        final active = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active
                                  ? (isDark ? AppTheme.gold : AppTheme.navy)
                                  : (isDark ? AppTheme.darkSurface : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active
                                    ? Colors.transparent
                                    : (isDark ? AppTheme.darkBorder : AppTheme.softBorder),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: active
                                    ? (isDark ? AppTheme.navyDeep : Colors.white)
                                    : titleColor,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Flagship AI Studio Hero Banner
          if (_searchQuery.isEmpty &&
              (_selectedCategory == 'Semua Alat' || _selectedCategory == 'AI Background'))
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.navyDeep, AppTheme.navy, Color(0xFF1F4E73)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.navy.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -28,
                      top: -28,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.gold.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 22,
                      bottom: -36,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.gold.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.sparkles,
                                        size: 12, color: AppTheme.gold),
                                    SizedBox(width: 5),
                                    Text(
                                      'AI Studio Foto · 100% Lokal',
                                      style: TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Hapus & Ganti Background Foto dengan Presisi Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Potong subjek otomatis dengan tepi halus, ganti warna pas foto, gradien studio, atau foto custom + efek bokeh.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.gold,
                                    foregroundColor: AppTheme.navyDeep,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                  onPressed: () => _openTool(findToolById('ai_remove_bg')),
                                  icon: const Icon(CupertinoIcons.wand_stars, size: 17),
                                  label: const Text(
                                    'Hapus BG',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.45),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                  onPressed: () => _openTool(findToolById('ai_replace_bg')),
                                  icon: const Icon(CupertinoIcons.photo_on_rectangle, size: 17),
                                  label: const Text(
                                    'Ganti BG',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Quick-Access Popular Row
          if (_searchQuery.isEmpty && _selectedCategory == 'Semua Alat')
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.flame_fill,
                            size: 16, color: AppTheme.pdfRed),
                        const SizedBox(width: 6),
                        Text(
                          'Akses Cepat Populer',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 86,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final tool = featured[index];
                        return InkWell(
                          onTap: () => _openTool(tool),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 96,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: tool.accentColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(tool.icon, size: 20, color: tool.accentColor),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  tool.shortTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Count indicator
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
              child: Text(
                'Menampilkan ${filtered.length} dari ${kAllTools.length} alat siap pakai',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
            ),
          ),

          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.search, size: 42, color: mutedColor),
                    const SizedBox(height: 10),
                    Text(
                      'Tidak ditemukan alat untuk "$_searchQuery"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // 7 Numbered Sections
          ...kToolSections.expand((section) {
            final sectionTools =
                filtered.where((t) => t.category == section.categoryKey).toList();
            if (sectionTools.isEmpty) return <Widget>[];

            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: section.accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              section.number,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: section.accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              section.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Text(
                            '${sectionTools.length} alat',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        section.subtitle,
                        style: TextStyle(fontSize: 12, color: mutedColor, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 11,
                    crossAxisSpacing: 11,
                    childAspectRatio: 1.02,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tool = sectionTools[index];
                      return _ToolGridCard(
                        tool: tool,
                        isDark: isDark,
                        titleColor: titleColor,
                        mutedColor: mutedColor,
                        onTap: () => _openTool(tool),
                      );
                    },
                    childCount: sectionTools.length,
                  ),
                ),
              ),
            ];
          }),

          // Privacy Banner & Footer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.lock_shield_fill,
                            color: AppTheme.emerald,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '100% Offline & Privasi Aman',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Seluruh pemrosesan PDF, Office, gambar, dan AI berjalan langsung di perangkat Anda tanpa server eksternal.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: mutedColor,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '© 2026 PDF Studio Pro · iOS & Android Offline Suite',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: mutedColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolGridCard extends StatelessWidget {
  final ToolItem tool;
  final bool isDark;
  final Color titleColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _ToolGridCard({
    required this.tool,
    required this.isDark,
    required this.titleColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.softBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: tool.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tool.icon, color: tool.accentColor, size: 22),
                  ),
                  if (tool.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: tool.accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tool.badge!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: tool.accentColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                tool.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  height: 1.2,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  tool.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedColor,
                    height: 1.35,
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
