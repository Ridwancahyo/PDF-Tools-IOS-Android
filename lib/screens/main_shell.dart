import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'ai_studio_tab.dart';
import 'files_tab.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  final GlobalKey<FilesTabState> _filesKey = GlobalKey<FilesTabState>();

  void _refreshSavedFiles() {
    _filesKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeScreen(onFileSaved: _refreshSavedFiles),
          AiStudioTab(onFileSaved: _refreshSavedFiles),
          FilesTab(key: _filesKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) {
          setState(() => _tabIndex = idx);
          if (idx == 2) _refreshSavedFiles();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            selectedIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.wand_stars),
            selectedIcon: Icon(CupertinoIcons.wand_stars),
            label: 'AI Studio',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.folder),
            selectedIcon: Icon(CupertinoIcons.folder_fill),
            label: 'Berkas Saya',
          ),
        ],
      ),
    );
  }
}
