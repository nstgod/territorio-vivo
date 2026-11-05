import 'package:flutter/material.dart';

import '../../data/models/indicator.dart';
import '../../data/models/occurrence.dart';
import '../../ui/screens/about/methodology_screen.dart';
import '../../ui/screens/alerts/alert_detail_screen.dart';
import '../../ui/screens/alerts/alerts_screen.dart';
import '../../ui/screens/consent/consent_screen.dart';
import '../../ui/screens/dashboards/dashboard_screen.dart';
import '../../ui/screens/indicator/indicator_detail_screen.dart';
import '../../ui/screens/occurrences/occurrence_form_screen.dart';
import '../../ui/screens/settings/thresholds_form_screen.dart';
import '../../ui/screens/shell/root_gate.dart';

/// Argumentos tipados das rotas (passagem de parâmetros entre telas).
class IndicatorArgs {
  const IndicatorArgs({required this.regionId, required this.indicator});
  final String regionId;
  final IndicatorId indicator;
}

class AlertArgs {
  const AlertArgs(this.alertId);
  final String alertId;
}

class AlertsArgs {
  const AlertsArgs({this.regionId});
  final String? regionId;
}

class OccurrenceFormArgs {
  const OccurrenceFormArgs({this.regionId, this.category});
  final String? regionId;
  final OccurrenceCategory? category;
}

/// Rotas nomeadas do app.
///
/// Fluxo principal: visão geral → dashboard → detalhe do indicador →
/// detalhe do alerta → decisão humana.
abstract final class AppRoutes {
  static const root = '/';
  static const consent = '/consent';
  static const dashboard = '/dashboard';
  static const indicator = '/indicator';
  static const alerts = '/alerts';
  static const alert = '/alert';
  static const newOccurrence = '/occurrences/new';
  static const thresholds = '/settings/thresholds';
  static const methodology = '/about';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget page = switch (settings.name) {
      root => const RootGate(),
      consent => const ConsentScreen(),
      dashboard => DashboardScreen(kind: args is DashboardKind ? args : DashboardKind.climate),
      indicator when args is IndicatorArgs =>
        IndicatorDetailScreen(regionId: args.regionId, indicator: args.indicator),
      alerts => AlertsScreen(initialRegionId: args is AlertsArgs ? args.regionId : null, standalone: true),
      alert when args is AlertArgs => AlertDetailScreen(alertId: args.alertId),
      newOccurrence => OccurrenceFormScreen(args: args is OccurrenceFormArgs ? args : const OccurrenceFormArgs()),
      thresholds => const ThresholdsFormScreen(),
      methodology => const MethodologyScreen(),
      _ => const _NotFoundScreen(),
    };
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Página não encontrada')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false),
          child: const Text('Voltar ao início'),
        ),
      ),
    );
  }
}
