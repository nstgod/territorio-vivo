import 'dart:math' as math;

import '../core/utils/formatters.dart';
import '../data/models/alert.dart';
import '../data/models/alert_thresholds.dart';
import '../data/models/indicator.dart';
import '../data/models/region.dart';
import '../data/models/time_series.dart';
import 'forecaster.dart';
import 'statistics.dart';

/// Contexto de uma avaliação: dados da região + configuração do gestor.
class AlertContext {
  const AlertContext({
    required this.region,
    required this.snapshot,
    required this.thresholds,
    required this.now,
    this.citizenReports = const {},
  });

  final Region region;
  final RegionSnapshot snapshot;
  final AlertThresholds thresholds;
  final DateTime now;

  /// Relatos cidadãos recentes (7 dias) por indicador relacionado.
  /// Entram só como evidência complementar, não na nota de confiança.
  final Map<IndicatorId, int> citizenReports;
}

/// Motor de regras + modelos estatísticos que transforma séries em alertas
/// explicáveis. Não toma decisões: apenas sinaliza, com evidência,
/// confiança e limitações, para que um humano avalie.
class AlertEngine {
  const AlertEngine({this.forecaster = const Forecaster()});

  final Forecaster forecaster;

  List<TerritoryAlert> evaluate(AlertContext ctx) {
    final alerts = <TerritoryAlert>[
      ?_heat(ctx),
      ?_rain(ctx),
      ?_air(ctx),
    ];
    for (final spec in _consumptionSpecs(ctx.thresholds)) {
      final anomaly = _anomaly(ctx, spec);
      if (anomaly != null) {
        alerts.add(anomaly);
        continue; // evita alerta duplicado de previsão para o mesmo indicador
      }
      final trend = _forecastChange(ctx, spec);
      if (trend != null) alerts.add(trend);
    }
    alerts.sort((a, b) {
      final s = b.severity.rank.compareTo(a.severity.rank);
      return s != 0 ? s : b.confidence.score.compareTo(a.confidence.score);
    });
    return alerts;
  }

  // ---------------------------------------------------------------------
  // Clima (dados reais + previsão meteorológica da fonte)
  // ---------------------------------------------------------------------

  TerritoryAlert? _heat(AlertContext ctx) {
    final s = ctx.snapshot[IndicatorId.tempMax];
    if (s == null || s.externalForecast.isEmpty) return null;
    final t = ctx.thresholds;
    final days = _upcoming(s.externalForecast, ctx.now);
    if (days.isEmpty) return null;

    var bestStart = -1, bestLen = 0, curStart = -1, curLen = 0;
    for (var i = 0; i < days.length; i++) {
      if (days[i].value >= t.heatMaxTemp) {
        if (curLen == 0) curStart = i;
        curLen++;
        if (curLen > bestLen) {
          bestLen = curLen;
          bestStart = curStart;
        }
      } else {
        curLen = 0;
      }
    }
    final peak = days.reduce((a, b) => a.value >= b.value ? a : b);
    final isWave = bestLen >= t.heatConsecutiveDays;
    final isExtremeDay = peak.value >= t.heatMaxTemp + 2;
    if (!isWave && !isExtremeDay) return null;

    final severity = (peak.value >= t.heatMaxTemp + 3 || bestLen >= 5)
        ? AlertSeverity.critical
        : AlertSeverity.attention;
    final firstIdx = isWave ? bestStart : days.indexOf(peak);
    final hist = s.values;
    final baseline = hist.isEmpty ? double.nan : Stats.mean(hist);
    final u = IndicatorId.tempMax.unit;

    return _build(
      ctx,
      kind: AlertKind.heatWave,
      indicator: IndicatorId.tempMax,
      severity: severity,
      title: isWave
          ? 'Onda de calor prevista: $bestLen dias ≥ ${Fmt.number(t.heatMaxTemp, decimals: 0)} $u'
          : 'Dia de calor extremo previsto (${Fmt.withUnit(peak.value, u)})',
      summary:
          'A previsão meteorológica indica temperaturas acima do limiar a partir de '
          '${Fmt.weekdayDayMonth(days[firstIdx].date)}. Calor prolongado aumenta '
          'atendimentos por desidratação e o risco para idosos e crianças.',
      evidence: [
        'Pico previsto: ${Fmt.withUnit(peak.value, u)} em ${Fmt.weekdayDayMonth(peak.date)}.',
        if (isWave)
          'Sequência de $bestLen dia(s) seguidos ≥ ${Fmt.withUnit(t.heatMaxTemp, u, decimals: 0)} '
              '(limiar: ${t.heatConsecutiveDays} dias).',
        'Média das máximas nos últimos ${hist.length} dias: ${Fmt.withUnit(baseline, u)}.',
        'Previsão diária: ${days.map((d) => '${Fmt.dayMonth(d.date)} ${Fmt.number(d.value, decimals: 0)}°').join(' · ')}.',
      ],
      fitFactor: _horizonFactor(firstIdx),
      limitations: const [
        'Previsão de modelo numérico (Open-Meteo): a precisão cai após o 3º dia.',
        'Resolução espacial de alguns km: ilhas de calor locais podem ser mais quentes que o previsto.',
      ],
      actions: const [
        'Avaliar abertura de pontos de hidratação e acolhimento climatizado.',
        'Avaliar comunicado às UBS e às equipes de saúde da família sobre grupos vulneráveis.',
      ],
      observed: peak.value,
      reference: t.heatMaxTemp,
      thresholdLabel: 'Limiar ${Fmt.withUnit(t.heatMaxTemp, u, decimals: 0)}',
    );
  }

