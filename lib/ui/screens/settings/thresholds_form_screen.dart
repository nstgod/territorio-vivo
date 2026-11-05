import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/alert_thresholds.dart';
import '../../../state/settings_provider.dart';
import '../../widgets/common.dart';

/// Formulário de configuração dos limiares de alerta (persistido).
class ThresholdsFormScreen extends StatefulWidget {
  const ThresholdsFormScreen({super.key});

  @override
  State<ThresholdsFormScreen> createState() => _ThresholdsFormScreenState();
}

class _ThresholdsFormScreenState extends State<ThresholdsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late double _notifyMin;

  static const _specs = <_FieldSpec>[
    _FieldSpec('heatMaxTemp', 'Calor: temperatura máxima', '°C', 25, 45,
        'Dia com máxima acima disto conta para onda de calor.'),
    _FieldSpec('heatConsecutiveDays', 'Calor: dias seguidos', 'dias', 1, 7,
        'Quantos dias seguidos caracterizam onda de calor.', integer: true),
    _FieldSpec('rainDailyMm', 'Chuva diária (alagamento)', 'mm', 5, 150,
        'Defesa Civil costuma usar 30 a 50 mm/dia como atenção.'),
    _FieldSpec('pm25', 'PM2,5 médio diário', 'µg/m³', 5, 150,
        'OMS 2021 recomenda até 15 µg/m³ em 24 h.'),
    _FieldSpec('anomalyZScore', 'Anomalia: desvios-padrão', 'z', 1.5, 5,
        'Menor = mais sensível (mais falsos alarmes).'),
    _FieldSpec('waterRisePct', 'Água: alta prevista', '%', 2, 50, 'Média prevista de 7 dias vs. linha de base.'),
    _FieldSpec('energyRisePct', 'Energia: alta prevista', '%', 2, 50, 'Média prevista de 7 dias vs. linha de base.'),
    _FieldSpec('healthRisePct', 'UBS: alta prevista', '%', 2, 50, 'Aumento de demanda que pede planejamento.'),
    _FieldSpec('wasteDropPct', 'Resíduos: queda prevista', '%', 2, 50, 'Queda na coleta que indica falha de serviço.'),
  ];

  @override
  void initState() {
    super.initState();
    _fill(context.read<SettingsProvider>().thresholds);
  }

  void _fill(AlertThresholds t) {
    final json = t.toJson();
    _c = {
      for (final s in _specs)
        s.key: TextEditingController(
          text: s.integer
              ? '${json[s.key]}'
              : Fmt.number((json[s.key] as num).toDouble(), decimals: s.key == 'anomalyZScore' ? 1 : 0),
        ),
    };
    _notifyMin = t.notifyMinConfidence;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _restoreDefaults() {
    const d = AlertThresholds.defaults;
    final json = d.toJson();
    setState(() {
      for (final s in _specs) {
        _c[s.key]!.text = s.integer
            ? '${json[s.key]}'
            : Fmt.number((json[s.key] as num).toDouble(), decimals: s.key == 'anomalyZScore' ? 1 : 0);
      }
      _notifyMin = d.notifyMinConfidence;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    double v(String k) => Validators.parseDecimal(_c[k]!.text)!;
    final value = AlertThresholds(
      heatMaxTemp: v('heatMaxTemp'),
      heatConsecutiveDays: int.parse(_c['heatConsecutiveDays']!.text.trim()),
      rainDailyMm: v('rainDailyMm'),
      pm25: v('pm25'),
      anomalyZScore: v('anomalyZScore'),
      waterRisePct: v('waterRisePct'),
      energyRisePct: v('energyRisePct'),
      healthRisePct: v('healthRisePct'),
      wasteDropPct: v('wasteDropPct'),
      notifyMinConfidence: _notifyMin,
    );
    await context.read<SettingsProvider>().saveThresholds(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Limiares salvos. Os alertas foram recalculados.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Limiares de alerta'),
        actions: [
          TextButton(onPressed: _restoreDefaults, child: const Text('Padrões')),
        ],
      ),
      body: ContentConstraint(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const InfoBanner(
                icon: Icons.balance_outlined,
                message: 'Limiares mais baixos geram mais alertas (e mais falsos alarmes). '
                    'Ajuste com a equipe técnica — os alertas continuam exigindo análise humana.',
              ),
              const SizedBox(height: AppSpacing.md),
              for (final s in _specs) ...[
                TextFormField(
                  controller: _c[s.key],
                  keyboardType: TextInputType.numberWithOptions(decimal: !s.integer),
                  decoration: InputDecoration(
                    labelText: s.label,
                    suffixText: s.unit,
                    helperText: '${s.help} (${Fmt.number(s.min, decimals: s.min % 1 == 0 ? 0 : 1)}–${Fmt.number(s.max, decimals: 0)})',
                  ),
                  validator: (v) => s.integer
                      ? Validators.integerInRange(v, min: s.min.toInt(), max: s.max.toInt())
                      : Validators.decimalInRange(v, min: s.min, max: s.max, unit: s.unit),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text('Notificar só com confiança ≥ ${Fmt.percent(_notifyMin)}', style: t.titleSmall),
              Slider(
                value: _notifyMin,
                min: 0.3,
                max: 0.95,
                divisions: 13,
                label: Fmt.percent(_notifyMin),
                semanticFormatterCallback: (v) => 'Confiança mínima ${Fmt.percent(v)}',
                onChanged: (v) => setState(() => _notifyMin = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar limiares'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldSpec {
  const _FieldSpec(this.key, this.label, this.unit, this.min, this.max, this.help, {this.integer = false});

  final String key;
  final String label;
  final String unit;
  final double min;
  final double max;
  final String help;
  final bool integer;
}
