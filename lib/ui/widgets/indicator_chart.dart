import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/alert_thresholds.dart';
import '../../data/models/indicator.dart';
import '../../data/models/time_series.dart';
import '../../domain/statistics.dart';
import '../../state/settings_provider.dart';
import '../../state/territory_provider.dart';
import 'charts.dart';

/// Linha de limiar que corresponde à regra de alerta de cada indicador.
(double, String)? thresholdLineFor(IndicatorId id, TimeSeries s, AlertThresholds t) {
  switch (id) {
    case IndicatorId.tempMax:
      return (t.heatMaxTemp, 'Calor ${Fmt.number(t.heatMaxTemp, decimals: 0)} °C');
    case IndicatorId.precipitation:
      return (t.rainDailyMm, '${Fmt.number(t.rainDailyMm, decimals: 0)} mm');
    case IndicatorId.pm25:
      return (t.pm25, 'PM2,5 ${Fmt.number(t.pm25, decimals: 0)}');
    case IndicatorId.water:
    case IndicatorId.energy:
    case IndicatorId.healthDemand:
    case IndicatorId.waste:
      final h = s.history;
      if (h.length < 35) return null;
      final base = Stats.mean(h.sublist(h.length - 35, h.length - 7).map((p) => p.value).toList());
      final pct = switch (id) {
        IndicatorId.water => t.waterRisePct,
        IndicatorId.energy => t.energyRisePct,
        IndicatorId.healthDemand => t.healthRisePct,
        _ => -t.wasteDropPct,
      };
      return (base * (1 + pct / 100), '${pct > 0 ? '+' : ''}${Fmt.number(pct, decimals: 0)}% da base');
  }
}

/// Gráfico do indicador já ligado ao estado global (série, previsão e
/// limiar atual). Reutilizado no dashboard, no detalhe do indicador e no
/// detalhe do alerta.
class IndicatorChart extends StatelessWidget {
  const IndicatorChart({
    super.key,
    required this.regionId,
    required this.indicator,
    this.lastDays,
    this.height = 220,
  });

  final String regionId;
  final IndicatorId indicator;
  final int? lastDays;
  final double height;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final thresholds = context.select<SettingsProvider, AlertThresholds>((s) => s.thresholds);
    final s = territory.series(regionId, indicator);
    if (s == null || s.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Indicador indisponível: fonte sem dados e sem cache.')),
      );
    }
    final line = thresholdLineFor(indicator, s, thresholds);
    if (indicator == IndicatorId.precipitation) {
      return DailyBarsChart(
        label: indicator.label,
        history: s.history,
        forecast: s.externalForecast,
        threshold: line?.$1,
        unit: indicator.unit,
        height: height,
        lastDays: lastDays ?? 21,
      );
    }
    final forecast = s.externalForecast.isNotEmpty
        ? forecastFromExternal(s.externalForecast)
        : territory.forecast(regionId, indicator)?.points ?? const [];
    return TrendChart(
      label: indicator.label,
      history: s.history,
      forecast: forecast,
      threshold: line?.$1,
      thresholdLabel: line?.$2,
      unit: indicator.unit,
      decimals: indicator.decimals,
      height: height,
      lastDays: lastDays,
    );
  }
}