  TerritoryAlert? _rain(AlertContext ctx) {
    final s = ctx.snapshot[IndicatorId.precipitation];
    if (s == null || s.externalForecast.isEmpty) return null;
    final t = ctx.thresholds;
    final next3 = _upcoming(s.externalForecast, ctx.now).take(3).toList();
    if (next3.isEmpty) return null;
    final peak = next3.reduce((a, b) => a.value >= b.value ? a : b);
    final total = next3.fold<double>(0, (a, p) => a + p.value);
    final dayHit = peak.value >= t.rainDailyMm;
    final sumHit = total >= t.rainDailyMm * 2;
    if (!dayHit && !sumHit) return null;

    final severity = (peak.value >= t.rainDailyMm * 2 || total >= t.rainDailyMm * 3)
        ? AlertSeverity.critical
        : AlertSeverity.attention;
    final wetDays = s.history.where((p) => p.value >= 10).length;
    final u = IndicatorId.precipitation.unit;

    return _build(
      ctx,
      kind: AlertKind.heavyRain,
      indicator: IndicatorId.precipitation,
      severity: severity,
      title: 'Risco de alagamento: ${Fmt.withUnit(total, u, decimals: 0)} previstos em 3 dias',
      summary:
          'O volume de chuva previsto supera o limiar configurado. Áreas de várzea e '
          'córregos canalizados da região tendem a alagar com chuvas concentradas.',
      evidence: [
        'Maior volume diário previsto: ${Fmt.withUnit(peak.value, u)} em ${Fmt.weekdayDayMonth(peak.date)} '
            '(limiar ${Fmt.withUnit(t.rainDailyMm, u, decimals: 0)}).',
        'Acumulado dos próximos 3 dias: ${Fmt.withUnit(total, u)}.',
        '$wetDays dia(s) com chuva ≥ 10 mm nos últimos ${s.history.length} dias (solo possivelmente saturado).',
      ],
      fitFactor: _horizonFactor(next3.indexOf(peak)) * 0.95,
      limitations: const [
        'Chuva é a variável meteorológica mais incerta: volume e local exato podem variar bastante.',
        'O app não possui mapa de drenagem; o risco real depende da limpeza de bocas de lobo e do relevo.',
      ],
      actions: const [
        'Avaliar acionamento preventivo da Defesa Civil para as áreas de risco conhecidas.',
        'Verificar limpeza de bocas de lobo e piscinões da região.',
      ],
      observed: peak.value,
      reference: t.rainDailyMm,
      thresholdLabel: 'Limiar ${Fmt.withUnit(t.rainDailyMm, u, decimals: 0)}/dia',
    );
  }

