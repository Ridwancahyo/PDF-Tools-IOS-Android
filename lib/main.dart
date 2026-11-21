import 'package:material_ui/material_ui.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfStudioProApp());
}

class PdfStudioProApp extends StatelessWidget {
  const PdfStudioProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (_, mode, _) {
        return MaterialApp(
          title: 'PDF Studio Pro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const MainShell(),
        );
      },
    );
  }
}
