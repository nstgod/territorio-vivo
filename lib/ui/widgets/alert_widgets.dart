import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/alert.dart';
import '../../data/models/region.dart';
import 'common.dart';

class SeverityBadge extends StatelessWidget {
  const SeverityBadge(this.severity, {super.key});

  final AlertSeverity severity;

  @override
  Widget build(BuildContext context) {
    final s = context.statusColors;
    final (bg, fg, icon) = switch (severity) {
      AlertSeverity.critical => (s.critical, s.onCritical, Icons.error),
      AlertSeverity.attention => (s.warning, s.onWarning, Icons.warning_amber_rounded),
      AlertSeverity.info => (s.info, s.onInfo, Icons.info_outline),
    };
    return StatusPill(
      label: severity.label,
      background: bg,
      foreground: fg,
      icon: icon,
      semanticLabel: 'Gravidade: ${severity.label}',
    );
  }
}

class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.confidence, {super.key});

  final AlertConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = confidence.level;
    final pct = Fmt.percent(confidence.score);
    return StatusPill(
      label: 'Confiança ${level.label.toLowerCase()} · $pct',
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
      icon: switch (level) {
        ConfidenceLevel.high => Icons.signal_cellular_alt,
        ConfidenceLevel.medium => Icons.signal_cellular_alt_2_bar,
        ConfidenceLevel.low => Icons.signal_cellular_alt_1_bar,
      },
      semanticLabel: 'Confiança ${level.label}, $pct',
    );
  }
}

class DecisionBadge extends StatelessWidget {
  const DecisionBadge(this.status, {super.key});

  final DecisionStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.statusColors;
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon, label) = switch (status) {
      DecisionStatus.pending => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.hourglass_top,
          'Aguarda análise',
        ),
      DecisionStatus.confirmed => (s.ok, s.onOk, Icons.check_circle, 'Confirmado'),
      DecisionStatus.dismissed => (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          Icons.do_not_disturb_on_outlined,
          'Descartado',
        ),
    };
    return StatusPill(
      label: label,
      background: bg,
      foreground: fg,
      icon: icon,
      semanticLabel: 'Situação: ${status.label}',
    );
  }
}

/// Item de lista de alerta, usado na visão geral, na lista e nos dashboards.
class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.alert,
    required this.status,
    required this.onTap,
    this.showRegion = true,
  });

  final TerritoryAlert alert;
  final DecisionStatus status;
  final VoidCallback onTap;
  final bool showRegion;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final region = Territory.byId(alert.regionId).name;
    final s = context.statusColors;
    final accent = switch (alert.severity) {
      AlertSeverity.critical => s.critical,
      AlertSeverity.attention => s.warning,
      AlertSeverity.info => s.info,
    };
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticLabel: '${alert.severity.label}: ${alert.title}. '
          '${showRegion ? 'Região $region. ' : ''}'
          'Confiança ${alert.confidence.level.label}. ${status.label}. Toque para ver a justificativa.',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          SeverityBadge(alert.severity),
                          ConfidenceBadge(alert.confidence),
                          DecisionBadge(status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(alert.title, style: t.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(alert.indicator.icon, size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              [
                                if (showRegion) region,
                                alert.kind.label,
                              ].join(' · '),
                              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
