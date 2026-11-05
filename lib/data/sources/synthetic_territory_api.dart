import 'dart:convert';
import 'dart:math' as math;

import '../models/indicator.dart';
import '../models/region.dart';
import '../models/time_series.dart';
import 'api_exception.dart';

/// "Serviço externo" simulado de consumo e serviços públicos.
///
/// Não há API pública diária de água, energia, coleta e UBS por
/// subprefeitura, então este serviço gera séries **sintéticas,
/// determinísticas e documentadas**: mesma região + mesmo dia = mesmo valor.
/// Responde em JSON, com latência, como uma API real, e pode ser colocado
/// em "modo offline" para demonstrar o cache.
class SyntheticTerritoryApi {
  SyntheticTerritoryApi({this.latency = const Duration(milliseconds: 650)});

  final Duration latency;
  static const int historyDays = 60;

  Future<String> fetchRegionJson(Region region, {bool offline = false, DateTime? now}) async {
    await Future<void>.delayed(latency);
    if (offline) {
      throw const ApiException('Serviço de dados municipais indisponível (offline).', offline: true);
    }
    final series = generate(region, now: now ?? DateTime.now());
    return jsonEncode({
      'regionId': region.id,
      'generatedAt': (now ?? DateTime.now()).toIso8601String(),
      'series': series.values.map((s) => s.toJson()).toList(),
    });
  }

  static Map<IndicatorId, TimeSeries> parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final list = (json['series'] as List)
        .map((e) => TimeSeries.fromJson(e as Map<String, dynamic>));
    return {for (final s in list) s.indicator: s};
  }

  /// Gera as quatro séries sintéticas da região, terminando em [now].
  static Map<IndicatorId, TimeSeries> generate(Region region, {required DateTime now}) {
    final today = DateTime(now.year, now.month, now.day);
    return {
      for (final spec in _specs)
        spec.indicator: TimeSeries(
          indicator: spec.indicator,
          history: [
            for (var back = historyDays - 1; back >= 0; back--)
              _point(region, spec, DateTime(today.year, today.month, today.day - back), back),
          ],
        ),
    };
  }

  static DataPoint _point(Region region, _Spec spec, DateTime date, int daysAgo) {
    final epochDay = date.difference(DateTime(2020)).inDays;
    final rnd = math.Random(region.seed * 1000003 + spec.indicator.index * 7919 + epochDay);
    // Box–Muller: ruído gaussiano determinístico.
    final u1 = math.max(1e-9, rnd.nextDouble());
    final u2 = rnd.nextDouble();
    final gauss = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);

    final base = region.population * spec.perCapita;
    final weekly = spec.weekday[date.weekday - 1];
    final slowCycle = 1 + 0.012 * math.sin(2 * math.pi * epochDay / 90 + region.seed);
    final scenario = _scenario(region.id, spec.indicator, daysAgo);
    final value = base * weekly * slowCycle * scenario * (1 + spec.noise * gauss);
    return DataPoint(date, math.max(0, value));
  }

  /// Eventos simulados para demonstrar cada tipo de alerta.
  static double _scenario(String regionId, IndicatorId id, int daysAgo) {
    switch ((regionId, id)) {
      // Possível vazamento: consumo de água sobe 13% nos últimos 3 dias.
      case ('itaquera', IndicatorId.water):
        return daysAgo < 3 ? 1.13 : 1.0;
      // Demanda crescente nas UBS nas últimas 3 semanas.
      case ('sao-mateus', IndicatorId.healthDemand):
        return daysAgo < 21 ? 1 + 0.009 * (21 - daysAgo) : 1.0;
      // Coleta de resíduos caindo gradualmente (falha contratual).
      case ('guaianases', IndicatorId.waste):
        return daysAgo < 14 ? 1 - 0.014 * (14 - daysAgo) : 1.0;
      // Pico de energia nos últimos 3 dias.
      case ('cidade-tiradentes', IndicatorId.energy):
        return daysAgo < 3 ? 1.09 : 1.0;
      default:
        return 1.0;
    }
  }

  static const _specs = [
    // mil m³/dia por habitante: 150 L = 0,00015 mil m³.
    _Spec(IndicatorId.water, 0.00015, 0.022, [0.98, 0.98, 0.99, 0.99, 1.0, 1.04, 1.03]),
    // MWh/dia por habitante: ~6 kWh.
    _Spec(IndicatorId.energy, 0.006, 0.022, [1.0, 1.0, 1.0, 1.0, 0.99, 1.02, 1.04]),
    // t/dia por habitante: ~1 kg; coleta menor no domingo e recuperação na segunda.
    _Spec(IndicatorId.waste, 0.001, 0.035, [1.30, 1.02, 1.0, 1.02, 1.0, 0.98, 0.55]),
    // atendimentos/dia por habitante; UBS quase fechadas no domingo.
    _Spec(IndicatorId.healthDemand, 0.0042, 0.035, [1.18, 1.08, 1.04, 1.02, 0.98, 0.45, 0.12]),
  ];
}

class _Spec {
  const _Spec(this.indicator, this.perCapita, this.noise, this.weekday);

  final IndicatorId indicator;
  final double perCapita;

  /// Desvio-padrão relativo do ruído diário.
  final double noise;

  /// Fator multiplicativo de segunda (0) a domingo (6).
  final List<double> weekday;
}
