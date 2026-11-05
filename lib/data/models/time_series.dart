import 'indicator.dart';

/// Um ponto de uma série diária.
class DataPoint {
  const DataPoint(this.date, this.value);

  final DateTime date;
  final double value;

  Map<String, dynamic> toJson() => {'d': date.toIso8601String(), 'v': value};

  factory DataPoint.fromJson(Map<String, dynamic> json) =>
      DataPoint(DateTime.parse(json['d'] as String), (json['v'] as num).toDouble());
}

/// Série de um indicador numa região: histórico observado e, quando a
/// própria fonte fornece, previsão externa (ex.: previsão meteorológica).
class TimeSeries {
  const TimeSeries({
    required this.indicator,
    required this.history,
    this.externalForecast = const [],
  });

  final IndicatorId indicator;
  final List<DataPoint> history;

  /// Previsão vinda da fonte (Open-Meteo). Para séries sintéticas fica vazia
  /// e a previsão é calculada no app pelo [Forecaster].
  final List<DataPoint> externalForecast;

  bool get isEmpty => history.isEmpty;
  DataPoint? get latest => history.isEmpty ? null : history.last;
  List<double> get values => history.map((p) => p.value).toList();

  Map<String, dynamic> toJson() => {
        'indicator': indicator.name,
        'history': history.map((p) => p.toJson()).toList(),
        'forecast': externalForecast.map((p) => p.toJson()).toList(),
      };

  factory TimeSeries.fromJson(Map<String, dynamic> json) => TimeSeries(
        indicator: IndicatorId.tryParse(json['indicator'] as String?) ?? IndicatorId.water,
        history: (json['history'] as List)
            .map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        externalForecast: ((json['forecast'] as List?) ?? const [])
            .map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Todos os indicadores de uma região num instante.
class RegionSnapshot {
  const RegionSnapshot({
    required this.regionId,
    required this.series,
    required this.fetchedAt,
    this.fromCache = false,
    this.missing = const {},
  });

  final String regionId;
  final Map<IndicatorId, TimeSeries> series;
  final DateTime fetchedAt;

  /// Verdadeiro quando os dados vieram do cache local (sem conexão).
  final bool fromCache;

  /// Indicadores cuja fonte falhou e não tinham cache.
  final Set<IndicatorId> missing;

  TimeSeries? operator [](IndicatorId id) => series[id];

  RegionSnapshot copyWith({bool? fromCache}) => RegionSnapshot(
        regionId: regionId,
        series: series,
        fetchedAt: fetchedAt,
        fromCache: fromCache ?? this.fromCache,
        missing: missing,
      );

  Map<String, dynamic> toJson() => {
        'regionId': regionId,
        'fetchedAt': fetchedAt.toIso8601String(),
        'series': series.values.map((s) => s.toJson()).toList(),
      };

  factory RegionSnapshot.fromJson(Map<String, dynamic> json) {
    final list = (json['series'] as List)
        .map((e) => TimeSeries.fromJson(e as Map<String, dynamic>));
    return RegionSnapshot(
      regionId: json['regionId'] as String,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      series: {for (final s in list) s.indicator: s},
    );
  }
}
