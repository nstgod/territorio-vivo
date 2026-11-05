import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/indicator.dart';
import '../../../data/models/region.dart';
import '../../../domain/forecaster.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/common.dart';
import '../overview/overview_screen.dart';

/// Transparência: fontes, regras, métricas do modelo, vieses e limites.
class MethodologyScreen extends StatelessWidget {
  const MethodologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Metodologia e limitações')),
      body: ContentConstraint(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
          children: [
            const SectionHeader('Fontes de dados'),
            const _Paragraphs([
              'Clima (temperatura máxima e chuva): API pública Open-Meteo, 30 dias de histórico '
                  'e 7 de previsão do modelo meteorológico, por coordenada de cada subprefeitura.',
              'Qualidade do ar (PM2,5): Open-Meteo Air Quality (modelo CAMS/Copernicus), média diária '
                  'calculada no app a partir de valores horários (mínimo de 12 h válidas).',
              'Água, energia, coleta de resíduos e UBS: séries sintéticas determinísticas, calibradas '
                  'por habitante, com sazonalidade semanal, ruído e eventos simulados. Não existem APIs '
                  'abertas diárias desses dados por subprefeitura; a simulação demonstra o método e é '
                  'sempre identificada como tal.',
            ]),
            const SectionHeader('Como os alertas são gerados'),
            const _RuleTable(),
            const SectionHeader('Nota de confiança'),
            const _Paragraphs([
              'Média ponderada de quatro fatores, todos exibidos no detalhe do alerta: força/precisão '
                  'do sinal (40%), volume de histórico (20%), atualidade dos dados (25%) e origem real '
                  'ou simulada (15%).',
              'Alta ≥ 75% · Média ≥ 50% · Baixa < 50%. Alertas com confiança baixa são marcados como '
                  '"não confiáveis para decisão".',
            ]),
            SectionHeader('Métricas do modelo (backtest)', subtitle: Forecaster.methodName),
            const _BacktestTable(),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Backtest: o modelo é treinado sem os últimos 7 dias e prevê esses dias "às cegas". '
                'WAPE = soma dos erros absolutos ÷ soma dos valores reais (não distorce em dias de valor baixo, '
                'como domingo nas UBS). Valores altos indicam que a última semana fugiu '
                'do padrão (é justamente onde há anomalias).',
                style: t.bodySmall,
              ),
            ),
            const SectionHeader('Quando as previsões NÃO são confiáveis'),
            const _Paragraphs([
              'Eventos súbitos que o histórico não contém: rompimento de adutora, greves, feriados '
                  'prolongados, grandes eventos.',
              'Previsão do tempo além de 3 dias e chuvas convectivas localizadas (temporais de verão).',
              'Dados vindos do cache há mais de 24 h ou com menos de 28 dias de histórico.',
              'Mudanças estruturais recentes (novo conjunto habitacional, nova UBS) que alteram a linha de base.',
            ]),
            const SectionHeader('Possíveis vieses'),
            const _Paragraphs([
              'Relatos cidadãos dependem de acesso digital: regiões com menos acesso tendem a relatar '
                  'menos. Por isso relatos entram apenas como evidência complementar e NÃO alteram a '
                  'nota de confiança.',
              'Modelos atmosféricos têm resolução de quilômetros: favelas e áreas sem arborização '
                  '(ilhas de calor) podem estar mais quentes do que o previsto.',
              'Limiares iguais para todas as regiões podem subestimar vulnerabilidades locais '
                  '(população idosa, áreas de risco).',
            ]),
            const SectionHeader('Benefício social'),
            SocialImpactCard(impact: context.watch<AlertsProvider>().impact),
            const SectionHeader('Privacidade e inclusão'),
            const _Paragraphs([
              'Sem cadastro, sem nome, sem GPS. Ocorrências guardam só a região e passam por '
                  'anonimização automática (e-mail, telefone, CPF, CEP, número do endereço).',
              'Consentimento explícito na primeira abertura; revogação apaga todos os dados locais.',
              'Acessibilidade: rótulos para leitor de tela em cards, gráficos (com resumo textual) e '
                  'botões; tema escuro e alto contraste; fonte ajustável até 200%; mapa com lista equivalente.',
            ]),
          ],
        ),
      ),
    );
  }
}

class _Paragraphs extends StatelessWidget {
  const _Paragraphs(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(child: Text('•  ')),
                  Expanded(child: Text(p)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RuleTable extends StatelessWidget {
  const _RuleTable();

  @override
  Widget build(BuildContext context) {
    const rules = [
      ('Onda de calor', 'Previsão com N dias seguidos ≥ limiar de temperatura (ou 1 dia ≥ limiar + 2 °C).'),
      ('Chuva forte', 'Dia previsto ≥ limiar em mm ou acumulado de 3 dias ≥ 2× o limiar.'),
      ('Qualidade do ar', 'PM2,5 observado ou previsto (3 dias) ≥ limiar.'),
      ('Anomalia', 'Média dos últimos 3 dias desvia ≥ z desvios-padrão da linha de base de 28 dias, '
          'descontado o padrão semanal.'),
      ('Alta/queda prevista', 'Média prevista de 7 dias varia mais que o limiar % em relação às 4 '
          'semanas anteriores.'),
      ('Gravidade', 'Crítico quando o excesso é cerca de 2× o limiar (ou z ≥ limiar + 1,5).'),
    ];
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        children: [
          for (final (name, rule) in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 120, child: Text(name, style: t.titleSmall)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(rule, style: t.bodyMedium)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BacktestTable extends StatelessWidget {
  const _BacktestTable();

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final ids = IndicatorId.values.where((i) => i.origin == DataOrigin.synthetic).toList();
    final t = Theme.of(context).textTheme;
    if (!territory.hasData) return const AppCard(child: Text('Carregue os dados para ver as métricas.'));
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: t.labelLarge,
          columnSpacing: AppSpacing.md,
          columns: [
            const DataColumn(label: Text('Região')),
            for (final i in ids) DataColumn(label: Text(i.shortName), numeric: true),
          ],
          rows: [
            for (final r in Territory.regions)
              DataRow(cells: [
                DataCell(Text(r.name)),
                for (final i in ids)
                  DataCell(Text(() {
                    final f = territory.forecast(r.id, i);
                    return f == null ? '—' : Fmt.percent(f.backtestWape, decimals: 1);
                  }())),
              ]),
          ],
        ),
      ),
    );
  }
}
