import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/alert.dart';
import '../../../data/models/indicator.dart';
import '../../../data/models/region.dart';
import '../../../domain/social_impact.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/territory_provider.dart';
import '../../../state/view_status.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import '../../widgets/territory_widgets.dart';

/// Visão geral: estado da região selecionada, atalhos para os painéis,
/// principais alertas e indicador de benefício social.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.onOpenAlerts});

  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final t = Theme.of(context).textTheme;

    final Widget body;
    if (!territory.hasData && territory.status != ViewStatus.error) {
      body = const LoadingView();
    } else if (!territory.hasData) {
      body = ErrorView(
        title: 'Sem dados disponíveis',
        message: territory.error ?? 'Tente novamente.',
        onRetry: territory.load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: territory.load,
        child: ContentConstraint(child: _OverviewContent(onOpenAlerts: onOpenAlerts)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Território Vivo'),
            Text(Territory.name, style: t.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Metodologia e limitações',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.methodology),
          ),
          IconButton(
            tooltip: 'Atualizar dados',
            icon: territory.isLoading
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: territory.isLoading ? null : territory.load,
          ),
        ],
      ),
      body: AnimatedSwitcher(duration: AppDurations.medium, child: body),
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.onOpenAlerts});

  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final alertsState = context.watch<AlertsProvider>();
    final region = territory.selectedRegion;
    final regionAlerts = alertsState.forRegion(region.id);
    final top = regionAlerts.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
      children: [
        const DataFreshnessBanner(),
        const SizedBox(height: AppSpacing.md),
        const RegionSelector(),
        const SizedBox(height: AppSpacing.md),
        _RegionSummary(
          regionName: region.name,
          population: region.population,
          alerts: regionAlerts,
          statusOf: alertsState.statusOf,
        ),
        const SizedBox(height: AppSpacing.md),
        const HumanDecisionNotice(compact: true),
        SectionHeader('Painéis territoriais', subtitle: 'Histórico, tendência e previsão por tema'),
        ResponsiveGrid(
          children: [
            for (final kind in DashboardKind.values)
              _DashboardCard(
                kind: kind,
                alertCount: regionAlerts.where((a) => a.indicator.dashboard == kind).length,
              ),
          ],
        ),
        SectionHeader(
          'Alertas em ${region.name}',
          subtitle: regionAlerts.isEmpty ? null : 'Ordenados por gravidade e confiança',
          action: TextButton(onPressed: onOpenAlerts, child: const Text('Ver todos')),
        ),
        if (top.isEmpty)
          const AppCard(
            child: Row(
              children: [
                Icon(Icons.check_circle_outline),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Nenhum alerta ativo para esta região com os limiares atuais.')),
              ],
            ),
          )
        else
          for (final a in top)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AlertTile(
                alert: a,
                status: alertsState.statusOf(a.id),
                showRegion: false,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.alert, arguments: AlertArgs(a.id)),
              ),
            ),
        SectionHeader('Impacto social', subtitle: 'Toda a Zona Leste monitorada'),
        SocialImpactCard(impact: alertsState.impact),
      ],
    );
  }
}

class _RegionSummary extends StatelessWidget {
  const _RegionSummary({
    required this.regionName,
    required this.population,
    required this.alerts,
    required this.statusOf,
  });

  final String regionName;
  final int population;
  final List<TerritoryAlert> alerts;
  final DecisionStatus Function(String) statusOf;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.statusColors;
    final critical = alerts.where((a) => a.severity == AlertSeverity.critical).length;
    final pending = alerts.where((a) => statusOf(a.id) == DecisionStatus.pending).length;
    final (color, icon, headline) = critical > 0
        ? (s.critical, Icons.error_outline, '$critical alerta(s) crítico(s)')
        : alerts.isNotEmpty
            ? (s.warning, Icons.warning_amber_rounded, '${alerts.length} alerta(s) de atenção')
            : (s.ok, Icons.verified_outlined, 'Situação estável');

    return AppCard(
      semanticLabel: '$regionName: $headline. $pending aguardando análise. '
          'População aproximada ${Fmt.integer(population)} habitantes.',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(regionName, style: t.titleLarge),
                  Text(headline, style: t.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
                  Text(
                    '$pending aguardando análise · ~${Fmt.integer(population)} habitantes',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.kind, required this.alertCount});

  final DashboardKind kind;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final indicators = IndicatorId.of(kind).map((i) => i.shortName).join(' · ');
    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.dashboard, arguments: kind),
      semanticLabel: 'Painel ${kind.label}: $indicators. '
          '${alertCount > 0 ? '$alertCount alerta(s).' : 'Sem alertas.'} Toque para abrir.',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Hero(
              tag: 'dash-${kind.name}',
              child: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Icon(kind.icon),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.label, style: t.titleSmall),
                  Text(indicators, style: t.bodySmall),
                ],
              ),
            ),
            if (alertCount > 0)
              Badge(
                label: Text('$alertCount'),
                backgroundColor: context.statusColors.warning,
                textColor: context.statusColors.onWarning,
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// Indicadores de benefício social (reutilizado na metodologia).
class SocialImpactCard extends StatelessWidget {
  const SocialImpactCard({super.key, required this.impact});

  final SocialImpact impact;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.groups_outlined,
        Fmt.integer(impact.populationMonitored),
        'habitantes cobertos pelo monitoramento',
      ),
      (
        Icons.health_and_safety_outlined,
        Fmt.integer(impact.populationInAlertAreas),
        'pessoas em regiões com alerta que podem ser preparadas com antecedência',
      ),
      (
        Icons.water_drop_outlined,
        '${Fmt.integer(impact.waterSavedM3)} m³',
        'de água potencialmente preservados com anomalias confirmadas pelo gestor',
      ),
      (
        Icons.fact_check_outlined,
        '${impact.alertsReviewed}/${impact.alertsTotal}',
        'alertas analisados por uma pessoa (${Fmt.percent(impact.reviewRate)})',
      ),
      (
        Icons.campaign_outlined,
        '${impact.citizenReports}',
        'ocorrências registradas por cidadãos, de forma anônima',
      ),
    ];
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        children: [
          for (final (icon, value, label) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
              child: MergeSemantics(
                child: Row(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '$value ', style: t.titleMedium),
                          TextSpan(text: label, style: t.bodyMedium),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          Text(
            'Volumes de água estimados a partir de séries sintéticas — ilustram o '
            'método, não economia real medida.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
