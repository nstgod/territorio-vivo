import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territorio_vivo/core/routes/app_routes.dart';
import 'package:territorio_vivo/core/theme/app_theme.dart';
import 'package:territorio_vivo/data/repositories/territory_repository.dart';
import 'package:territorio_vivo/data/sources/local_store.dart';
import 'package:territorio_vivo/data/sources/open_meteo_api.dart';
import 'package:territorio_vivo/data/sources/synthetic_territory_api.dart';
import 'package:territorio_vivo/services/notification_service.dart';
import 'package:territorio_vivo/state/occurrences_provider.dart';
import 'package:territorio_vivo/state/settings_provider.dart';
import 'package:territorio_vivo/state/territory_provider.dart';
import 'package:territorio_vivo/ui/screens/consent/consent_screen.dart';
import 'package:territorio_vivo/ui/screens/occurrences/occurrence_form_screen.dart';

void main() {
  late LocalStore store;
  late SettingsProvider settings;
  late OccurrencesProvider occurrences;
  late TerritoryProvider territory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
    settings = SettingsProvider(store, NotificationService())..load();
    occurrences = OccurrencesProvider(store);
    territory = TerritoryProvider(
      TerritoryRepository(store: store, climateApi: OpenMeteoApi(), syntheticApi: SyntheticTerritoryApi()),
      settings,
    );
  });

  Widget host(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: occurrences),
          ChangeNotifierProvider.value(value: territory),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
          ),
        ),
      );

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('formulário de ocorrência mostra erros claros e não salva inválido', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(host(const OccurrenceFormScreen(args: OccurrenceFormArgs())));

    await tester.tap(find.text('Enviar ocorrência'));
    await tester.pumpAndSettle();

    expect(find.text('O tipo de problema é obrigatório.'), findsOneWidget);
    expect(find.text('Descreva o que está acontecendo.'), findsOneWidget);
    expect(find.text('Confirme a declaração para enviar.'), findsOneWidget);
    expect(occurrences.items, isEmpty);
  });

  testWidgets('formulário válido salva a ocorrência anonimizada', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(host(const OccurrenceFormScreen(args: OccurrenceFormArgs())));

    await tester.tap(find.text('Tipo de problema *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazamento de água').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descreva o problema *'),
      'Água jorrando na calçada, me liga 11 98765-4321',
    );
    await tester.pump();
    expect(find.textContaining('Detectamos telefone'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Enviar ocorrência'));
    await tester.pumpAndSettle();

    expect(occurrences.items, hasLength(1));
    final saved = occurrences.items.single;
    expect(saved.description, isNot(contains('98765')));
    expect(saved.redactedItems, contains('telefone'));
    expect(saved.regionId, territory.selectedRegionId);
  });

  testWidgets('consentimento exige as duas confirmações', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(host(const ConsentScreen(onboarding: true)));

    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pump();
    expect(find.text('Marque as duas confirmações para continuar.'), findsOneWidget);
    expect(settings.hasConsent, isFalse);

    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();
    expect(settings.hasConsent, isTrue);
  });
}
