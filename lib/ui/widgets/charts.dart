import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/time_series.dart';
import '../../domain/forecaster.dart';

/// Converte a previsão externa (sem intervalo) para o formato do gráfico.
List<ForecastPoint> forecastFromExternal(List<DataPoint> points) => [
      for (final p in points)
        ForecastPoint(date: p.date, value: p.value, lower: p.value, upper: p.value),
    ];

/// Gráfico de linha: histórico (sólido), previsão (tracejado), faixa de
/// incerteza de 95% e limiar de alerta. Tem descrição textual para leitores
/// de tela e legenda visível.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.label,
    required this.history,
    this.forecast = const [],
    this.threshold,
    this.thresholdLabel,
    required this.unit,
    this.decimals = 1,
    this.height = 220,
    this.lastDays,
  });

  final String label;
  final List<DataPoint> history;
  final List<ForecastPoint> forecast;
  final double? threshold;
  final String? thresholdLabel;
  final String unit;
  final int decimals;
  final double height;

  /// Mostra só os últimos N dias do histórico (estado local da tela).
  final int? lastDays;

  @override
  Widget build(BuildContext context) {
    final s = context.statusColors;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final hist = lastDays == null || history.length <= lastDays!
        ? history
        : history.sublist(history.length - lastDays!);
    if (hist.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('Sem dados para exibir.')));
    }

    final dates = [...hist.map((p) => p.date), ...forecast.map((p) => p.date)];
    final histSpots = [for (var i = 0; i < hist.length; i++) FlSpot(i.toDouble(), hist[i].value)];
    final n = hist.length;
    final fcSpots = [
      FlSpot((n - 1).toDouble(), hist.last.value),
      for (var i = 0; i < forecast.length; i++) FlSpot((n + i).toDouble(), forecast[i].value),
    ];
    final hasBand = forecast.any((p) => p.upper - p.lower > 1e-6);
    final upperSpots = [
      FlSpot((n - 1).toDouble(), hist.last.value),
      for (var i = 0; i < forecast.length; i++) FlSpot((n + i).toDouble(), forecast[i].upper),
    ];
    final lowerSpots = [
      FlSpot((n - 1).toDouble(), hist.last.value),
      for (var i = 0; i < forecast.length; i++) FlSpot((n + i).toDouble(), forecast[i].lower),
    ];

    final allY = [
      ...hist.map((p) => p.value),
      ...forecast.map((p) => p.upper),
      ...forecast.map((p) => p.lower),
      ?threshold,
    ];
    var minY = allY.reduce(math.min);
    var maxY = allY.reduce(math.max);
    final pad = math.max((maxY - minY) * 0.12, maxY.abs() * 0.02 + 0.5);
    minY = math.max(0, minY - pad);
    maxY = maxY + pad;

    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: histSpots,
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        color: s.chartPrimary,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: s.chartPrimary.withValues(alpha: 0.08)),
      ),
      if (forecast.isNotEmpty)
        LineChartBarData(
          spots: fcSpots,
          isCurved: true,
          curveSmoothness: 0.2,
          preventCurveOverShooting: true,
          color: s.chartForecast,
          barWidth: 2.5,
          dashArray: const [6, 4],
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, _) => spot.x >= n,
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 2.5,
              color: s.chartForecast,
              strokeWidth: 0,
            ),
          ),
        ),
      if (hasBand) ...[
        LineChartBarData(spots: upperSpots, color: Colors.transparent, barWidth: 0, dotData: const FlDotData(show: false)),
        LineChartBarData(spots: lowerSpots, color: Colors.transparent, barWidth: 0, dotData: const FlDotData(show: false)),
      ],
    ];
    final bandFrom = forecast.isNotEmpty ? 2 : 1;

    final step = math.max(1, (dates.length / 5).ceil());
    final summary = _summary(hist);

    return Semantics(
      label: summary,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (dates.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: bars,
                  betweenBarsData: hasBand
                      ? [BetweenBarsData(fromIndex: bandFrom, toIndex: bandFrom + 1, color: s.chartBand)]
                      : const [],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (threshold != null)
                        HorizontalLine(
                          y: threshold!,
                          color: s.chartThreshold,
                          strokeWidth: 1.5,
                          dashArray: const [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: t.labelSmall?.copyWith(color: s.chartThreshold, fontWeight: FontWeight.w700),
                            labelResolver: (_) => thresholdLabel ?? 'Limiar',
                          ),
                        ),
                    ],
                    verticalLines: [
                      if (forecast.isNotEmpty)
                        VerticalLine(
                          x: (n - 1).toDouble(),
                          color: scheme.outline,
                          strokeWidth: 1,
                          dashArray: const [2, 3],
                        ),
                    ],
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (v, meta) {
                          if (v == meta.min || v == meta.max) return const SizedBox.shrink();
                          return Text(_compact(v), style: t.labelSmall);
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= dates.length || i % step != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(Fmt.dayMonth(dates[i]), style: t.labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    getTouchedSpotIndicator: (bar, indexes) => indexes
                        .map((_) => bar.color == Colors.transparent
                            ? null
                            : TouchedSpotIndicatorData(
                                FlLine(color: scheme.outline, strokeWidth: 1),
                                FlDotData(show: true, getDotPainter: (_, _, b, _) =>
                                    FlDotCirclePainter(radius: 4, color: b.color ?? s.chartPrimary)),
                              ))
                        .toList(),
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) => spots.map((spot) {
                        final bar = spot.bar;
                        if (bar.color == Colors.transparent) return null;
                        final i = spot.x.round();
                        final isFc = i >= n || (forecast.isNotEmpty && spot.barIndex == 1);
                        if (isFc && i == n - 1) return null;
                        final date = i < dates.length ? Fmt.dayMonth(dates[i]) : '';
                        return LineTooltipItem(
                          '$date${isFc ? ' (previsão)' : ''}\n${Fmt.withUnit(spot.y, unit, decimals: decimals)}',
                          t.labelMedium!.copyWith(color: scheme.onInverseSurface),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                duration: AppDurations.medium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _Legend(color: s.chartPrimary, label: 'Histórico'),
                if (forecast.isNotEmpty) _Legend(color: s.chartForecast, label: 'Previsão', dashed: true),
                if (hasBand) _Legend(color: s.chartBand, label: 'Faixa de 95%', block: true),
                if (threshold != null) _Legend(color: s.chartThreshold, label: 'Limiar', dashed: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _summary(List<DataPoint> hist) {
    final last = hist.last;
    final b = StringBuffer('Gráfico de $label. ')
      ..write('${hist.length} dias de histórico; último valor ')
      ..write('${Fmt.withUnit(last.value, unit, decimals: decimals)} em ${Fmt.dayMonth(last.date)}. ');
    if (forecast.isNotEmpty) {
      final mean = forecast.map((p) => p.value).reduce((a, b) => a + b) / forecast.length;
      b.write('Previsão para ${forecast.length} dias com média de '
          '${Fmt.withUnit(mean, unit, decimals: decimals)}. ');
    }
    if (threshold != null) {
      b.write('Limiar de alerta: ${Fmt.withUnit(threshold!, unit, decimals: decimals)}.');
    }
    return b.toString();
  }

  static String _compact(double v) {
    if (v.abs() >= 10000) return '${Fmt.number(v / 1000, decimals: 0)} mil';
    if (v.abs() >= 100) return Fmt.number(v, decimals: 0);
    return Fmt.number(v, decimals: 1);
  }
}

/// Barras diárias (ex.: chuva), com dias previstos em outra cor.
class DailyBarsChart extends StatelessWidget {
  const DailyBarsChart({
    super.key,
    required this.label,
    required this.history,
    this.forecast = const [],
    this.threshold,
    required this.unit,
    this.height = 200,
    this.lastDays = 21,
  });

  final String label;
  final List<DataPoint> history;
  final List<DataPoint> forecast;
  final double? threshold;
  final String unit;
  final double height;
  final int lastDays;

  @override
  Widget build(BuildContext context) {
    final s = context.statusColors;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final hist = history.length <= lastDays ? history : history.sublist(history.length - lastDays);
    final points = [...hist, ...forecast];
    if (points.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('Sem dados para exibir.')));
    }
    final maxY = math.max(points.map((p) => p.value).reduce(math.max), threshold ?? 0) * 1.15 + 1;
    final step = math.max(1, (points.length / 5).ceil());
    final totalFc = forecast.fold<double>(0, (a, p) => a + p.value);

    return Semantics(
      container: true,
      label: 'Gráfico de barras de $label: ${hist.length} dias observados e '
          '${forecast.length} previstos, somando ${Fmt.withUnit(totalFc, unit)} na previsão.'
          '${threshold != null ? ' Limiar diário ${Fmt.withUnit(threshold!, unit, decimals: 0)}.' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: points[i].value,
                          width: math.max(3, 220 / points.length),
                          color: i >= hist.length ? s.chartForecast : s.chartPrimary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ]),
                  ],
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    if (threshold != null)
                      HorizontalLine(
                        y: threshold!,
                        color: s.chartThreshold,
                        strokeWidth: 1.5,
                        dashArray: const [4, 4],
                      ),
                  ]),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, meta) => v == meta.max
                            ? const SizedBox.shrink()
                            : Text(Fmt.number(v, decimals: 0), style: t.labelSmall),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= points.length || i % step != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(Fmt.dayMonth(points[i].date), style: t.labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, _, rod, _) {
                        final p = points[group.x];
                        return BarTooltipItem(
                          '${Fmt.dayMonth(p.date)}${group.x >= hist.length ? ' (previsão)' : ''}\n'
                          '${Fmt.withUnit(p.value, unit)}',
                          t.labelMedium!.copyWith(color: scheme.onInverseSurface),
                        );
                      },
                    ),
                  ),
                ),
                duration: AppDurations.medium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: Wrap(
              spacing: AppSpacing.md,
              children: [
                _Legend(color: s.chartPrimary, label: 'Observado', block: true),
                if (forecast.isNotEmpty) _Legend(color: s.chartForecast, label: 'Previsto', block: true),
                if (threshold != null) _Legend(color: s.chartThreshold, label: 'Limiar', dashed: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minigráfico para os cards de KPI.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.color, this.height = 36});

  final List<double> values;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    final c = color ?? context.statusColors.chartPrimary;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            lineTouchData: const LineTouchData(enabled: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
                isCurved: true,
                preventCurveOverShooting: true,
                color: c,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: c.withValues(alpha: 0.12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dashed = false, this.block = false});

  final Color color;
  final String label;
  final bool dashed;
  final bool block;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (block)
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))
        else
          SizedBox(
            width: 18,
            height: 12,
            child: CustomPaint(painter: _LinePainter(color, dashed)),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      return;
    }
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.color != color || old.dashed != dashed;
}
