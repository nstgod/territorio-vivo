import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/utils/formatters.dart';
import '../data/models/alert.dart';
import '../data/models/region.dart';

/// Explicação de um alerta em linguagem simples para o cidadão.
class AlertExplanation {
  const AlertExplanation({required this.text, required this.generatedByAi});

  final String text;

  /// Verdadeiro quando veio do LLM (o app exibe o aviso "gerado por IA").
  final bool generatedByAi;
}

/// Gera a explicação via Claude (IA generativa) quando há chave configurada
/// por `--dart-define=ANTHROPIC_API_KEY=...` (nunca versionada). Sem chave,
/// sem conexão ou em caso de falha, usa um modelo de texto local — o app
/// nunca depende do LLM para funcionar.
///
/// Só dados agregados e não pessoais do alerta são enviados.
class ExplanationService {
  ExplanationService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? const String.fromEnvironment('ANTHROPIC_API_KEY');

  final http.Client _client;
  final String _apiKey;

  static const _model = 'claude-opus-5-5';
  final _cache = <String, AlertExplanation>{};

  bool get aiEnabled => _apiKey.isNotEmpty;

  Future<AlertExplanation> explain(TerritoryAlert alert, {bool offline = false}) async {
    final cached = _cache[alert.id];
    if (cached != null) return cached;
    AlertExplanation result = localExplanation(alert);
    if (aiEnabled && !offline) {
      try {
        final text = await _askClaude(alert);
        if (text != null && text.trim().isNotEmpty) {
          result = AlertExplanation(text: text.trim(), generatedByAi: true);
        }
      } catch (e) {
        debugPrint('Explicação por IA indisponível, usando texto local: $e');
      }
    }
    return _cache[alert.id] = result;
  }

  Future<String?> _askClaude(TerritoryAlert alert) async {
    final region = Territory.byId(alert.regionId).name;
    final prompt = StringBuffer()
      ..writeln('Alerta: ${alert.title}')
      ..writeln('Região: $region (Zona Leste de São Paulo)')
      ..writeln('Gravidade: ${alert.severity.label}')
      ..writeln('Confiança do modelo: ${alert.confidence.level.label} '
          '(${Fmt.percent(alert.confidence.score)})')
      ..writeln('Resumo técnico: ${alert.summary}')
      ..writeln('Evidências:')
      ..writeAll(alert.evidence.map((e) => '- $e\n'))
      ..writeln('Limitações:')
      ..writeAll(alert.limitations.map((e) => '- $e\n'));

    final res = await _client
        .post(
          Uri.https('api.anthropic.com', '/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': _apiKey,
            'anthropic-version': '2026-10-21',
            'anthropic-beta': 'server-side-fallback-2026-07-01',
            // Necessário apenas quando o app roda no navegador (Flutter web).
            if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': 2000,
            'output_config': {'effort': 'low'},
            'fallbacks': 'default',
            'system':
                'Você explica alertas de um painel de inteligência territorial para '
                'moradores, em português do Brasil, com linguagem simples (nível '
                'ensino fundamental). Escreva no máximo 4 frases curtas: o que pode '
                'acontecer, por que o sistema acha isso (cite 1 número da evidência), '
                'quão certo ele está e um cuidado prático para a pessoa. Deixe claro '
                'que é uma previsão que a prefeitura vai analisar, não uma ordem. '
                'Não invente dados além dos fornecidos. Sem markdown.',
            'messages': [
              {'role': 'user', 'content': prompt.toString()},
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (json['stop_reason'] == 'refusal') return null;
    final blocks = (json['content'] as List).cast<Map<String, dynamic>>();
    return blocks
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n');
  }

  /// Explicação montada localmente a partir dos campos do alerta.
  static AlertExplanation localExplanation(TerritoryAlert alert) {
    final region = Territory.byId(alert.regionId).name;
    final certainty = switch (alert.confidence.level) {
      ConfidenceLevel.high => 'O sistema está bastante seguro dessa previsão',
      ConfidenceLevel.medium => 'O sistema tem uma segurança moderada nessa previsão',
      ConfidenceLevel.low => 'O sistema ainda tem pouca segurança nessa previsão',
    };
    final firstEvidence = alert.evidence.isEmpty ? '' : ' ${alert.evidence.first}';
    final text = 'Em $region: ${alert.title.toLowerCase()}.$firstEvidence '
        '$certainty (${Fmt.percent(alert.confidence.score)}). '
        'Isto é um aviso para a prefeitura analisar — não é uma ordem nem uma '
        'decisão. Se você perceber o problema na sua rua, registre uma ocorrência no app.';
    return AlertExplanation(text: text, generatedByAi: false);
  }
}
