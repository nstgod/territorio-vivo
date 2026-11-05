import 'package:flutter/material.dart';

import '../core/utils/anonymizer.dart';
import '../data/models/alert_thresholds.dart';
import '../data/sources/local_store.dart';
import '../services/notification_service.dart';

/// Estado global de preferências, consentimento e limiares — persistido.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._store, this._notifications);

  final LocalStore _store;
  final NotificationService _notifications;

  static const consentVersion = 1;

  ThemeMode _themeMode = ThemeMode.system;
  bool _highContrast = false;
  double _textScale = 1.0;
  bool _simulateOffline = false;
  bool _notificationsEnabled = false;
  DateTime? _consentAt;
  AlertThresholds _thresholds = AlertThresholds.defaults;
  String _reporterToken = '';

  ThemeMode get themeMode => _themeMode;
  bool get highContrast => _highContrast;
  double get textScale => _textScale;
  bool get simulateOffline => _simulateOffline;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get hasConsent => _consentAt != null;
  DateTime? get consentAt => _consentAt;
  AlertThresholds get thresholds => _thresholds;

  /// Token anônimo deste aparelho (não identifica a pessoa).
  String get reporterToken => _reporterToken;

  void load() {
    final s = _store.readMap(LocalStore.kSettings) ?? const {};
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == s['themeMode'],
      orElse: () => ThemeMode.system,
    );
    _highContrast = s['highContrast'] as bool? ?? false;
    _textScale = (s['textScale'] as num?)?.toDouble() ?? 1.0;
    _simulateOffline = s['simulateOffline'] as bool? ?? false;
    _notificationsEnabled = s['notifications'] as bool? ?? false;

    final consent = _store.readMap(LocalStore.kConsent);
    if (consent != null && consent['version'] == consentVersion) {
      _consentAt = DateTime.tryParse(consent['at'] as String? ?? '');
    }
    final t = _store.readMap(LocalStore.kThresholds);
    _thresholds = t == null ? AlertThresholds.defaults : AlertThresholds.fromJson(t);

    _reporterToken = _store.readString(LocalStore.kReporterToken) ?? '';
    if (_reporterToken.isEmpty) {
      _reporterToken = Anonymizer.randomToken();
      _store.writeString(LocalStore.kReporterToken, _reporterToken);
    }
  }

  Future<void> giveConsent() async {
    _consentAt = DateTime.now();
    await _store.writeJson(LocalStore.kConsent, {
      'version': consentVersion,
      'at': _consentAt!.toIso8601String(),
    });
    notifyListeners();
  }

  /// Revoga o consentimento e apaga todos os dados locais do app.
  Future<void> revokeConsentAndErase() async {
    await _store.clearAll();
    _consentAt = null;
    _themeMode = ThemeMode.system;
    _highContrast = false;
    _textScale = 1.0;
    _simulateOffline = false;
    _notificationsEnabled = false;
    _thresholds = AlertThresholds.defaults;
    _reporterToken = Anonymizer.randomToken();
    await _store.writeString(LocalStore.kReporterToken, _reporterToken);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _persist();
  }

  void setHighContrast(bool value) {
    _highContrast = value;
    _persist();
  }

  void setTextScale(double value) {
    _textScale = value.clamp(0.85, 2.0);
    _persist();
  }

  void setSimulateOffline(bool value) {
    _simulateOffline = value;
    _persist();
  }

  Future<bool> setNotificationsEnabled(bool value) async {
    if (value && !await _notifications.requestPermission()) {
      return false;
    }
    _notificationsEnabled = value;
    _persist();
    return true;
  }

  Future<void> saveThresholds(AlertThresholds value) async {
    _thresholds = value;
    await _store.writeJson(LocalStore.kThresholds, value.toJson());
    notifyListeners();
  }

  void _persist() {
    _store.writeJson(LocalStore.kSettings, {
      'themeMode': _themeMode.name,
      'highContrast': _highContrast,
      'textScale': _textScale,
      'simulateOffline': _simulateOffline,
      'notifications': _notificationsEnabled,
    });
    notifyListeners();
  }
}
