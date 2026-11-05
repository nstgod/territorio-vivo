import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/territory_repository.dart';
import 'data/sources/local_store.dart';
import 'data/sources/open_meteo_api.dart';
import 'data/sources/synthetic_territory_api.dart';
import 'services/explanation_service.dart';
import 'services/notification_service.dart';
import 'state/alerts_provider.dart';
import 'state/occurrences_provider.dart';
import 'state/settings_provider.dart';
import 'state/territory_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.open();
  final notifications = NotificationService();
  await notifications.init();

  final settings = SettingsProvider(store, notifications)..load();
  final occurrences = OccurrencesProvider(store);
  final territory = TerritoryProvider(
    TerritoryRepository(
      store: store,
      climateApi: OpenMeteoApi(),
      syntheticApi: SyntheticTerritoryApi(),
    ),
    settings,
  );
  final alerts = AlertsProvider(
    store: store,
    territory: territory,
    settings: settings,
    occurrences: occurrences,
    notifications: notifications,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: territory),
        ChangeNotifierProvider.value(value: occurrences),
        ChangeNotifierProvider.value(value: alerts),
        Provider(create: (_) => ExplanationService()),
      ],
      child: const TerritorioVivoApp(),
    ),
  );
}
