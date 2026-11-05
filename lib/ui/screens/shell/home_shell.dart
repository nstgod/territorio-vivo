import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/alerts_provider.dart';
import '../../../state/occurrences_provider.dart';
import '../../../state/territory_provider.dart';
import '../alerts/alerts_screen.dart';
import '../map/map_screen.dart';
import '../occurrences/occurrences_screen.dart';
import '../overview/overview_screen.dart';
import '../settings/settings_screen.dart';

/// Estrutura com navegação inferior entre as 5 áreas principais.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0; // estado local: aba atual

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final territory = context.read<TerritoryProvider>();
      if (!territory.hasData) territory.load();
      context.read<OccurrencesProvider>().load();
    });
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final critical = context.select<AlertsProvider, int>((a) => a.criticalPendingCount);
    final pages = [
      OverviewScreen(onOpenAlerts: () => _goTo(1)),
      const AlertsScreen(),
      const MapScreen(),
      const OccurrencesScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início',
            tooltip: 'Visão geral do território',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: critical > 0,
              label: Text('$critical'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alertas',
            tooltip: critical > 0 ? 'Alertas, $critical crítico(s) aguardando análise' : 'Alertas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
            tooltip: 'Mapa das regiões',
          ),
          const NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Ocorrências',
            tooltip: 'Ocorrências cidadãs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Ajustes',
            tooltip: 'Ajustes, acessibilidade e privacidade',
          ),
        ],
      ),
    );
  }
}
