import 'package:flutter/foundation.dart';

import '../core/utils/anonymizer.dart';
import '../data/models/indicator.dart';
import '../data/models/occurrence.dart';
import '../data/sources/local_store.dart';
import 'view_status.dart';

/// Ocorrências registradas por cidadãos (persistidas localmente).
class OccurrencesProvider extends ChangeNotifier {
  OccurrencesProvider(this._store);

  final LocalStore _store;

  ViewStatus _status = ViewStatus.initial;
  List<Occurrence> _items = const [];
  String? _error;

  ViewStatus get status => _status;
  String? get error => _error;
  List<Occurrence> get items => _items;

  Future<void> load() async {
    _status = ViewStatus.loading;
    notifyListeners();
    try {
      _items = _store
          .readList(LocalStore.kOccurrences)
          .map((e) => Occurrence.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _status = ViewStatus.success;
    } catch (e) {
      _status = ViewStatus.error;
      _error = 'Não foi possível ler as ocorrências salvas.';
    }
    notifyListeners();
  }

  /// Anonimiza e salva uma ocorrência. Retorna o que foi removido do texto.
  Future<Occurrence> add({
    required OccurrenceCategory category,
    required String regionId,
    required String description,
    required int severity,
    required DateTime occurredOn,
    required String reporterToken,
  }) async {
    final clean = Anonymizer.anonymize(description);
    final now = DateTime.now();
    final item = Occurrence(
      id: '${now.microsecondsSinceEpoch}-${Anonymizer.randomToken().substring(0, 4)}',
      category: category,
      regionId: regionId,
      description: clean.text,
      severity: severity,
      occurredOn: occurredOn,
      createdAt: now,
      reporterToken: reporterToken,
      redactedItems: clean.removed,
    );
    _items = [item, ..._items];
    await _persist();
    _status = ViewStatus.success;
    notifyListeners();
    return item;
  }

  Future<void> remove(String id) async {
    _items = _items.where((o) => o.id != id).toList();
    await _persist();
    notifyListeners();
  }

  /// Relatos dos últimos 7 dias por indicador relacionado, numa região.
  Map<IndicatorId, int> recentByIndicator(String regionId, {DateTime? now}) {
    final limit = (now ?? DateTime.now()).subtract(const Duration(days: 7));
    final out = <IndicatorId, int>{};
    for (final o in _items) {
      final ind = o.category.relatedIndicator;
      if (ind == null || o.regionId != regionId || o.occurredOn.isBefore(limit)) continue;
      out[ind] = (out[ind] ?? 0) + 1;
    }
    return out;
  }

  /// Usado após a revogação do consentimento.
  void reset() {
    _items = const [];
    _status = ViewStatus.success;
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeJson(LocalStore.kOccurrences, _items.map((o) => o.toJson()).toList());
}
