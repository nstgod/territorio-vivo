import 'package:flutter_test/flutter_test.dart';
import 'package:territorio_vivo/data/models/alert.dart';
import 'package:territorio_vivo/data/models/alert_thresholds.dart';
import 'package:territorio_vivo/data/models/indicator.dart';
import 'package:territorio_vivo/data/models/region.dart';
import 'package:territorio_vivo/data/models/time_series.dart';
import 'package:territorio_vivo/data/sources/synthetic_territory_api.dart';
import 'package:territorio_vivo/domain/alert_engine.dart';

void main() {
  final now = DateTime(2026, 11, 5, 10);
  final today = DateTime(2026, 11, 5);
  const engine = AlertEngine();

  RegionSnapshot snapshot(Map<IndicatorId, TimeSeries> series, {bool fromCache = false, DateTime? fetchedAt}) =>
      RegionSnapshot(
        regionId: 'penha',
        series: series,
        fetchedAt: fetchedAt ?? now,
        fromCache: fromCache,
      );

  List<DataPoint> flat(double value, {int days = 30, double jitter = 0.4}) => [
        for (var i = days; i >= 1; i--)
          DataPoint(today.subtract(Duration(days: i)), value + (i % 3 - 1) * jitter),
      ];

  List<DataPoint> forecastOf(List<double> values) => [
        for (var i = 0; i < values.length; i++) DataPoint(today.add(Duration(days: i)), values[i]),
      ];

  List<TerritoryAlert> run(RegionSnapshot s, [AlertThresholds t = AlertThresholds.defaults]) =>
      engine.evaluate(AlertContext(region: Territory.byId('penha'), snapshot: s, thresholds: t, now: now));

  group('Onda de calor', () {
    test('dispara com 3 dias seguidos acima do limiar e traz evidência', () {
      final s = snapshot({
        IndicatorId.tempMax: TimeSeries(
          indicator: IndicatorId.tempMax,
          history: flat(27),
          externalForecast: forecastOf([29, 33, 34, 33.5, 30, 28, 27]),
        ),
      });
      final alerts = run(s);
      final heat = alerts.singleWhere((a) => a.kind == AlertKind.heatWave);
      expect(heat.severity, AlertSeverity.attention);
      expect(heat.evidence.any((e) => e.contains('Sequência de 3')), isTrue);
      expect(heat.limitations, isNotEmpty);
      expect(heat.confidence.factors, hasLength(4));
    });

    test('não dispara quando a previsão fica abaixo do limiar', () {
      final s = snapshot({
        IndicatorId.tempMax: TimeSeries(
          indicator: IndicatorId.tempMax,
          history: flat(25),
          externalForecast: forecastOf([26, 27, 28, 29, 30, 29, 28]),
        ),
      });
      expect(run(s).where((a) => a.kind == AlertKind.heatWave), isEmpty);
    });

    test('limiar configurado pelo gestor altera o resultado', () {
      final s = snapshot({
        IndicatorId.tempMax: TimeSeries(
          indicator: IndicatorId.tempMax,
          history: flat(25),
          externalForecast: forecastOf([29, 30, 30, 30, 26, 26, 26]),
        ),
      });
      expect(run(s).where((a) => a.kind == AlertKind.heatWave), isEmpty);
      final lower = AlertThresholds.defaults.copyWith(heatMaxTemp: 28.5);
      expect(run(s, lower).where((a) => a.kind == AlertKind.heatWave), hasLength(1));
    });
  });

  group('Chuva forte', () {
    test('volume diário 2x o limiar é crítico', () {
      final s = snapshot({
        IndicatorId.precipitation: TimeSeries(
          indicator: IndicatorId.precipitation,
          history: flat(2, jitter: 1),
          externalForecast: forecastOf([5, 65, 10, 0, 0, 0, 0]),
        ),
      });
      final rain = run(s).singleWhere((a) => a.kind == AlertKind.heavyRain);
      expect(rain.severity, AlertSeverity.critical);
    });
  });

  group('Anomalia de consumo', () {
    test('detecta o vazamento simulado de Itaquera', () {
      final region = Territory.byId('itaquera');
      final series = SyntheticTerritoryApi.generate(region, now: now);
      final alerts = engine.evaluate(AlertContext(
        region: region,
        snapshot: RegionSnapshot(regionId: region.id, series: series, fetchedAt: now),
        thresholds: AlertThresholds.defaults,
        now: now,
      ));
      final water = alerts.where((a) => a.indicator == IndicatorId.water).toList();
      expect(water, hasLength(1));
      expect(water.single.kind, AlertKind.anomaly);
      expect(water.single.excessVolume, greaterThan(0));
    });

    test('Penha (sem eventos simulados) não gera alertas de consumo', () {
      final region = Territory.byId('penha');
      final series = SyntheticTerritoryApi.generate(region, now: now);
      final alerts = engine.evaluate(AlertContext(
        region: region,
        snapshot: RegionSnapshot(regionId: region.id, series: series, fetchedAt: now),
        thresholds: AlertThresholds.defaults,
        now: now,
      ));
      expect(alerts, isEmpty);
    });

    test('alta gradual da demanda em São Mateus vira alerta de previsão', () {
      final region = Territory.byId('sao-mateus');
      final series = SyntheticTerritoryApi.generate(region, now: now);
      final alerts = engine.evaluate(AlertContext(
        region: region,
        snapshot: RegionSnapshot(regionId: region.id, series: series, fetchedAt: now),
        thresholds: AlertThresholds.defaults,
        now: now,
      ));
      expect(alerts.where((a) => a.indicator == IndicatorId.healthDemand), isNotEmpty);
    });
  });

  group('Robustez (21 dias diferentes)', () {
    // Cada cenário simulado deve ser detectado e regiões sem evento não
    // devem gerar falso alarme, qualquer que seja o dia da semana.
    const expected = {
      'itaquera': IndicatorId.water,
      'sao-mateus': IndicatorId.healthDemand,
      'guaianases': IndicatorId.waste,
      'cidade-tiradentes': IndicatorId.energy,
    };
    for (var d = 0; d < 21; d++) {
      final day = DateTime(2026, 10, 20 + d, 9);
      test('dia ${day.day}/${day.month}', () {
        for (final region in Territory.regions) {
          final series = SyntheticTerritoryApi.generate(region, now: day);
          final alerts = engine.evaluate(AlertContext(
            region: region,
            snapshot: RegionSnapshot(regionId: region.id, series: series, fetchedAt: day),
            thresholds: AlertThresholds.defaults,
            now: day,
          ));
          final indicators = alerts.map((a) => a.indicator).toSet();
          final target = expected[region.id];
          expect(indicators, target == null ? isEmpty : {target}, reason: region.id);
        }
      });
    }
  });

  group('Confiança e transparência', () {
    test('dados do cache antigos reduzem a confiança e entram nas limitações', () {
      final series = {
        IndicatorId.tempMax: TimeSeries(
          indicator: IndicatorId.tempMax,
          history: flat(27),
          externalForecast: forecastOf([33, 34, 34, 33, 30, 28, 27]),
        ),
      };
      final live = run(snapshot(series)).single;
      final cached = run(snapshot(series,
              fromCache: true, fetchedAt: now.subtract(const Duration(hours: 30))))
          .single;
      expect(cached.confidence.score, lessThan(live.confidence.score));
      expect(cached.limitations.any((l) => l.contains('cache')), isTrue);
    });

    test('nota de confiança baixa é marcada como não confiável', () {
      final c = AlertEngine.computeConfidence(
        fitFactor: 0.1,
        historyDays: 5,
        origin: DataOrigin.synthetic,
        fromCache: true,
        dataAge: const Duration(days: 3),
      );
      expect(c.level, ConfidenceLevel.low);
      expect(c.isReliable, isFalse);
    });

    test('id do alerta é determinístico (decisão humana sobrevive à recarga)', () {
      final s = snapshot({
        IndicatorId.tempMax: TimeSeries(
          indicator: IndicatorId.tempMax,
          history: flat(27),
          externalForecast: forecastOf([33, 34, 34, 33, 30, 28, 27]),
        ),
      });
      expect(run(s).single.id, run(s).single.id);
    });

    test('todo alerta tem evidência, limitações e sugestões (nunca ação automática)', () {
      for (final region in Territory.regions) {
        final series = SyntheticTerritoryApi.generate(region, now: now);
        final alerts = engine.evaluate(AlertContext(
          region: region,
          snapshot: RegionSnapshot(regionId: region.id, series: series, fetchedAt: now),
          thresholds: AlertThresholds.defaults,
          now: now,
        ));
        for (final a in alerts) {
          expect(a.evidence, isNotEmpty, reason: a.title);
          expect(a.limitations, isNotEmpty, reason: a.title);
          expect(a.suggestedActions, isNotEmpty, reason: a.title);
          expect(a.confidence.score, inInclusiveRange(0, 1));
        }
      }
    });
  });
}
