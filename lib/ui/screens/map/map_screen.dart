import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/alert.dart';
import '../../../data/models/region.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/common.dart';

/// Mapa das regiões colorido pelo alerta mais grave. Abaixo, a mesma
/// informação em lista (alternativa acessível ao mapa).
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertsProvider>();
    final territory = context.watch<TerritoryProvider>();
    final s = context.statusColors;
    final scheme = Theme.of(context).colorScheme;

    AlertSeverity? worst(String regionId) {
      final list = alerts.forRegion(regionId);
      if (list.isEmpty) return null;
      return list.map((a) => a.severity).reduce((a, b) => a.rank >= b.rank ? a : b);
    }

    Color colorFor(AlertSeverity? sev) => switch (sev) {
          AlertSeverity.critical => s.critical,
          AlertSeverity.attention => s.warning,
          AlertSeverity.info => s.info,
          null => s.ok,
        };

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa do território')),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final map = Semantics(
          label: 'Mapa da Zona Leste com ${Territory.regions.length} regiões. '
              'A lista ao lado traz as mesmas informações.',
          child: ClipRRect(
            borderRadius: AppRadius.card,
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(-23.565, -46.46),
                initialZoom: 11.3,
                minZoom: 9,
                maxZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'br.com.fiap.territorio_vivo',
                ),
                CircleLayer(
                  circles: [
                    for (final r in Territory.regions)
                      CircleMarker(
                        point: LatLng(r.latitude, r.longitude),
                        radius: 1500,
                        useRadiusInMeter: true,
                        color: colorFor(worst(r.id)).withValues(alpha: 0.30),
                        borderColor: colorFor(worst(r.id)),
                        borderStrokeWidth: r.id == territory.selectedRegionId ? 4 : 2,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final r in Territory.regions)
                      Marker(
                        point: LatLng(r.latitude, r.longitude),
                        width: 140,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _showRegion(context, r),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: AppRadius.chip,
                                border: Border.all(color: colorFor(worst(r.id)), width: 2),
                              ),
                              child: Text(
                                '${r.name} · ${alerts.forRegion(r.id).length}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                ),
              ],
            ),
          ),
        );
        final list = ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const _Legend(),
            const SizedBox(height: AppSpacing.sm),
            for (final r in Territory.regions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => _showRegion(context, r),
                  semanticLabel: '${r.name}: ${alerts.forRegion(r.id).length} alerta(s), '
                      '${worst(r.id)?.label ?? 'sem alertas'}. Toque para opções.',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        CircleAvatar(radius: 8, backgroundColor: colorFor(worst(r.id))),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(r.name, style: Theme.of(context).textTheme.titleSmall),
                        ),
                        Text('${alerts.forRegion(r.id).length} alerta(s)'),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(flex: 3, child: map),
                SizedBox(width: 320, child: list),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: SizedBox(height: c.maxHeight * 0.48, child: map),
            ),
            Expanded(child: list),
          ],
        );
      }),
    );
  }

  void _showRegion(BuildContext context, Region r) {
    final alerts = context.read<AlertsProvider>().forRegion(r.id);
    final critical = alerts.where((a) => a.severity == AlertSeverity.critical).length;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(r.name, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text('~${Fmt.integer(r.population)} habitantes · ${alerts.length} alerta(s), $critical crítico(s)'),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheet).pop();
                  Navigator.of(context).pushNamed(AppRoutes.alerts, arguments: AlertsArgs(regionId: r.id));
                },
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Ver alertas da região'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<TerritoryProvider>().selectRegion(r.id);
                  Navigator.of(sheet).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${r.name} selecionada nos painéis.')),
                  );
                },
                icon: const Icon(Icons.place_outlined),
                label: const Text('Usar nos painéis'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final s = context.statusColors;
    Widget item(Color c, String l) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 6, backgroundColor: c),
            const SizedBox(width: AppSpacing.xs),
            Text(l, style: Theme.of(context).textTheme.labelMedium),
          ],
        );
    return ExcludeSemantics(
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          item(s.critical, 'Crítico'),
          item(s.warning, 'Atenção'),
          item(s.ok, 'Sem alertas'),
        ],
      ),
    );
  }
}
