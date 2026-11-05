import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/settings_provider.dart';
import '../consent/consent_screen.dart';
import 'home_shell.dart';

/// Primeira rota: sem consentimento registrado, mostra a etapa de
/// consentimento; depois, o app.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final hasConsent = context.select<SettingsProvider, bool>((s) => s.hasConsent);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: hasConsent
          ? const HomeShell(key: ValueKey('home'))
          : const ConsentScreen(key: ValueKey('consent'), onboarding: true),
    );
  }
}
