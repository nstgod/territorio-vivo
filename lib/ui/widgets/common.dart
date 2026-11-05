import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Card padrão do app (borda, raio e espaçamento vindos do tema).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.semanticLabel,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final card = Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
    if (semanticLabel == null) return card;
    // MergeSemantics junta rótulo e ação de toque num único nó: o leitor de
    // tela anuncia o card inteiro e o duplo toque o aciona.
    return MergeSemantics(
      child: Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: card,
      ),
    );
  }
}

/// Título de seção com ação opcional à direita.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: t.titleMedium)),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: t.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Centraliza e limita a largura do conteúdo em telas largas.
class ContentConstraint extends StatelessWidget {
  const ContentConstraint({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: child,
      ),
    );
  }
}

/// Número de colunas de grade conforme a largura disponível.
int gridColumnsFor(double width) {
  if (width >= 900) return 3;
  if (width >= 560) return 2;
  return 1;
}

/// Grade responsiva simples (sem altura fixa, respeita fonte ampliada).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minColumns = 1});

  final List<Widget> children;
  final int minColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = gridColumnsFor(c.maxWidth).clamp(minColumns, 4);
      const gap = AppSpacing.sm;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

/// Pílula colorida de status.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 1),
        decoration: BoxDecoration(color: background, borderRadius: AppRadius.chip),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa informativa (aviso de decisão humana, cache, modo offline…).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.tone = BannerTone.info,
    this.action,
  });

  final IconData icon;
  final String? title;
  final String message;
  final BannerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = context.statusColors;
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (tone) {
      BannerTone.info => s.info,
      BannerTone.warning => s.warning,
      BannerTone.critical => s.critical,
      BannerTone.neutral => scheme.primary,
    };
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: tone != BannerTone.neutral,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: AppRadius.card,
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title!, style: t.titleSmall?.copyWith(color: scheme.onSurface)),
                  Text(message, style: t.bodyMedium?.copyWith(color: scheme.onSurface)),
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum BannerTone { info, warning, critical, neutral }

/// Aviso fixo exigido: os alertas apoiam, mas não substituem, a decisão humana.
class HumanDecisionNotice extends StatelessWidget {
  const HumanDecisionNotice({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      icon: Icons.verified_user_outlined,
      tone: BannerTone.neutral,
      title: compact ? null : 'A decisão final é sempre humana',
      message: compact
          ? 'Alertas apoiam, mas não substituem, a decisão do gestor.'
          : 'Os alertas são gerados por regras e modelos estatísticos para apoiar a '
              'análise. Nenhuma ação é tomada automaticamente: cada alerta precisa '
              'ser avaliado e registrado por uma pessoa responsável.',
    );
  }
}
