import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/alert.dart';
import '../../../data/models/region.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';

/// Lista de alertas de todo o território, com filtros (estado local).
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.initialRegionId, this.standalone = false});

  final String? initialRegionId;

  /// Verdadeiro quando aberta por rota (com botão voltar), não pela aba.
  final bool standalone;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late String? _regionId = widget.initialRegionId;
  AlertSeverity? _severity;
  DecisionStatus? _status = DecisionStatus.pending;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final alerts = context.watch<AlertsProvider>();
    final filtered = alerts.alerts.where((a) {
      if (_regionId != null && a.regionId != _regionId) return false;
      if (_severity != null && a.severity != _severity) return false;
      if (_status != null && alerts.statusOf(a.id) != _status) return false;
      return true;
    }).toList();

    final Widget list;
    if (!territory.hasData && territory.isLoading) {
      list = const LoadingView(message: 'Calculando alertas…');
    } else if (!territory.hasData) {
      list = ErrorView(message: territory.error ?? 'Sem dados para gerar alertas.', onRetry: territory.load);
    } else if (filtered.isEmpty) {
      list = EmptyView(
        icon: Icons.notifications_off_outlined,
        title: 'Nenhum alerta com estes filtros',
        message: alerts.alerts.isEmpty
            ? 'Os dados atuais não ultrapassam nenhum limiar. Ajuste os limiares em Ajustes, se necessário.'
            : 'Altere os filtros para ver outros alertas.',
        action: (_regionId != null || _severity != null || _status != null)
            ? OutlinedButton(
                onPressed: () => setState(() {
                  _regionId = null;
                  _severity = null;
                  _status = null;
                }),
                child: const Text('Limpar filtros'),
              )
            : null,
      );
    } else {
      list = ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          final a = filtered[i];
          return AlertTile(
            alert: a,
            status: alerts.statusOf(a.id),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.alert, arguments: AlertArgs(a.id)),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: Text('Alertas (${filtered.length})'),
        actions: [
          IconButton(
            tooltip: 'Configurar limiares de alerta',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.thresholds),
          ),
        ],
      ),
      body: ContentConstraint(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
              child: Column(
                children: [
                  const HumanDecisionNotice(compact: true),
                  const SizedBox(height: AppSpacing.sm),
                  _Filters(
                    regionId: _regionId,
                    severity: _severity,
                    status: _status,
                    onRegion: (v) => setState(() => _regionId = v),
                    onSeverity: (v) => setState(() => _severity = v),
                    onStatus: (v) => setState(() => _status = v),
                  ),
                ],
              ),
            ),
            Expanded(child: AnimatedSwitcher(duration: AppDurations.fast, child: list)),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.regionId,
    required this.severity,
    required this.status,
    required this.onRegion,
    required this.onSeverity,
    required this.onStatus,
  });

  final String? regionId;
  final AlertSeverity? severity;
  final DecisionStatus? status;
  final ValueChanged<String?> onRegion;
  final ValueChanged<AlertSeverity?> onSeverity;
  final ValueChanged<DecisionStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: regionId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Região',
            prefixIcon: Icon(Icons.place_outlined),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas as regiões')),
            for (final r in Territory.regions) DropdownMenuItem(value: r.id, child: Text(r.name)),
          ],
          onChanged: onRegion,
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in [null, ...DecisionStatus.values])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    label: Text(switch (s) {
                      null => 'Todos',
                      DecisionStatus.pending => 'Pendentes',
                      DecisionStatus.confirmed => 'Confirmados',
                      DecisionStatus.dismissed => 'Descartados',
                    }),
                    selected: status == s,
                    onSelected: (_) => onStatus(s),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              for (final s in AlertSeverity.values.reversed)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    label: Text(s.label),
                    selected: severity == s,
                    onSelected: (sel) => onSeverity(sel ? s : null),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
