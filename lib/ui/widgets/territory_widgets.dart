import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/indicator.dart';
import '../../data/models/region.dart';
import '../../data/models/time_series.dart';
import '../../domain/statistics.dart';
import '../../state/settings_provider.dart';
import '../../state/territory_provider.dart';
import 'charts.dart';
import 'common.dart';

/// Seletor de região compartilhado (altera o estado global).
class RegionSelector extends StatelessWidget {
  const RegionSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: Territory.regions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final r = Territory.regions[i];
          final selected = r.id == territory.selectedRegionId;
          return ChoiceChip(
            label: Text(r.name),
            selected: selected,
            tooltip: 'Selecionar região ${r.name}',
            onSelected: (_) => territory.selectRegion(r.id),
          );
        },
      ),
    );
  }
}

/// Mostra de onde vieram os dados e quando (ao vivo, cache, offline).
class DataFreshnessBanner extends StatelessWidget {
  const DataFreshnessBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final offline = context.select<SettingsProvider, bool>((s) => s.simulateOffline);
    final fetched = territory.fetchedAt;
    if (!territory.hasData || fetched == null) return const SizedBox.shrink();
    if (!territory.fromCache) {
      return Semantics(
        label: 'Dados atualizados ${Fmt.relative(fetched)}',
        child: Row(
          children: [
            Icon(Icons.cloud_done_outlined, size: 16, color: context.statusColors.ok),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Dados ao vivo · atualizados ${Fmt.relative(fetched)} (${Fmt.dateTime(fetched)})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    return InfoBanner(
      icon: Icons.cloud_off_outlined,
      tone: BannerTone.warning,
      title: offline ? 'Modo offline' : 'Sem conexão: exibindo dados salvos',
      message: 'Última atualização ${Fmt.relative(fetched)} (${Fmt.dateTime(fetched)}). '
          'Os alertas continuam funcionando, com confiança reduzida pela idade dos dados.',
    );
  }
}

/// Cartão de indicador: valor atual, variação vs. semana anterior,
/// minigráfico e origem do dado.
class KpiTile extends StatelessWidget {
  const KpiTile({super.key, required this.series, this.onTap, this.alertCount = 0});

  final TimeSeries series;
  final VoidCallback? onTap;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final ind = series.indicator;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final s = context.statusColors;
    final latest = series.latest;
    final values = series.values;
    final recent = values.length >= 14 ? values.sublist(values.length - 7) : values;
    final prior = values.length >= 14
        ? values.sublist(values.length - 14, values.length - 7)
        : const <double>[];
    final delta = prior.isEmpty ? double.nan : (Stats.mean(recent) - Stats.mean(prior)) / Stats.mean(prior);
    final spark = values.length > 21 ? values.sublist(values.length - 21) : values;
    final trendIcon = delta.isNaN
        ? Icons.remove
        : delta > 0.01
            ? Icons.trending_up
            : delta < -0.01
                ? Icons.trending_down
                : Icons.trending_flat;
    final valueText = latest == null ? '—' : Fmt.number(latest.value, decimals: ind.decimals);

    return AppCard(
      onTap: onTap,
      semanticLabel: '${ind.label}: $valueText ${ind.unit}'
          '${latest != null ? ' em ${Fmt.dayMonth(latest.date)}' : ''}. '
          'Média de 7 dias ${delta.isNaN ? 'sem comparação' : '${Fmt.percent(delta, decimals: 1, signed: true)} em relação à semana anterior'}. '
          '${alertCount > 0 ? '$alertCount alerta(s). ' : ''}${ind.origin.label}. Toque para detalhes.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ind.icon, color: scheme.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(ind.label, style: t.titleSmall)),
                if (alertCount > 0)
                  Badge(
                    label: Text('$alertCount'),
                    backgroundColor: s.critical,
                    textColor: s.onCritical,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: AppSpacing.xs,
              children: [
                Text(valueText, style: t.headlineSmall),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(ind.unit, style: t.bodySmall),
                ),
              ],
            ),
            Row(
              children: [
                Icon(trendIcon, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    delta.isNaN ? 'sem comparação' : '${Fmt.percent(delta, decimals: 1, signed: true)} vs. semana anterior',
                    style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Sparkline(values: spark),
            const SizedBox(height: AppSpacing.xs),
            OriginTag(ind.origin),
          ],
        ),
      ),
    );
  }
}

class OriginTag extends StatelessWidget {
  const OriginTag(this.origin, {super.key});

  final DataOrigin origin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          origin == DataOrigin.real ? Icons.public : Icons.science_outlined,
          size: 14,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            origin.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
