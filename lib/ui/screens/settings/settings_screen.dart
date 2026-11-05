import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/occurrences_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/common.dart';

/// Ajustes: aparência e acessibilidade, alertas, dados e privacidade.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _revoke(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined),
        title: const Text('Revogar consentimento?'),
        content: const Text(
          'Todos os dados deste app no aparelho serão apagados: ocorrências, decisões, '
          'limiares, preferências e cache. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Apagar tudo')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final alerts = context.read<AlertsProvider>();
    final occurrences = context.read<OccurrencesProvider>();
    await context.read<SettingsProvider>().revokeConsentAndErase();
    alerts.resetLocalState();
    occurrences.reset();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final territory = context.watch<TerritoryProvider>();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ContentConstraint(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
          children: [
            const SectionHeader('Aparência e acessibilidade'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tema', style: t.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => s.setThemeMode(v.first),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alto contraste'),
                    subtitle: const Text('Cores com contraste reforçado (WCAG AAA) e bordas mais grossas.'),
                    value: s.highContrast,
                    onChanged: s.setHighContrast,
                  ),
                  const Divider(),
                  Text('Tamanho do texto: ${Fmt.percent(s.textScale)}', style: t.titleSmall),
                  Slider(
                    value: s.textScale,
                    min: 0.85,
                    max: 2.0,
                    divisions: 23,
                    label: Fmt.percent(s.textScale),
                    semanticFormatterCallback: (v) => 'Tamanho do texto ${Fmt.percent(v)}',
                    onChanged: s.setTextScale,
                  ),
                  Text(
                    'Somado à configuração de fonte do sistema. Prévia: Alerta crítico em Itaquera.',
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
            const SectionHeader('Alertas'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Limiares de alerta'),
                    subtitle: const Text('Defina quando cada alerta deve disparar'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.thresholds),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Notificar alertas críticos'),
                    subtitle: Text(
                      'Só críticos com confiança ≥ ${Fmt.percent(s.thresholds.notifyMinConfidence)}. '
                      'A notificação apenas avisa — nada é executado.',
                    ),
                    value: s.notificationsEnabled,
                    onChanged: (v) async {
                      final ok = await s.setNotificationsEnabled(v);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Notificações indisponíveis neste dispositivo ou permissão negada.'),
                        ));
                      }
                    },
                  ),
                ],
              ),
            ),
            const SectionHeader('Dados e conexão'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_off_outlined),
                    title: const Text('Simular modo offline'),
                    subtitle: const Text('Ignora a rede e usa somente os dados salvos no aparelho.'),
                    value: s.simulateOffline,
                    onChanged: (v) {
                      s.setSimulateOffline(v);
                      territory.load();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Atualizar dados agora'),
                    subtitle: Text(territory.fetchedAt == null
                        ? 'Nenhum dado carregado'
                        : 'Última carga: ${Fmt.dateTime(territory.fetchedAt!)}'
                            '${territory.fromCache ? ' (cache)' : ''}'),
                    trailing: territory.isLoading
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                    onTap: territory.isLoading ? null : territory.load,
                  ),
                ],
              ),
            ),
            const SectionHeader('Privacidade (LGPD)'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Termos e consentimento'),
                    subtitle: Text(s.consentAt == null ? 'Não registrado' : 'Aceito em ${Fmt.longDate(s.consentAt!)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.consent),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.fingerprint),
                    title: const Text('Identificador anônimo do aparelho'),
                    subtitle: Text('${s.reporterToken.substring(0, 4)}•••• · aleatório, não identifica você'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                    title: const Text('Revogar consentimento e apagar dados'),
                    onTap: () => _revoke(context),
                  ),
                ],
              ),
            ),
            const SectionHeader('Sobre'),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Metodologia, métricas e limitações'),
                subtitle: const Text('Território Vivo 1.0 · FIAP Global Solution 2026.2'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.methodology),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
