import 'package:material_ui/material_ui.dart';

/// Colours taken from the Joshdepp design: near-black green surfaces with a
/// single lime accent.
abstract final class Palette {
  static const background = Color(0xFF0E130F);
  static const card = Color(0xFF2A302B);
  static const cardRaised = Color(0xFF363D37);
  static const field = Color(0xFF1B211C);
  static const lime = Color(0xFFC0E60F);
  static const limeDeep = Color(0xFFA9CF00);
  static const onLime = Color(0xFF10150B);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFF99A39A);
  static const danger = Color(0xFFFF6B5E);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Lexend',
    scaffoldBackgroundColor: Palette.background,
    colorScheme: const ColorScheme.dark(
      primary: Palette.lime,
      onPrimary: Palette.onLime,
      secondary: Palette.lime,
      onSecondary: Palette.onLime,
      surface: Palette.background,
      onSurface: Palette.text,
      error: Palette.danger,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.text,
      displayColor: Palette.text,
    ),
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.cardRaised,
      contentTextStyle: TextStyle(
        fontFamily: 'Lexend',
        color: Palette.text,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.onLime
            : Palette.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.lime
            : Palette.field,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
