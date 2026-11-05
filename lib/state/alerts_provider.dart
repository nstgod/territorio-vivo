import 'package:flutter/foundation.dart';

import '../data/models/alert.dart';
import '../data/models/alert_thresholds.dart';
import '../data/models/region.dart';
import '../data/sources/local_store.dart';
import '../domain/alert_engine.dart';
import '../domain/social_impact.dart';
import '../services/notification_service.dart';
import 'occurrences_provider.dart';
import 'settings_provider.dart';
import 'territory_provider.dart';

/// Estado global dos alertas: recalculados sempre que chegam dados novos,
/// mudam os limiares ou entram relatos cidadãos. Guarda (e persiste) a
/// decisão humana de cada alerta.
class AlertsProvider extends ChangeNotifier {
  AlertsProvider({
    required LocalStore store,
    required TerritoryProvider territory,
    required SettingsProvider settings,
    required OccurrencesProvider occurrences,
    required NotificationService notifications,
    AlertEngine engine = const AlertEngine(),
  })  : _store = store,
        _territory = territory,
        _settings = settings,
        _occurrences = occurrences,
        _notifications = notifications,
        _engine = engine {
    _decisions = {
      for (final e in _store.readList(LocalStore.kDecisions))
        (e as Map<String, dynamic>)['alertId'] as String: AlertDecision.fromJson(e),
    };
    _notified = _store.readList(LocalStore.kNotified).cast<String>().toSet();
    _territory.addListener(_onDependencyChanged);
    _settings.addListener(_onDependencyChanged);
    _occurrences.addListener(_onDependencyChanged);
  }

  final LocalStore _store;
  final TerritoryProvider _territory;
  final SettingsProvider _settings;
  final OccurrencesProvider _occurrences;
  final NotificationService _notifications;
  final AlertEngine _engine;

  List<TerritoryAlert> _alerts = const [];
  Map<String, AlertDecision> _decisions = {};
  Set<String> _notified = {};

  int _lastVersion = -1;
  AlertThresholds? _lastThresholds;
  int _lastOccurrences = -1;

  List<TerritoryAlert> get alerts => _alerts;
  Map<String, AlertDecision> get decisions => _decisions;

  List<TerritoryAlert> forRegion(String regionId) =>
      _alerts.where((a) => a.regionId == regionId).toList();

  TerritoryAlert? byId(String id) {
    for (final a in _alerts) {
      if (a.id == id) return a;
    }
    return null;
  }

  AlertDecision? decisionFor(String alertId) => _decisions[alertId];

  DecisionStatus statusOf(String alertId) =>
      _decisions[alertId]?.status ?? DecisionStatus.pending;

  int get pendingCount =>
      _alerts.where((a) => statusOf(a.id) == DecisionStatus.pending).length;

  int get criticalPendingCount => _alerts
      .where((a) => a.severity == AlertSeverity.critical && statusOf(a.id) == DecisionStatus.pending)
      .length;

  SocialImpact get impact => SocialImpact.compute(
        alerts: _alerts,
        decisions: _decisions,
        occurrences: _occurrences.items,
        regionsWithData: _territory.snapshots.entries
            .where((e) => e.value.series.isNotEmpty)
            .map((e) => e.key)
            .toSet(),
      );

  /// Registra a decisão humana (confirmar ou descartar) com justificativa.
  Future<void> decide(String alertId, DecisionStatus status, String note) async {
    _decisions = {
      ..._decisions,
      alertId: AlertDecision(
        alertId: alertId,
        status: status,
        note: note.trim(),
        decidedAt: DateTime.now(),
      ),
    };
    await _persistDecisions();
    notifyListeners();
  }

  Future<void> undoDecision(String alertId) async {
    _decisions = Map.of(_decisions)..remove(alertId);
    await _persistDecisions();
    notifyListeners();
  }

  void _onDependencyChanged() {
    final changed = _territory.version != _lastVersion ||
        _settings.thresholds != _lastThresholds ||
        _occurrences.items.length != _lastOccurrences;
    if (!changed) return;
    recompute();
  }

  /// Limpa decisões em memória após a revogação do consentimento (o
  /// armazenamento local já foi apagado).
  void resetLocalState() {
    _decisions = {};
    _notified = {};
    notifyListeners();
  }

  @visibleForTesting
  void recompute() {
    _lastVersion = _territory.version;
    _lastThresholds = _settings.thresholds;
    _lastOccurrences = _occurrences.items.length;

    final now = DateTime.now();
    final out = <TerritoryAlert>[];
    for (final region in Territory.regions) {
      final snap = _territory.snapshot(region.id);
      if (snap == null || snap.series.isEmpty) continue;
      out.addAll(_engine.evaluate(AlertContext(
        region: region,
        snapshot: snap,
        thresholds: _settings.thresholds,
        now: now,
        citizenReports: _occurrences.recentByIndicator(region.id, now: now),
      )));
    }
    out.sort((a, b) {
      final s = b.severity.rank.compareTo(a.severity.rank);
      return s != 0 ? s : b.confidence.score.compareTo(a.confidence.score);
    });
    _alerts = out;
    notifyListeners();
    _notifyCritical();
  }

  /// Notifica uma única vez cada alerta crítico com confiança suficiente.
  Future<void> _notifyCritical() async {
    if (!_settings.notificationsEnabled) return;
    final min = _settings.thresholds.notifyMinConfidence;
    var changed = false;
    for (final a in _alerts) {
      if (a.severity != AlertSeverity.critical ||
          a.confidence.score < min ||
          _notified.contains(a.id)) {
        continue;
      }
      await _notifications.showCritical(a);
      _notified.add(a.id);
      changed = true;
    }
    if (changed) await _store.writeJson(LocalStore.kNotified, _notified.toList());
  }

  Future<void> _persistDecisions() => _store.writeJson(
        LocalStore.kDecisions,
        _decisions.values.map((d) => d.toJson()).toList(),
      );

  @override
  void dispose() {
    _territory.removeListener(_onDependencyChanged);
    _settings.removeListener(_onDependencyChanged);
    _occurrences.removeListener(_onDependencyChanged);
    super.dispose();
  }
}
