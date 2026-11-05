import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/alert.dart';
import '../../../data/models/region.dart';
import '../../../services/explanation_service.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/settings_provider.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/indicator_chart.dart';
import '../../widgets/state_views.dart';

/// Detalhe do alerta: evidência, confiança (com fatores), limitações,
/// explicação simples e o registro da decisão humana.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertsProvider>();
    final alert = alerts.byId(alertId);
    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alerta')),
        body: const EmptyView(
          icon: Icons.notifications_paused_outlined,
          title: 'Este alerta não está mais ativo',
          message: 'Os dados ou os limiares mudaram e a condição deixou de ocorrer. '
              'Decisões já registradas continuam salvas.',
        ),
      );
    }
    final region = Territory.byId(alert.regionId);
    final t = Theme.of(context).textTheme;
    final decision = alerts.decisionFor(alert.id);

    return Scaffold(
      appBar: AppBar(title: Text(alert.kind.label)),
      body: ContentConstraint(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                SeverityBadge(alert.severity),
                ConfidenceBadge(alert.confidence),
                DecisionBadge(decision?.status ?? DecisionStatus.pending),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(header: true, child: Text(alert.title, style: t.headlineSmall)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${region.name} · ${alert.indicator.label} · gerado em ${Fmt.dateTime(alert.generatedAt)}',
              style: t.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(alert.summary, style: t.bodyLarge),
            if (!alert.confidence.isReliable) ...[
              const SizedBox(height: AppSpacing.md),
              const InfoBanner(
                icon: Icons.report_outlined,
                tone: BannerTone.warning,
                title: 'Previsão pouco confiável',
                message: 'A nota de confiança está abaixo de 50%. Trate como sinal para '
                    'investigar, não como base para decisão.',
              ),
            ],
            const SectionHeader('Por que este alerta? (evidências)'),
            AppCard(child: _Bullets(alert.evidence, icon: Icons.analytics_outlined)),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(alert.indicator.label, style: t.titleSmall)),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppRoutes.indicator,
                          arguments: IndicatorArgs(regionId: alert.regionId, indicator: alert.indicator),
                        ),
                        child: const Text('Ver indicador'),
                      ),
                    ],
                  ),
                  IndicatorChart(regionId: alert.regionId, indicator: alert.indicator, lastDays: 30),
                ],
              ),
            ),
            const SectionHeader(
              'Nível de confiança',
              subtitle: 'Média ponderada de quatro fatores explícitos',
            ),
            _ConfidenceCard(confidence: alert.confidence),
            const SectionHeader('Limitações e quando não confiar'),
            AppCard(child: _Bullets(alert.limitations, icon: Icons.warning_amber_outlined)),
            const SectionHeader('Explicação em linguagem simples'),
            _ExplanationCard(alert: alert),
            const SectionHeader(
              'Sugestões para análise',
              subtitle: 'O app não executa nenhuma destas ações',
            ),
            AppCard(child: _Bullets(alert.suggestedActions, icon: Icons.lightbulb_outline)),
            const SectionHeader('Decisão humana'),
            const HumanDecisionNotice(),
            const SizedBox(height: AppSpacing.sm),
            _DecisionSection(alert: alert, decision: decision),
          ],
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items, {required this.icon});

  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, size: 18, color: scheme.primary)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.confidence});

  final AlertConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final s = context.statusColors;
    Color colorFor(double v) => v >= 0.75 ? s.ok : (v >= 0.5 ? s.warning : s.critical);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Confiança geral ${confidence.level.label}, ${Fmt.percent(confidence.score)}',
            excludeSemantics: true,
            child: Row(
              children: [
                Text(Fmt.percent(confidence.score), style: t.headlineMedium),
                const SizedBox(width: AppSpacing.sm),
                Text('confiança ${confidence.level.label.toLowerCase()}', style: t.titleSmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final f in confidence.factors)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
              child: Semantics(
                label: '${f.label}: ${Fmt.percent(f.score)}. ${f.explanation}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(f.label, style: t.bodyMedium)),
                        Text(Fmt.percent(f.score), style: t.labelLarge),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: f.score),
                        duration: AppDurations.slow,
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          color: colorFor(f.score),
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(f.explanation, style: t.bodySmall),
                  ],
                ),
              ),
            ),
          Text(
            'Faixas: alta ≥ 75% · média ≥ 50% · baixa < 50% (não confiável para decisão).',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatefulWidget {
  const _ExplanationCard({required this.alert});

  final TerritoryAlert alert;

  @override
  State<_ExplanationCard> createState() => _ExplanationCardState();
}

class _ExplanationCardState extends State<_ExplanationCard> {
  late Future<AlertExplanation> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ExplanationService>().explain(
          widget.alert,
          offline: context.read<SettingsProvider>().simulateOffline,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: FutureBuilder<AlertExplanation>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Row(
              children: [
                SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Preparando explicação…')),
              ],
            );
          }
          final e = snap.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.text, style: t.bodyLarge),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(e.generatedByAi ? Icons.auto_awesome : Icons.article_outlined, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      e.generatedByAi
                          ? 'Gerado por IA (Claude) a partir das evidências acima — pode conter imprecisões.'
                          : 'Texto automático montado a partir das evidências (IA não configurada ou offline).',
                      style: t.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DecisionSection extends StatefulWidget {
  const _DecisionSection({required this.alert, required this.decision});

  final TerritoryAlert alert;
  final AlertDecision? decision;

  @override
  State<_DecisionSection> createState() => _DecisionSectionState();
}

class _DecisionSectionState extends State<_DecisionSection> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  DecisionStatus _choice = DecisionStatus.confirmed;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await context.read<AlertsProvider>().decide(widget.alert.id, _choice, _note.text);
    if (!mounted) return;
    setState(() => _saving = false);
    _note.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Decisão registrada: ${_choice.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = widget.decision;
    if (d != null && d.status != DecisionStatus.pending) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecisionBadge(d.status),
            const SizedBox(height: AppSpacing.sm),
            Text('${d.reviewerRole} · ${Fmt.dateTime(d.decidedAt)}', style: t.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text('Justificativa: ${d.note}', style: t.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.read<AlertsProvider>().undoDecision(widget.alert.id),
              icon: const Icon(Icons.undo),
              label: const Text('Reabrir análise'),
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Após avaliar as evidências, registre sua decisão:', style: t.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<DecisionStatus>(
              segments: const [
                ButtonSegment(
                  value: DecisionStatus.confirmed,
                  icon: Icon(Icons.check),
                  label: Text('Confirmar'),
                  tooltip: 'Confirmar: o alerta procede e será encaminhado',
                ),
                ButtonSegment(
                  value: DecisionStatus.dismissed,
                  icon: Icon(Icons.close),
                  label: Text('Descartar'),
                  tooltip: 'Descartar: falso alarme ou já tratado',
                ),
              ],
              selected: {_choice},
              onSelectionChanged: (v) => setState(() => _choice = v.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 300,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Justificativa da decisão *',
                hintText: 'Ex.: vistoria solicitada à concessionária; relatos confirmam vazamento.',
                helperText: 'Fica registrada para auditoria (sem nome do responsável).',
              ),
              validator: Validators.decisionNote,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.gavel),
              label: const Text('Registrar decisão'),
            ),
          ],
        ),
      ),
    );
  }
}
