import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'state/settings_provider.dart';

class TerritorioVivoApp extends StatelessWidget {
  const TerritorioVivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Território Vivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(highContrast: settings.highContrast),
      darkTheme: AppTheme.dark(highContrast: settings.highContrast),
      themeMode: settings.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 250),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.root,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        // Escala de fonte do app multiplicada pela do sistema (acessibilidade).
        final mq = MediaQuery.of(context);
        final systemScale = mq.textScaler.scale(1);
        final scale = (systemScale * settings.textScale).clamp(0.85, 2.6);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
