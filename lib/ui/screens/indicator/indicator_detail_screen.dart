import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/indicator.dart';
import '../../../data/models/occurrence.dart';
import '../../../data/models/region.dart';
import '../../../domain/forecaster.dart';
import '../../../domain/statistics.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/indicator_chart.dart';
import '../../widgets/state_views.dart';
import '../../widgets/territory_widgets.dart';

/// Detalhe de um indicador numa região: gráfico ampliado, estatísticas,
/// métricas do modelo (backtest), tabela de previsão e alertas ligados.
class IndicatorDetailScreen extends StatelessWidget {
  const IndicatorDetailScreen({super.key, required this.regionId, required this.indicator});

  final String regionId;
  final IndicatorId indicator;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final alerts = context.watch<AlertsProvider>();
    final region = Territory.byId(regionId);
    final series = territory.series(regionId, indicator);
    final related = alerts.forRegion(regionId).where((a) => a.indicator == indicator).toList();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(indicator.label),
            Text(region.name, style: t.bodySmall),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed(
          AppRoutes.newOccurrence,
          arguments: OccurrenceFormArgs(
            regionId: regionId,
            category: OccurrenceCategory.values.firstWhere(
              (c) => c.relatedIndicator == indicator,
              orElse: () => OccurrenceCategory.other,
            ),
          ),
        ),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Relatar problema'),
        tooltip: 'Registrar ocorrência relacionada a ${indicator.label}',
      ),
      body: series == null || series.isEmpty
          ? (territory.isLoading
              ? const LoadingView()
              : const EmptyView(
                  icon: Icons.insights_outlined,
                  title: 'Indicador sem dados',
                  message: 'A fonte não respondeu e não há cópia salva para esta região.',
                ))
          : ContentConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
                children: [
                  Text(indicator.description, style: t.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  OriginTag(indicator.origin),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: IndicatorChart(regionId: regionId, indicator: indicator, lastDays: 60, height: 260),
                  ),
                  SectionHeader('Estatísticas'),
                  _StatsCard(
                    values: series.values,
                    unit: indicator.unit,
                    decimals: indicator.decimals,
                  ),
                  _ForecastSection(
                    indicator: indicator,
                    result: territory.forecast(regionId, indicator),
                    external: series.externalForecast.isNotEmpty,
                  ),
                  SectionHeader('Alertas deste indicador'),
                  if (related.isEmpty)
                    const AppCard(child: Text('Nenhum alerta ativo com os limiares atuais.'))
                  else
                    for (final a in related)
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
                ],
              ),
            ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.values, required this.unit, required this.decimals});

  final List<double> values;
  final String unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final last7 = values.length >= 7 ? values.sublist(values.length - 7) : values;
    final last28 = values.length >= 28 ? values.sublist(values.length - 28) : values;
    final fit = Stats.linearFit(last28);
    String f(double v) => Fmt.withUnit(v, unit, decimals: decimals);
    final rows = [
      ('Último valor', f(values.last)),
      ('Média 7 dias', f(Stats.mean(last7))),
      ('Média 28 dias', f(Stats.mean(last28))),
      ('Desvio-padrão (28d)', f(Stats.stdDev(last28))),
      ('Mínimo / máximo (28d)', '${f(last28.reduce((a, b) => a < b ? a : b))} / ${f(last28.reduce((a, b) => a > b ? a : b))}'),
      ('Tendência linear (28d)', '${Fmt.number(fit.slope, decimals: 2)} $unit/dia'),
      ('Dias de histórico', '${values.length}'),
    ];
    return AppCard(child: _KeyValueTable(rows: rows));
  }
}

class _ForecastSection extends StatelessWidget {
  const _ForecastSection({required this.indicator, required this.result, required this.external});

  final IndicatorId indicator;
  final ForecastResult? result;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (external) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Previsão'),
          AppCard(
            child: Text(
              'A previsão deste indicador vem do modelo meteorológico/atmosférico da '
              'Open-Meteo. A confiança dos alertas diminui a cada dia de antecedência '
              '(≈ 8 pontos percentuais por dia).',
            ),
          ),
        ],
      );
    }
    final r = result;
    if (r == null) return const SizedBox.shrink();
    final u = indicator.unit;
    final d = indicator.decimals;
    final reliable = !r.backtestWape.isNaN && r.backtestWape < 0.10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Modelo e métricas', subtitle: r.method),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueTable(rows: [
                ('R² do ajuste (treino)', Fmt.number(r.r2, decimals: 2)),
                ('Desvio dos resíduos', Fmt.withUnit(r.residualStd, u, decimals: d)),
                ('Backtest · MAE (7 dias)', Fmt.withUnit(r.backtestMae, u, decimals: d)),
                ('Backtest · WAPE (7 dias)', Fmt.percent(r.backtestWape, decimals: 1)),
                (
                  'Tendência',
                  '${Fmt.number(r.trendPerDay, decimals: 2)} $u/dia · '
                      '${r.trendSignificant ? 'significativa (amortecida)' : 'não significativa (ignorada)'}',
                ),
                ('Janela de treino', '${r.trainingDays} dias'),
              ]),
              const SizedBox(height: AppSpacing.sm),
              InfoBanner(
                icon: reliable ? Icons.check_circle_outline : Icons.report_outlined,
                tone: reliable ? BannerTone.info : BannerTone.warning,
                message: reliable
                    ? 'Erro de backtest abaixo de 10%: a previsão acompanhou bem a última semana.'
                    : 'Erro de backtest alto: a última semana fugiu do padrão (evento, anomalia ou '
                        'mudança de tendência). Não use esta previsão sozinha para decidir.',
              ),
            ],
          ),
        ),
        SectionHeader('Previsão para 7 dias'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              for (final p in r.points)
                MergeSemantics(
                  child: ListTile(
                    dense: true,
                    title: Text(Fmt.weekdayDayMonth(p.date)),
                    trailing: Text(Fmt.withUnit(p.value, u, decimals: d), style: t.titleSmall),
                    subtitle: Text(
                      'Faixa de 95%: ${Fmt.number(p.lower, decimals: d)} a ${Fmt.number(p.upper, decimals: d)}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeyValueTable extends StatelessWidget {
  const _KeyValueTable({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(k, style: t.bodyMedium)),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: Text(v, style: t.titleSmall, textAlign: TextAlign.end)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
