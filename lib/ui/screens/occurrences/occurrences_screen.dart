import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/occurrence.dart';
import '../../../data/models/region.dart';
import '../../../state/occurrences_provider.dart';
import '../../../state/view_status.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';

/// Ocorrências registradas neste aparelho (anônimas).
class OccurrencesScreen extends StatelessWidget {
  const OccurrencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OccurrencesProvider>();
    final Widget body = switch (state.status) {
      ViewStatus.initial || ViewStatus.loading => const LoadingView(message: 'Carregando ocorrências…'),
      ViewStatus.error => ErrorView(message: state.error ?? 'Erro.', onRetry: state.load),
      ViewStatus.success when state.items.isEmpty => EmptyView(
          icon: Icons.campaign_outlined,
          title: 'Nenhuma ocorrência registrada',
          message: 'Viu um vazamento, lixo acumulado ou alagamento? Registre de forma '
              'anônima — o relato vira evidência complementar nos alertas da região.',
          action: FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.newOccurrence),
            icon: const Icon(Icons.add),
            label: const Text('Registrar ocorrência'),
          ),
        ),
      ViewStatus.success => ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
          itemCount: state.items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) {
            if (i == 0) {
              return const InfoBanner(
                icon: Icons.privacy_tip_outlined,
                message: 'Relatos sem nome, contato ou GPS. Dados pessoais digitados são '
                    'removidos antes de salvar.',
              );
            }
            return _OccurrenceCard(item: state.items[i - 1]);
          },
        ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Ocorrências cidadãs')),
      floatingActionButton: state.items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.newOccurrence),
              icon: const Icon(Icons.add),
              label: const Text('Registrar'),
              tooltip: 'Registrar nova ocorrência',
            ),
      body: ContentConstraint(child: body),
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({required this.item});

  final Occurrence item;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Excluir ocorrência?'),
        content: const Text('O relato será removido deste aparelho.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<OccurrencesProvider>().remove(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final region = Territory.byId(item.regionId).name;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: Icon(item.category.icon),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.category.label, style: t.titleSmall),
                      Text(
                        '$region · ${Fmt.weekdayDayMonth(item.occurredOn)} · gravidade ${item.severity}/5',
                        style: t.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(item.description, style: t.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (item.redactedItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text('Removido para proteger privacidade: ${item.redactedItems.join(', ')}',
                      style: t.bodySmall),
                ),
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir'),
            ),
          ),
        ],
      ),
    );
  }
}
