import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Palette.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await AppState.instance.init();
  runApp(const JoshdeppApp());
}

class JoshdeppApp extends StatelessWidget {
  const JoshdeppApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joshdepp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => AppState.instance.onboarded
            ? const HomeScreen()
            : const OnboardingScreen(),
      ),
    );
  }
}
