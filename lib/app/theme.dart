import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens for LIFEVERSE — "after hours": emerald, gold and danger red
/// over paper (light) or ink (dark). Jakarta for UI, Fraunces for display type.
class LvColors {
  const LvColors._();

  static const violet = Color(0xFF176B52);
  static const violetLight = Color(0xFF1FA37A);
  static const coral = Color(0xFFC44536);
  static const amber = Color(0xFFE6A93D);
  static const teal = Color(0xFF168C8C);
  static const rose = Color(0xFFB8324A);
  static const leaf = Color(0xFF2F8F5B);

  // Kept for existing references.
  static const indigo = violet;
  static const saffron = amber;

  static const creamBg = Color(0xFFF7F5EF);
  static const nightBg = Color(0xFF111316);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF176B52), Color(0xFFE6A93D), Color(0xFFC44536)],
    stops: [0, 0.58, 1],
  );

  static const stat = {
    'knowledge': Color(0xFF5B6CE0),
    'discipline': Color(0xFF8C5BD6),
    'communication': Color(0xFF14A394),
    'wellbeing': Color(0xFF2FA866),
    'energy': Color(0xFFE79A1C),
    'health': Color(0xFFD9546E),
    'looks': Color(0xFFC2569B),
    'fame': Color(0xFFD9A31C),
  };

  static const npc = [
    Color(0xFFE5486F),
    Color(0xFF5B6CE0),
    Color(0xFF8D6E4F),
    Color(0xFF14A394),
    Color(0xFFD9772B),
    Color(0xFF7B4FD6),
  ];
}

class LvFonts {
  const LvFonts._();
  static const ui = 'Jakarta';
  static const display = 'Fraunces';
}

class LvRadii {
  const LvRadii._();
  static const card = 8.0;
  static const control = 8.0;
  static const sheet = 16.0;
}

class LvTheme {
  const LvTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static TextTheme _text(TextTheme base, ColorScheme s) {
    TextStyle? disp(TextStyle? t, double size, FontWeight w) => t?.copyWith(
      fontFamily: LvFonts.display,
      fontSize: size,
      fontWeight: w,
      letterSpacing: 0,
      color: s.onSurface,
    );
    final ui = base.apply(
      fontFamily: LvFonts.ui,
      bodyColor: s.onSurface,
      displayColor: s.onSurface,
    );
    return ui.copyWith(
      displaySmall: disp(ui.displaySmall, 38, FontWeight.w700),
      headlineLarge: disp(ui.headlineLarge, 32, FontWeight.w700),
      headlineMedium: disp(ui.headlineMedium, 28, FontWeight.w700),
      headlineSmall: disp(ui.headlineSmall, 24, FontWeight.w600),
      titleLarge: ui.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: 0,
      ),
      titleMedium: ui.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16.5,
      ),
      titleSmall: ui.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
      ),
      bodyLarge: ui.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: ui.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45),
      bodySmall: ui.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.4,
        color: s.onSurfaceVariant,
      ),
      labelLarge: ui.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 14.5,
        letterSpacing: 0,
      ),
      labelMedium: ui.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static ThemeData _build(Brightness b) {
    final light = b == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: LvColors.violet,
      brightness: b,
      primary: light ? LvColors.violet : const Color(0xFF5ED8A5),
      secondary: light ? const Color(0xFF168C8C) : const Color(0xFF58D5D5),
      tertiary: light ? const Color(0xFFC44536) : const Color(0xFFFF8D7F),
      error: light ? const Color(0xFFB8324A) : const Color(0xFFFF8FA1),
      surface: light ? const Color(0xFFFFFEFA) : const Color(0xFF1A1E22),
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: b,
      fontFamily: LvFonts.ui,
    );
    final text = _text(base.textTheme, scheme);
    const buttonText = TextStyle(
      fontFamily: LvFonts.ui,
      fontWeight: FontWeight.w700,
      fontSize: 15,
      letterSpacing: 0,
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: light ? LvColors.creamBg : LvColors.nightBg,
      cardTheme: CardThemeData(
        elevation: 0,
        color: light ? Colors.white : const Color(0xFF1A1E22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LvRadii.card),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: light ? 0.45 : 0.25),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        systemOverlayStyle: light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: LvFonts.display,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(52, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(52, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: scheme.primary.withValues(alpha: 0.45),
            width: 1.4,
          ),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: buttonText.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh.withValues(
            alpha: light ? 0.9 : 0.6,
          ),
          shape: const CircleBorder(),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: light ? Colors.white : const Color(0xFF221E30),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LvRadii.sheet),
        ),
        titleTextStyle: TextStyle(
          fontFamily: LvFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: light ? Colors.white : const Color(0xFF1E1A2B),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LvRadii.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: light
            ? const Color(0xFF151719)
            : const Color(0xFFEAF6EF),
        contentTextStyle: TextStyle(
          fontFamily: LvFonts.ui,
          fontWeight: FontWeight.w600,
          color: light ? Colors.white : const Color(0xFF151719),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 6,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        labelStyle: text.labelMedium,
        selectedColor: scheme.primaryContainer,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: const StadiumBorder(),
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? const Color(0xFFF4EFF9) : const Color(0xFF241F33),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LvRadii.control),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LvRadii.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LvRadii.control),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.15),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: light ? Colors.white : const Color(0xFF17141F),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: light ? 0.14 : 0.3),
        indicatorShape: const StadiumBorder(),
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (st) => TextStyle(
            fontFamily: LvFonts.ui,
            fontSize: 12,
            fontWeight: st.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: st.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (st) => IconThemeData(
            color: st.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: light ? Colors.white : const Color(0xFF17141F),
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: const StadiumBorder(),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LvRadii.control),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 24,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
