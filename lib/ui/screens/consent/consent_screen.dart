import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/settings_provider.dart';
import '../../widgets/common.dart';

/// Consentimento explícito (LGPD) e compromisso com a decisão humana.
///
/// Em [onboarding] é a primeira tela do app; fora dele (rota /consent)
/// apenas exibe os termos e quando o consentimento foi dado.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _dataTerms = false;
  bool _humanDecision = false;
  bool _submitted = false;

  Future<void> _accept() async {
    setState(() => _submitted = true);
    if (!_dataTerms || !_humanDecision) return;
    await context.read<SettingsProvider>().giveConsent();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final consentAt = context.select<SettingsProvider, DateTime?>((s) => s.consentAt);

    return Scaffold(
      appBar: widget.onboarding ? null : AppBar(title: const Text('Termos e privacidade')),
      body: SafeArea(
        child: ContentConstraint(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (widget.onboarding) ...[
                const SizedBox(height: AppSpacing.md),
                ExcludeSemantics(child: Icon(Icons.travel_explore, size: 56, color: scheme.primary)),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text('Bem-vindo ao Território Vivo', style: t.headlineMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Painel de inteligência territorial da Zona Leste de São Paulo: '
                  'acompanhe clima, qualidade do ar, consumo de água e energia e a '
                  'demanda por serviços — com alertas preditivos explicados.',
                  style: t.bodyLarge,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const _TermItem(
                icon: Icons.dataset_outlined,
                title: 'Quais dados usamos',
                text: 'Dados públicos de clima e qualidade do ar (Open-Meteo) e séries '
                    'sintéticas de consumo e serviços, claramente identificadas. Nenhum '
                    'dado de consumo individual é coletado.',
              ),
              const _TermItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Seus relatos são anônimos',
                text: 'Ocorrências não pedem nome, e-mail, telefone nem GPS: a localização '
                    'é apenas a região. Telefones, e-mails, CPF e números de endereço '
                    'digitados são removidos automaticamente antes de salvar.',
              ),
              const _TermItem(
                icon: Icons.phone_android_outlined,
                title: 'Tudo fica no seu aparelho',
                text: 'Preferências, ocorrências, decisões e cache ficam salvos localmente. '
                    'Você pode revogar o consentimento e apagar tudo em Ajustes, a qualquer momento.',
              ),
              const _TermItem(
                icon: Icons.auto_awesome_outlined,
                title: 'Explicações por IA (opcional)',
                text: 'Se habilitada, a explicação em linguagem simples envia ao modelo de IA '
                    'apenas os números agregados do alerta — nunca dados pessoais.',
              ),
              const _TermItem(
                icon: Icons.verified_user_outlined,
                title: 'A decisão é humana',
                text: 'Alertas são previsões com incerteza. O app nunca executa ações: ele '
                    'mostra evidências, confiança e limitações para apoiar quem decide.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (!widget.onboarding)
                InfoBanner(
                  icon: Icons.check_circle_outline,
                  message: consentAt == null
                      ? 'Consentimento não registrado.'
                      : 'Consentimento registrado em ${Fmt.longDate(consentAt)} às '
                          '${Fmt.two(consentAt.hour)}:${Fmt.two(consentAt.minute)}.',
                )
              else ...[
                _ConsentCheck(
                  value: _dataTerms,
                  error: _submitted && !_dataTerms,
                  label: 'Li e concordo com o tratamento de dados descrito acima (LGPD).',
                  onChanged: (v) => setState(() => _dataTerms = v),
                ),
                _ConsentCheck(
                  value: _humanDecision,
                  error: _submitted && !_humanDecision,
                  label: 'Entendo que os alertas apoiam, mas não substituem, a decisão humana.',
                  onChanged: (v) => setState(() => _humanDecision = v),
                ),
                if (_submitted && (!_dataTerms || !_humanDecision))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        'Marque as duas confirmações para continuar.',
                        style: t.bodyMedium?.copyWith(color: scheme.error),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _accept,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Aceitar e continuar'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.methodology),
                  child: const Text('Como os alertas funcionam (metodologia)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TermItem extends StatelessWidget {
  const _TermItem({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(text, style: t.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentCheck extends StatelessWidget {
  const _ConsentCheck({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.error,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(label),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      isError: error,
    );
  }
}