  TerritoryAlert? _air(AlertContext ctx) {
    final s = ctx.snapshot[IndicatorId.pm25];
    if (s == null) return null;
    final t = ctx.thresholds;
    final candidates = [
      if (s.latest != null) s.latest!,
      ..._upcoming(s.externalForecast, ctx.now).take(3),
    ];
    if (candidates.isEmpty) return null;
    final peak = candidates.reduce((a, b) => a.value >= b.value ? a : b);
    if (peak.value < t.pm25) return null;

    final severity =
        peak.value >= t.pm25 * 2 ? AlertSeverity.critical : AlertSeverity.attention;
    final u = IndicatorId.pm25.unit;
    final idx = math.max(0, peak.date.difference(_day(ctx.now)).inDays);

    return _build(
      ctx,
      kind: AlertKind.airQuality,
      indicator: IndicatorId.pm25,
      severity: severity,
      title: 'Qualidade do ar inadequada: PM2,5 ${Fmt.withUnit(peak.value, u)}',
      summary:
          'A concentração de partículas finas supera o limiar. Exposição prolongada '
          'agrava doenças respiratórias e cardiovasculares.',
      evidence: [
        'Pico de PM2,5: ${Fmt.withUnit(peak.value, u)} em ${Fmt.weekdayDayMonth(peak.date)}.',
        'Limiar configurado: ${Fmt.withUnit(t.pm25, u, decimals: 0)} · referência OMS 2021: 15 $u (24 h).',
        'Média dos últimos ${s.history.length} dias: ${Fmt.withUnit(Stats.mean(s.values), u)}.',
      ],
      fitFactor: _horizonFactor(idx) * 0.85,
      limitations: const [
        'Valores de modelo (CAMS, resolução de dezenas de km), não de estação de medição da CETESB.',
        'Fontes locais (queimadas, obras, tráfego intenso) podem não aparecer no modelo.',
      ],
      actions: const [
        'Avaliar comunicado de saúde para grupos sensíveis (asmáticos, idosos, crianças).',
        'Comparar com as estações oficiais da CETESB antes de qualquer medida.',
      ],
      observed: peak.value,
      reference: t.pm25,
      thresholdLabel: 'Limiar ${Fmt.withUnit(t.pm25, u, decimals: 0)}',
    );
  }

  // ---------------------------------------------------------------------
  // Recursos e serviços (séries sintéticas + modelo do app)
  // ---------------------------------------------------------------------

  List<_ConsumptionSpec> _consumptionSpecs(AlertThresholds t) => [
        _ConsumptionSpec(
          IndicatorId.water,
          higherIsWorse: true,
          changePct: t.waterRisePct,
          anomalyText: 'Consumo de água muito acima do esperado — possível vazamento na rede',
          actions: const [
            'Solicitar vistoria da concessionária para possível vazamento ou rompimento.',
            'Cruzar com relatos cidadãos de vazamento na região.',
          ],
        ),
        _ConsumptionSpec(
          IndicatorId.energy,
          higherIsWorse: true,
          changePct: t.energyRisePct,
          anomalyText: 'Consumo de energia fora do padrão',
          actions: const [
            'Consultar a distribuidora sobre falhas, sobrecarga ou ligações irregulares.',
            'Avaliar relação com o calor previsto (uso de ventiladores e ar-condicionado).',
          ],
        ),
        _ConsumptionSpec(
          IndicatorId.waste,
          higherIsWorse: false,
          changePct: t.wasteDropPct,
          anomalyText: 'Queda brusca na coleta de resíduos — risco de acúmulo nas ruas',
          actions: const [
            'Verificar com a concessionária o cumprimento do cronograma de coleta.',
            'Avaliar mutirão de limpeza em pontos de descarte irregular.',
          ],
        ),
        _ConsumptionSpec(
          IndicatorId.healthDemand,
          higherIsWorse: true,
          changePct: t.healthRisePct,
          anomalyText: 'Demanda nas UBS muito acima do normal',
          actions: const [
            'Avaliar remanejamento temporário de equipes entre UBS.',
            'Investigar causa (surto sazonal, calor, fechamento de unidade vizinha).',
          ],
        ),
      ];

