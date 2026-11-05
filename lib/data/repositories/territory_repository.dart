import '../models/indicator.dart';
import '../models/region.dart';
import '../models/time_series.dart';
import '../sources/local_store.dart';
import '../sources/open_meteo_api.dart';
import '../sources/synthetic_territory_api.dart';

/// Resultado da carga de todas as regiões.
class TerritoryLoad {
  const TerritoryLoad({required this.snapshots, required this.errors});

  final Map<String, RegionSnapshot> snapshots;

  /// Mensagens das fontes que falharam (exibidas como aviso, não como erro,
  /// quando o cache cobriu a falha).
  final List<String> errors;

  bool get hasAnyData => snapshots.values.any((s) => s.series.isNotEmpty);
  bool get anyFromCache => snapshots.values.any((s) => s.fromCache);
}

/// Orquestra as fontes de dados com estratégia "rede primeiro, cache como
/// fallback": cada resposta boa é gravada localmente; se a rede falha, o app
/// continua útil com a última versão salva (e avisa a idade do dado).
class TerritoryRepository {
  TerritoryRepository({
    required this.store,
    required this.climateApi,
    required this.syntheticApi,
  });

  final LocalStore store;
  final OpenMeteoApi climateApi;
  final SyntheticTerritoryApi syntheticApi;

  static const _climateIds = {IndicatorId.tempMax, IndicatorId.precipitation, IndicatorId.pm25};

  Future<TerritoryLoad> loadAll({bool offline = false}) async {
    final errors = <String>[];
    final entries = await Future.wait(
      Territory.regions.map((r) async => MapEntry(r.id, await _loadRegion(r, offline, errors))),
    );
    return TerritoryLoad(snapshots: Map.fromEntries(entries), errors: errors.toSet().toList());
  }

  Future<RegionSnapshot> _loadRegion(Region region, bool offline, List<String> errors) async {
    final now = DateTime.now();
    final series = <IndicatorId, TimeSeries>{};
    var usedCache = false;
    final cached = _readCache(region.id);

    // 1) Clima e ar: API pública real.
    try {
      if (offline) throw Exception('offline');
      series.addAll(await climateApi.fetchClimate(region, now: now));
    } catch (e) {
      errors.add(offline ? 'Modo offline: usando dados salvos.' : _message(e));
      usedCache |= _fillFromCache(series, cached, _climateIds);
    }

    // 2) Recursos e serviços: serviço simulado.
    try {
      final body = await syntheticApi.fetchRegionJson(region, offline: offline, now: now);
      series.addAll(SyntheticTerritoryApi.parse(body));
    } catch (e) {
      errors.add(_message(e));
      usedCache |= _fillFromCache(
        series,
        cached,
        IndicatorId.values.toSet().difference(_climateIds),
      );
    }

    final missing = IndicatorId.values.toSet().difference(series.keys.toSet());
    final snapshot = RegionSnapshot(
      regionId: region.id,
      series: series,
      // Se algo veio do cache, a "idade" exibida é a do cache (conservador).
      fetchedAt: usedCache ? (cached?.fetchedAt ?? now) : now,
      fromCache: usedCache,
      missing: missing,
    );

    // Sem uso de cache, toda parte que falhou também não existia no cache:
    // gravar só o que veio fresco não apaga nada útil.
    if (!usedCache && series.isNotEmpty) {
      await store.writeJson('${LocalStore.kCachePrefix}${region.id}', snapshot.toJson());
    }
    return snapshot;
  }

  RegionSnapshot? _readCache(String regionId) {
    final json = store.readMap('${LocalStore.kCachePrefix}$regionId');
    if (json == null) return null;
    try {
      return RegionSnapshot.fromJson(json);
    } catch (_) {
      return null; // cache corrompido ou de versão antiga: ignora
    }
  }

  bool _fillFromCache(
    Map<IndicatorId, TimeSeries> target,
    RegionSnapshot? cached,
    Set<IndicatorId> ids,
  ) {
    if (cached == null) return false;
    var filled = false;
    for (final id in ids) {
      final s = cached.series[id];
      if (s != null) {
        target[id] = s;
        filled = true;
      }
    }
    return filled;
  }

  static String _message(Object e) {
    final text = e.toString();
    return text.startsWith('ApiException: ') ? text.substring(14) : 'Falha ao obter dados.';
  }
}
