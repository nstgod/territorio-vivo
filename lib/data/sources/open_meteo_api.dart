import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/indicator.dart';
import '../models/region.dart';
import '../models/time_series.dart';
import 'api_exception.dart';

/// Cliente das APIs públicas e gratuitas da Open-Meteo (sem chave):
/// previsão/histórico meteorológico e qualidade do ar (modelo CAMS).
class OpenMeteoApi {
  OpenMeteoApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  Future<Map<IndicatorId, TimeSeries>> fetchClimate(Region region, {DateTime? now}) async {
    final today = _day(now ?? DateTime.now());
    final weatherUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${region.latitude}',
      'longitude': '${region.longitude}',
      'daily': 'temperature_2m_max,precipitation_sum',
      'past_days': '30',
      'forecast_days': '7',
      'timezone': 'America/Sao_Paulo',
    });
    final airUri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': '${region.latitude}',
      'longitude': '${region.longitude}',
      'hourly': 'pm2_5',
      'past_days': '30',
      'forecast_days': '4',
      'timezone': 'America/Sao_Paulo',
    });

    final results = await Future.wait([_get(weatherUri), _get(airUri)]);
    final weather = results[0];
    final air = results[1];

    final daily = weather['daily'] as Map<String, dynamic>?;
    if (daily == null) throw const ApiException('Resposta meteorológica sem dados diários.');
    final dates = (daily['time'] as List).cast<String>().map(DateTime.parse).toList();

    TimeSeries split(IndicatorId id, List<dynamic> raw) {
      final history = <DataPoint>[];
      final forecast = <DataPoint>[];
      for (var i = 0; i < dates.length && i < raw.length; i++) {
        final v = raw[i];
        if (v == null) continue;
        final p = DataPoint(dates[i], (v as num).toDouble());
        (dates[i].isBefore(today) ? history : forecast).add(p);
      }
      return TimeSeries(indicator: id, history: history, externalForecast: forecast);
    }

    final out = <IndicatorId, TimeSeries>{
      IndicatorId.tempMax: split(IndicatorId.tempMax, daily['temperature_2m_max'] as List),
      IndicatorId.precipitation: split(IndicatorId.precipitation, daily['precipitation_sum'] as List),
    };

    final hourly = air['hourly'] as Map<String, dynamic>?;
    if (hourly != null) {
      out[IndicatorId.pm25] = _dailyMean(
        IndicatorId.pm25,
        (hourly['time'] as List).cast<String>(),
        hourly['pm2_5'] as List,
        today,
      );
    }
    return out;
  }

  /// Agrega a série horária em média diária (exige ≥ 12 h válidas no dia).
  static TimeSeries _dailyMean(
    IndicatorId id,
    List<String> times,
    List<dynamic> values,
    DateTime today,
  ) {
    final buckets = <DateTime, List<double>>{};
    for (var i = 0; i < times.length && i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final d = _day(DateTime.parse(times[i]));
      buckets.putIfAbsent(d, () => []).add((v as num).toDouble());
    }
    final history = <DataPoint>[];
    final forecast = <DataPoint>[];
    final days = buckets.keys.toList()..sort();
    for (final d in days) {
      final list = buckets[d]!;
      if (list.length < 12) continue;
      final mean = list.reduce((a, b) => a + b) / list.length;
      (d.isBefore(today) ? history : forecast).add(DataPoint(d, mean));
    }
    return TimeSeries(indicator: id, history: history, externalForecast: forecast);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode != 200) {
        throw ApiException('Open-Meteo respondeu HTTP ${res.statusCode}.');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw const ApiException('Tempo esgotado ao consultar a Open-Meteo.', offline: true);
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('Resposta inválida da Open-Meteo.');
    } catch (_) {
      // SocketException (mobile) / ClientException (web): sem conexão.
      throw const ApiException('Sem conexão com a Open-Meteo.', offline: true);
    }
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