  TerritoryAlert? _anomaly(AlertContext ctx, _ConsumptionSpec spec) {
    final s = ctx.snapshot[spec.indicator];
    if (s == null || s.history.length < 21) return null;
    final h = s.history;
    const recentDays = 3;
    final baseline = h.sublist(math.max(0, h.length - 31), h.length - recentDays);
    final recent = h.sublist(h.length - recentDays);

    // Remove o efeito do dia da semana antes de comparar (ex.: UBS fecham
    // no domingo) para não confundir sazonalidade com anomalia.
    final byWd = <int, List<double>>{};
    for (final p in baseline) {
      byWd.putIfAbsent(p.date.weekday, () => []).add(p.value);
    }
    final overall = Stats.mean(baseline.map((p) => p.value).toList());
    double expectedFor(DataPoint p) {
      final list = byWd[p.date.weekday];
      return (list == null || list.isEmpty) ? overall : Stats.mean(list);
    }

    final baseResid = baseline.map((p) => p.value - expectedFor(p)).toList();
    final sd = Stats.stdDev(baseResid);
    if (sd == 0) return null;
    final recentResid = recent.map((p) => p.value - expectedFor(p)).toList();
    final z = Stats.mean(recentResid) / sd;
    final signedZ = spec.higherIsWorse ? z : -z;
    final thr = ctx.thresholds.anomalyZScore;
    if (signedZ < thr) return null;

    final expected = recent.map(expectedFor).toList();
    final observedMean = Stats.mean(recent.map((p) => p.value).toList());
    final expectedMean = Stats.mean(expected);
    final deltaPct = (observedMean - expectedMean) / expectedMean;
    final excess = spec.indicator == IndicatorId.water
        ? recentResid.fold<double>(0, (a, r) => a + math.max(0, r))
        : 0.0;
    final ind = spec.indicator;
    final reports = ctx.citizenReports[ind] ?? 0;
    final fc = forecaster.forecast(h);

    return _build(
      ctx,
      kind: AlertKind.anomaly,
      indicator: ind,
      severity: signedZ >= thr + 1.5 ? AlertSeverity.critical : AlertSeverity.attention,
      title: spec.anomalyText,
      summary:
          'Nos últimos $recentDays dias o indicador "${ind.label}" ficou '
          '${Fmt.percent(deltaPct.abs())} ${deltaPct > 0 ? 'acima' : 'abaixo'} do esperado '
          'para esses dias da semana, um desvio estatisticamente incomum.',
      evidence: [
        'Média observada (${recentDays}d): ${Fmt.withUnit(observedMean, ind.unit, decimals: ind.decimals)} '
            '· esperado: ${Fmt.withUnit(expectedMean, ind.unit, decimals: ind.decimals)}.',
        'Desvio de ${Fmt.number(z.abs(), decimals: 1)} desvios-padrão (z-score) em relação aos '
            '${baseline.length} dias anteriores, já descontado o padrão semanal '
            '(limiar: ${Fmt.number(thr, decimals: 1)}).',
        if (excess > 0)
          'Volume excedente estimado: ${Fmt.integer(excess * 1000)} m³ em $recentDays dias.',
        if (fc != null)
          'Tendência do modelo: ${Fmt.number(fc.trendPerDay, decimals: ind.decimals == 0 ? 1 : 2)} ${ind.unit} por dia'
              '${fc.trendSignificant ? '' : ' (não significativa)'}.',
        if (reports > 0)
          '$reports relato(s) cidadão(s) relacionado(s) nesta região nos últimos 7 dias.',
      ],
      fitFactor: Stats.clamp01(0.5 + (signedZ - thr) / 4),
      limitations: [
        'Anomalia estatística indica algo incomum, não a causa: pode ser vazamento, evento, feriado ou falha de medição.',
        'Linha de base de ${baseline.length} dias: mudanças estruturais recentes (novos conjuntos habitacionais) podem gerar falsos alarmes.',
        if (reports == 0)
          'Nenhum relato cidadão corrobora o alerta — a ausência de relatos não descarta o problema.',
      ],
      actions: spec.actions,
      observed: observedMean,
      reference: expectedMean,
      thresholdLabel: 'z ≥ ${Fmt.number(thr, decimals: 1)}',
      excess: excess,
    );
  }

