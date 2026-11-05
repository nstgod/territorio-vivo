import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/indicator.dart';
import '../../../data/models/region.dart';
import '../../../domain/statistics.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/indicator_chart.dart';
import '../../widgets/state_views.dart';
import '../../widgets/territory_widgets.dart';

/// Dashboard temático (clima/ar, água/energia, serviços). Os três painéis
/// compartilham a estrutura, mas cada um tem indicadores, gráficos e um
/// comparativo entre regiões próprios.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.kind});

  final DashboardKind kind;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _days = 30; // estado local: janela do gráfico

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final alerts = context.watch<AlertsProvider>();
    final kind = widget.kind;
    final region = territory.selectedRegion;
    final indicators = IndicatorId.of(kind);
    final dashAlerts = alerts
        .forRegion(region.id)
        .where((a) => a.indicator.dashboard == kind)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(tag: 'dash-${kind.name}', child: Icon(kind.icon)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(kind.label)),
          ],
        ),
      ),
      body: !territory.hasData
          ? (territory.isLoading
              ? const LoadingView()
              : ErrorView(message: territory.error ?? 'Sem dados.', onRetry: territory.load))
          : RefreshIndicator(
              onRefresh: territory.load,
              child: ContentConstraint(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
                  children: [
                    const RegionSelector(),
                    const SizedBox(height: AppSpacing.sm),
                    const DataFreshnessBanner(),
                    const SizedBox(height: AppSpacing.sm),
                    Text(_intro(kind), style: Theme.of(context).textTheme.bodyMedium),
                    SectionHeader('Indicadores em ${region.name}'),
                    ResponsiveGrid(
                      children: [
                        for (final ind in indicators)
                          if (territory.series(region.id, ind) case final s?)
                            KpiTile(
                              series: s,
                              alertCount: dashAlerts.where((a) => a.indicator == ind).length,
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutes.indicator,
                                arguments: IndicatorArgs(regionId: region.id, indicator: ind),
                              ),
                            )
                          else
                            AppCard(child: Text('${ind.label}: indisponível no momento.')),
                      ],
                    ),
                    SectionHeader(
                      'Histórico e tendência',
                      action: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 14, label: Text('14d'), tooltip: 'Últimos 14 dias'),
                          ButtonSegment(value: 30, label: Text('30d'), tooltip: 'Últimos 30 dias'),
                          ButtonSegment(value: 60, label: Text('60d'), tooltip: 'Últimos 60 dias'),
                        ],
                        selected: {_days},
                        onSelectionChanged: (v) => setState(() => _days = v.first),
                      ),
                    ),
                    for (final ind in indicators) ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('${ind.label} (${ind.unit})',
                                      style: Theme.of(context).textTheme.titleSmall),
                                ),
                                OriginTag(ind.origin),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            IndicatorChart(regionId: region.id, indicator: ind, lastDays: _days),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    SectionHeader('Comparativo entre regiões', subtitle: _comparisonSubtitle(kind)),
                    _RegionComparison(kind: kind),
                    SectionHeader('Alertas deste painel'),
                    if (dashAlerts.isEmpty)
                      const AppCard(child: Text('Nenhum alerta ativo neste painel para a região.'))
                    else
                      for (final a in dashAlerts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AlertTile(
                            alert: a,
                            status: alerts.statusOf(a.id),
                            showRegion: false,
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.alert, arguments: AlertArgs(a.id)),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.sm),
                    const HumanDecisionNotice(compact: true),
                  ],
                ),
              ),
            ),
    );
  }

  static String _intro(DashboardKind kind) => switch (kind) {
        DashboardKind.climate =>
          'Temperatura, chuva e PM2,5 reais (Open-Meteo), com 30 dias de histórico e a '
              'previsão meteorológica dos próximos dias.',
        DashboardKind.resources =>
          'Consumo diário de água e energia (séries sintéticas) com previsão de 7 dias do '
              'modelo do app e faixa de incerteza de 95%.',
        DashboardKind.services =>
          'Coleta de resíduos e atendimentos nas UBS (séries sintéticas). Quedas na coleta '
              'e picos de demanda geram alertas para planejamento.',
      };

  static String _comparisonSubtitle(DashboardKind kind) => switch (kind) {
        DashboardKind.climate => 'Maior temperatura máxima prevista para os próximos dias',
        DashboardKind.resources => 'Consumo de água por habitante (média de 7 dias)',
        DashboardKind.services => 'Atendimentos nas UBS por mil habitantes (média de 7 dias)',
      };
}

class _RegionComparison extends StatelessWidget {
  const _RegionComparison({required this.kind});

  final DashboardKind kind;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final rows = <(Region, double)>[];
    for (final r in Territory.regions) {
      final double? v = switch (kind) {
        DashboardKind.climate => () {
            final f = territory.series(r.id, IndicatorId.tempMax)?.externalForecast ?? const [];
            return f.isEmpty ? null : f.map((p) => p.value).reduce((a, b) => a > b ? a : b);
          }(),
        DashboardKind.resources => () {
            final s = territory.series(r.id, IndicatorId.water)?.values ?? const <double>[];
            if (s.length < 7) return null;
            // mil m³/dia → litros/hab/dia
            return Stats.mean(s.sublist(s.length - 7)) * 1e6 / r.population;
          }(),
        DashboardKind.services => () {
            final s = territory.series(r.id, IndicatorId.healthDemand)?.values ?? const <double>[];
            if (s.length < 7) return null;
            return Stats.mean(s.sublist(s.length - 7)) * 1000 / r.population;
          }(),
      };
      if (v != null) rows.add((r, v));
    }
    if (rows.isEmpty) return const AppCard(child: Text('Sem dados suficientes para comparar.'));
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    final max = rows.first.$2;
    final unit = switch (kind) {
      DashboardKind.climate => '°C',
      DashboardKind.resources => 'L/hab/dia',
      DashboardKind.services => 'por mil hab./dia',
    };
    final decimals = kind == DashboardKind.resources ? 0 : 1;
    final selected = territory.selectedRegionId;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        children: [
          for (final (r, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Semantics(
                label: '${r.name}: ${Fmt.withUnit(v, unit, decimals: decimals)}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            style: r.id == selected ? t.titleSmall : t.bodyMedium,
                          ),
                        ),
                        Text(Fmt.withUnit(v, unit, decimals: decimals), style: t.labelLarge),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: max == 0 ? 0 : v / max,
                        minHeight: 8,
                        color: r.id == selected ? scheme.primary : scheme.primary.withValues(alpha: 0.45),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
