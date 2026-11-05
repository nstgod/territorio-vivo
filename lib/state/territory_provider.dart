import 'package:flutter/foundation.dart';

import '../data/models/indicator.dart';
import '../data/models/region.dart';
import '../data/models/time_series.dart';
import '../data/repositories/territory_repository.dart';
import '../domain/forecaster.dart';
import 'settings_provider.dart';
import 'view_status.dart';

/// Estado global dos dados do território: carga, região selecionada,
/// séries e previsões. Compartilhado por visão geral, dashboards, detalhe
/// do indicador e mapa.
class TerritoryProvider extends ChangeNotifier {
  TerritoryProvider(this._repository, this._settings, {Forecaster? forecaster})
      : _forecaster = forecaster ?? const Forecaster();

  final TerritoryRepository _repository;
  final SettingsProvider _settings;
  final Forecaster _forecaster;

  ViewStatus _status = ViewStatus.initial;
  TerritoryLoad? _load;
  String? _error;
  String _selectedRegionId = Territory.regions.first.id;
  int _version = 0;
  final _forecastCache = <String, ForecastResult?>{};

  ViewStatus get status => _status;
  String? get error => _error;
  bool get isLoading => _status == ViewStatus.loading;
  bool get hasData => _load?.hasAnyData ?? false;

  /// Incrementa a cada carga bem-sucedida (usado para recalcular alertas).
  int get version => _version;
  bool get fromCache => _load?.anyFromCache ?? false;
  List<String> get warnings => _load?.errors ?? const [];

  String get selectedRegionId => _selectedRegionId;
  Region get selectedRegion => Territory.byId(_selectedRegionId);

  RegionSnapshot? snapshot(String regionId) => _load?.snapshots[regionId];
  RegionSnapshot? get selectedSnapshot => snapshot(_selectedRegionId);
  Map<String, RegionSnapshot> get snapshots => _load?.snapshots ?? const {};

  DateTime? get fetchedAt {
    final all = snapshots.values.map((s) => s.fetchedAt).toList();
    if (all.isEmpty) return null;
    all.sort();
    return all.first; // o mais antigo: conservador
  }

  void selectRegion(String id) {
    if (id == _selectedRegionId) return;
    _selectedRegionId = id;
    notifyListeners();
  }

  Future<void> load() async {
    if (_status == ViewStatus.loading) return;
    _status = ViewStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.loadAll(offline: _settings.simulateOffline);
      _forecastCache.clear();
      if (result.hasAnyData) {
        _load = result;
        _status = ViewStatus.success;
        _version++;
      } else {
        _status = ViewStatus.error;
        _error = _settings.simulateOffline
            ? 'Modo offline ativado e ainda não há dados salvos neste aparelho. '
                'Desative o modo offline em Ajustes e atualize.'
            : 'Não foi possível obter dados e não há cópia salva. '
                'Verifique sua conexão e tente novamente.';
      }
    } catch (e) {
      _status = ViewStatus.error;
      _error = 'Erro inesperado ao carregar os dados.';
      debugPrint('TerritoryProvider.load: $e');
    }
    notifyListeners();
  }

  TimeSeries? series(String regionId, IndicatorId id) => snapshot(regionId)?[id];

  /// Previsão do app para séries sem previsão externa (memoizada).
  ForecastResult? forecast(String regionId, IndicatorId id) {
    final key = '$regionId/${id.name}/$_version';
    return _forecastCache.putIfAbsent(key, () {
      final s = series(regionId, id);
      if (s == null || s.externalForecast.isNotEmpty) return null;
      return _forecaster.forecast(s.history);
    });
  }
}
