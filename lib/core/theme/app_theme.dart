import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Cores semânticas (severidade, confiança, fonte de dado) que variam por
/// tema. Fica numa [ThemeExtension] para que os componentes reutilizáveis
/// peçam "cor de crítico" e recebam o tom certo em claro, escuro e alto
/// contraste — sem `if (dark)` espalhado pelas telas.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.critical,
    required this.onCritical,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.ok,
    required this.onOk,
    required this.chartPrimary,
    required this.chartForecast,
    required this.chartBand,
    required this.chartThreshold,
  });

  final Color critical;
  final Color onCritical;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;
  final Color ok;
  final Color onOk;
  final Color chartPrimary;
  final Color chartForecast;
  final Color chartBand;
  final Color chartThreshold;

  static const light = StatusColors(
    critical: AppPalette.red700,
    onCritical: Colors.white,
    warning: AppPalette.amber600,
    onWarning: Colors.white,
    info: AppPalette.blue700,
    onInfo: Colors.white,
    ok: AppPalette.green700,
    onOk: Colors.white,
    chartPrimary: AppPalette.teal700,
    chartForecast: AppPalette.amber600,
    chartBand: Color(0x33B26A00),
    chartThreshold: AppPalette.red700,
  );

  static const dark = StatusColors(
    critical: AppPalette.red300,
    onCritical: Color(0xFF3B0907),
    warning: AppPalette.amber300,
    onWarning: Color(0xFF3A2500),
    info: AppPalette.blue300,
    onInfo: Color(0xFF07254A),
    ok: AppPalette.green300,
    onOk: Color(0xFF00391A),
    chartPrimary: Color(0xFF6FD6C6),
    chartForecast: AppPalette.amber300,
    chartBand: Color(0x40FFC857),
    chartThreshold: AppPalette.red300,
  );

  /// Alto contraste: pares com razão de contraste >= 7:1 (WCAG AAA).
  static const highContrastLight = StatusColors(
    critical: Color(0xFF8B0000),
    onCritical: Colors.white,
    warning: Color(0xFF5C3A00),
    onWarning: Colors.white,
    info: Color(0xFF002F6C),
    onInfo: Colors.white,
    ok: Color(0xFF004D1A),
    onOk: Colors.white,
    chartPrimary: Colors.black,
    chartForecast: Color(0xFF5C3A00),
    chartBand: Color(0x405C3A00),
    chartThreshold: Color(0xFF8B0000),
  );

  static const highContrastDark = StatusColors(
    critical: Color(0xFFFFB4AB),
    onCritical: Colors.black,
    warning: Color(0xFFFFE066),
    onWarning: Colors.black,
    info: Color(0xFFB8D8FF),
    onInfo: Colors.black,
    ok: Color(0xFFA6F5BF),
    onOk: Colors.black,
    chartPrimary: Colors.white,
    chartForecast: Color(0xFFFFE066),
    chartBand: Color(0x55FFE066),
    chartThreshold: Color(0xFFFFB4AB),
  );

  @override
  StatusColors copyWith({
    Color? critical,
    Color? onCritical,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? ok,
    Color? onOk,
    Color? chartPrimary,
    Color? chartForecast,
    Color? chartBand,
    Color? chartThreshold,
  }) {
    return StatusColors(
      critical: critical ?? this.critical,
      onCritical: onCritical ?? this.onCritical,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      ok: ok ?? this.ok,
      onOk: onOk ?? this.onOk,
      chartPrimary: chartPrimary ?? this.chartPrimary,
      chartForecast: chartForecast ?? this.chartForecast,
      chartBand: chartBand ?? this.chartBand,
      chartThreshold: chartThreshold ?? this.chartThreshold,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      critical: Color.lerp(critical, other.critical, t)!,
      onCritical: Color.lerp(onCritical, other.onCritical, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      onOk: Color.lerp(onOk, other.onOk, t)!,
      chartPrimary: Color.lerp(chartPrimary, other.chartPrimary, t)!,
      chartForecast: Color.lerp(chartForecast, other.chartForecast, t)!,
      chartBand: Color.lerp(chartBand, other.chartBand, t)!,
      chartThreshold: Color.lerp(chartThreshold, other.chartThreshold, t)!,
    );
  }
}

extension StatusColorsX on BuildContext {
  StatusColors get statusColors =>
      Theme.of(this).extension<StatusColors>() ?? StatusColors.light;
}

/// Fábrica dos quatro temas do app: claro, escuro e as duas variantes de
/// alto contraste.
abstract final class AppTheme {
  static ThemeData light({bool highContrast = false}) =>
      _build(Brightness.light, highContrast: highContrast);

  static ThemeData dark({bool highContrast = false}) =>
      _build(Brightness.dark, highContrast: highContrast);

  static ThemeData _build(Brightness brightness, {required bool highContrast}) {
    final isDark = brightness == Brightness.dark;
    final ColorScheme scheme = _scheme(isDark: isDark, highContrast: highContrast);
    final StatusColors status = switch ((isDark, highContrast)) {
      (false, false) => StatusColors.light,
      (true, false) => StatusColors.dark,
      (false, true) => StatusColors.highContrastLight,
      (true, true) => StatusColors.highContrastDark,
    };

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    final textTheme = _textTheme(base.textTheme, scheme);
    final borderSide = BorderSide(
      color: highContrast ? scheme.onSurface : scheme.outlineVariant,
      width: highContrast ? 2 : 1,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: [status],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: borderSide,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: borderSide,
        labelStyle: textTheme.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        height: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: borderSide.color, thickness: 1),
    );
  }

  static ColorScheme _scheme({required bool isDark, required bool highContrast}) {
    if (highContrast) {
      return isDark
          ? const ColorScheme.highContrastDark(
              primary: Color(0xFF8CF5E4),
              onPrimary: Colors.black,
              secondary: Color(0xFFFFE066),
              onSecondary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ).copyWith(
              surfaceContainerLow: const Color(0xFF0A0A0A),
              surfaceContainer: const Color(0xFF121212),
              surfaceContainerHighest: const Color(0xFF1E1E1E),
              secondaryContainer: const Color(0xFF00382F),
              onSecondaryContainer: Colors.white,
              outlineVariant: Colors.white,
            )
          : const ColorScheme.highContrastLight(
              primary: Color(0xFF00382F),
              onPrimary: Colors.white,
              secondary: Color(0xFF5C3A00),
              onSecondary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ).copyWith(
              surfaceContainerLow: Colors.white,
              surfaceContainer: const Color(0xFFF2F2F2),
              surfaceContainerHighest: const Color(0xFFE6E6E6),
              secondaryContainer: const Color(0xFFB2DFDB),
              onSecondaryContainer: Colors.black,
              outlineVariant: Colors.black,
            );
    }
    final seeded = ColorScheme.fromSeed(
      seedColor: AppPalette.teal700,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    return isDark
        ? seeded
        : seeded.copyWith(
            primary: AppPalette.teal700,
            surface: AppPalette.sand50,
            onSurface: AppPalette.ink,
          );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    // Pesos e alturas de linha padronizados; tamanhos seguem o Material 3,
    // que já respeita a escala de fonte do sistema e a do app.
    return base
        .copyWith(
          headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
