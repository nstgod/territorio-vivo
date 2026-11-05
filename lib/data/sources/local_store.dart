import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local (chave-valor JSON) sobre SharedPreferences.
///
/// Guarda: preferências, consentimento, limiares, decisões humanas sobre
/// alertas, ocorrências cidadãs e o cache das séries por região — tudo o
/// que mantém o app útil sem conexão.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  static const kSettings = 'settings.v1';
  static const kThresholds = 'thresholds.v1';
  static const kConsent = 'consent.v1';
  static const kDecisions = 'decisions.v1';
  static const kOccurrences = 'occurrences.v1';
  static const kNotified = 'notified_alerts.v1';
  static const kReporterToken = 'reporter_token.v1';
  static const kCachePrefix = 'cache.region.v1.';

  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  List<dynamic> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      return jsonDecode(raw) as List<dynamic>;
    } on FormatException {
      return const [];
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  String? readString(String key) => _prefs.getString(key);
  Future<void> writeString(String key, String value) => _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Apaga todos os dados do app (revogação de consentimento).
  Future<void> clearAll() => _prefs.clear();
}