  TerritoryAlert? _forecastChange(AlertContext ctx, _ConsumptionSpec spec) {
    final s = ctx.snapshot[spec.indicator];
    if (s == null || s.history.length < 35) return null;
    final fc = forecaster.forecast(s.history);
    if (fc == null) return null;
    final h = s.history;
    final baseline = h.sublist(h.length - 35, h.length - 7).map((p) => p.value).toList();
    final baseMean = Stats.mean(baseline);
    final change = (fc.meanForecast - baseMean) / baseMean;
    final worse = spec.higherIsWorse ? change : -change;
    final thr = spec.changePct / 100;
    if (worse < thr) return null;

    final ind = spec.indicator;
    final wapeFactor = fc.backtestWape.isNaN ? 0.4 : Stats.clamp01(1 - fc.backtestWape / 0.25);
    final up = change > 0;

    return _build(
      ctx,
      kind: up ? AlertKind.forecastRise : AlertKind.forecastDrop,
      indicator: ind,
      severity: worse >= thr * 2 ? AlertSeverity.critical : AlertSeverity.attention,
      title: up
          ? '${ind.label}: alta prevista de ${Fmt.percent(change)} nos próximos 7 dias'
          : '${ind.label}: queda prevista de ${Fmt.percent(change.abs())} nos próximos 7 dias',
      summary:
          'O modelo projeta que a média dos próximos 7 dias ficará '
          '${Fmt.percent(change.abs())} ${up ? 'acima' : 'abaixo'} da linha de base das 4 semanas anteriores.',
      evidence: [
        'Média prevista (7 dias): ${Fmt.withUnit(fc.meanForecast, ind.unit, decimals: ind.decimals)} '
            '· linha de base: ${Fmt.withUnit(baseMean, ind.unit, decimals: ind.decimals)}.',
        'Tendência: ${Fmt.number(fc.trendPerDay, decimals: 2)} ${ind.unit}/dia'
            '${fc.trendSignificant ? ', estatisticamente significativa' : ' (não significativa: previsão usa o nível recente)'}.',
        'Backtest (últimos 7 dias previstos às cegas): erro de ${Fmt.percent(fc.backtestWape, decimals: 1)} (WAPE).',
        'Limiar configurado: ${Fmt.percent(thr)} de variação.',
      ],
      fitFactor: wapeFactor,
      limitations: const [
        'Modelo linear: não antecipa eventos súbitos (rompimento de adutora, greve, feriado prolongado).',
        'Intervalo de 95% pode ser largo; observe a faixa sombreada no gráfico.',
      ],
      actions: spec.actions,
      observed: fc.meanForecast,
      reference: baseMean,
      thresholdLabel: '${up ? '+' : '−'}${Fmt.percent(thr)}',
    );
  }

  // ---------------------------------------------------------------------
  // Montagem, confiança e utilidades
  // ---------------------------------------------------------------------

