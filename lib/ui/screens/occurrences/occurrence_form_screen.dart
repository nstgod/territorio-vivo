import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/anonymizer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/occurrence.dart';
import '../../../data/models/region.dart';
import '../../../state/occurrences_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/common.dart';

/// Formulário de registro de ocorrência pelo cidadão, com validação,
/// mensagens de erro claras e anonimização antes de salvar.
class OccurrenceFormScreen extends StatefulWidget {
  const OccurrenceFormScreen({super.key, required this.args});

  final OccurrenceFormArgs args;

  @override
  State<OccurrenceFormScreen> createState() => _OccurrenceFormScreenState();
}

class _OccurrenceFormScreenState extends State<OccurrenceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _dateField = TextEditingController();
  late OccurrenceCategory? _category = widget.args.category;
  late String? _regionId = widget.args.regionId ?? context.read<TerritoryProvider>().selectedRegionId;
  DateTime? _date = DateTime.now();
  int _severity = 3;
  bool _declaration = false;
  bool _saving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  List<String> _piiPreview = const [];

  @override
  void initState() {
    super.initState();
    _dateField.text = Fmt.weekdayDayMonth(_date!);
    _description.addListener(_checkPii);
  }

  @override
  void dispose() {
    _description.dispose();
    _dateField.dispose();
    super.dispose();
  }

  void _checkPii() {
    final found = Anonymizer.anonymize(_description.text).removed;
    if (found.join() != _piiPreview.join()) setState(() => _piiPreview = found);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: 'Quando aconteceu?',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateField.text = Fmt.weekdayDayMonth(picked);
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise os campos destacados em vermelho.')),
      );
      return;
    }
    setState(() => _saving = true);
    final saved = await context.read<OccurrencesProvider>().add(
          category: _category!,
          regionId: _regionId!,
          description: _description.text,
          severity: _severity,
          occurredOn: _date!,
          reporterToken: context.read<SettingsProvider>().reporterToken,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    final removed = saved.redactedItems;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(removed.isEmpty
            ? 'Ocorrência registrada de forma anônima. Obrigado!'
            : 'Ocorrência registrada. Removemos: ${removed.join(', ')}.'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar ocorrência')),
      body: ContentConstraint(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const InfoBanner(
                icon: Icons.privacy_tip_outlined,
                message: 'Não pedimos nome, telefone nem localização exata. Evite citar '
                    'pessoas; dados pessoais digitados serão removidos automaticamente.',
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<OccurrenceCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de problema *'),
                items: [
                  for (final c in OccurrenceCategory.values)
                    DropdownMenuItem(
                      value: c,
                      child: Row(children: [
                        Icon(c.icon, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(child: Text(c.label)),
                      ]),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => Validators.required(v, field: 'O tipo de problema'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _regionId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Região *',
                  prefixIcon: Icon(Icons.place_outlined),
                  helperText: 'Só a região é salva — nunca o endereço.',
                ),
                items: [
                  for (final r in Territory.regions) DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() => _regionId = v),
                validator: (v) => Validators.required(v, field: 'A região'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _dateField,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Quando aconteceu? *',
                  prefixIcon: Icon(Icons.event_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                validator: (_) => Validators.occurrenceDate(_date),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _description,
                maxLines: 5,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descreva o problema *',
                  hintText: 'Ex.: água jorrando da calçada há dois dias perto da praça.',
                  alignLabelWithHint: true,
                ),
                validator: Validators.description,
              ),
              if (_piiPreview.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Detectamos ${_piiPreview.join(', ')} no texto: será removido ao salvar.',
                            style: t.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Text('Gravidade percebida: $_severity de 5', style: t.titleSmall),
              Slider(
                value: _severity.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$_severity',
                semanticFormatterCallback: (v) => 'Gravidade ${v.round()} de 5',
                onChanged: (v) => setState(() => _severity = v.round()),
              ),
              FormField<bool>(
                initialValue: _declaration,
                validator: (_) => _declaration
                    ? null
                    : 'Confirme a declaração para enviar.',
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: _declaration,
                      isError: field.hasError,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Declaro que o relato é verdadeiro e não inclui dados pessoais de terceiros.',
                      ),
                      onChanged: (v) {
                        setState(() => _declaration = v ?? false);
                        field.didChange(v);
                      },
                    ),
                    if (field.hasError)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.md),
                        child: Text(field.errorText!, style: t.bodySmall?.copyWith(color: scheme.error)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Enviar ocorrência'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