  TerritoryAlert _build(
    AlertContext ctx, {
    required AlertKind kind,
    required IndicatorId indicator,
    required AlertSeverity severity,
    required String title,
    required String summary,
    required List<String> evidence,
    required double fitFactor,
    required List<String> limitations,
    required List<String> actions,
    required double observed,
    required double reference,
    required String thresholdLabel,
    double excess = 0,
  }) {
    final s = ctx.snapshot[indicator];
    final confidence = computeConfidence(
      fitFactor: fitFactor,
      historyDays: s?.history.length ?? 0,
      origin: indicator.origin,
      fromCache: ctx.snapshot.fromCache,
      dataAge: ctx.now.difference(ctx.snapshot.fetchedAt),
      fitLabel: switch (kind) {
        AlertKind.anomaly => 'Força do desvio',
        AlertKind.forecastRise || AlertKind.forecastDrop => 'Precisão no backtest',
        _ => 'Horizonte da previsão',
      },
    );
    final allLimitations = [
      ...limitations,
      if (indicator.origin == DataOrigin.synthetic)
        'Série sintética (simulação calibrada): demonstra o método, não representa medições oficiais.',
      if (ctx.snapshot.fromCache)
        'Dados do cache local de ${Fmt.dateTime(ctx.snapshot.fetchedAt)} — podem estar desatualizados.',
      if (!confidence.isReliable)
        'Confiança baixa: use apenas como sinal para investigação, não como base para decisão.',
    ];
    return TerritoryAlert(
      id: '${kind.name}_${ctx.region.id}_${indicator.name}_${Fmt.ymd(ctx.now)}',
      kind: kind,
      severity: severity,
      regionId: ctx.region.id,
      indicator: indicator,
      title: title,
      summary: summary,
      evidence: evidence,
      confidence: confidence,
      limitations: allLimitations,
      suggestedActions: actions,
      generatedAt: ctx.now,
      observedValue: observed,
      referenceValue: reference,
      thresholdLabel: thresholdLabel,
      excessVolume: excess,
    );
  }

  /// Nota de confiança 0–1 = média ponderada de quatro fatores explícitos.
  static AlertConfidence computeConfidence({
    required double fitFactor,
    required int historyDays,
    required DataOrigin origin,
    required bool fromCache,
    required Duration dataAge,
    String fitLabel = 'Ajuste do modelo',
  }) {
    final dataScore = Stats.clamp01(historyDays / 28);
    final double freshScore;
    if (!fromCache) {
      freshScore = 1.0;
    } else if (dataAge.inHours < 6) {
      freshScore = 0.85;
    } else if (dataAge.inHours < 24) {
      freshScore = 0.65;
    } else {
      freshScore = 0.35;
    }
    final originScore = origin == DataOrigin.real ? 0.95 : 0.75;
    final fit = Stats.clamp01(fitFactor);

    final factors = [
      ConfidenceFactor(fitLabel, fit, 'Peso 40% · quão forte e validado é o sinal.'),
      ConfidenceFactor('Volume de histórico', dataScore,
          'Peso 20% · $historyDays dia(s) disponíveis (ideal ≥ 28).'),
      ConfidenceFactor('Atualidade dos dados', freshScore,
          fromCache ? 'Peso 25% · dados do cache local.' : 'Peso 25% · dados recebidos agora.'),
      ConfidenceFactor('Origem do dado', originScore,
          origin == DataOrigin.real ? 'Peso 15% · fonte pública real.' : 'Peso 15% · série simulada.'),
    ];
    final score = 0.40 * fit + 0.20 * dataScore + 0.25 * freshScore + 0.15 * originScore;
    return AlertConfidence(score: score, factors: factors);
  }

  /// 1º dia ≈ 0,95; cai 0,08 por dia de antecedência.
  static double _horizonFactor(int daysAhead) =>
      Stats.clamp01(0.95 - 0.08 * math.max(0, daysAhead));

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static List<DataPoint> _upcoming(List<DataPoint> forecast, DateTime now) {
    final today = _day(now);
    return forecast.where((p) => !_day(p.date).isBefore(today)).toList();
  }
}

class _ConsumptionSpec {
  const _ConsumptionSpec(
    this.indicator, {
    required this.higherIsWorse,
    required this.changePct,
    required this.anomalyText,
    required this.actions,
  });

  final IndicatorId indicator;
  final bool higherIsWorse;
  final double changePct;
  final String anomalyText;
  final List<String> actions;
}
