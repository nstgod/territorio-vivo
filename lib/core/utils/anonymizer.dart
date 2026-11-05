import 'dart:math' as math;

/// Resultado da anonimização de um texto livre.
class AnonymizedText {
  const AnonymizedText(this.text, this.removed);

  final String text;

  /// Tipos de dado pessoal encontrados e removidos.
  final List<String> removed;

  bool get changed => removed.isNotEmpty;
}

/// Remove dados pessoais de relatos livres antes de salvá-los (LGPD:
/// minimização). Cobre os padrões mais comuns em relatos de cidadãos.
abstract final class Anonymizer {
  static final _rules = <(String, RegExp, String)>[
    ('e-mail', RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '[e-mail removido]'),
    ('CPF', RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b'), '[CPF removido]'),
    ('CEP', RegExp(r'\b\d{5}-\d{3}\b'), '[CEP removido]'),
    (
      'telefone',
      RegExp(r'(\+?55\s?)?(\(?\d{2}\)?\s?)?9?\d{4}[-\s]?\d{4}\b'),
      '[telefone removido]',
    ),
    (
      'número de endereço',
      RegExp(
        r'\b(rua|r\.|avenida|av\.|travessa|tv\.|alameda|estrada)\s+([^\d,\n]{2,40}?)[,\s]+(n[º°o.]?\s*)?\d{1,5}\b',
        caseSensitive: false,
      ),
      r'$1 $2',
    ),
  ];

  static AnonymizedText anonymize(String input) {
    var text = input;
    final removed = <String>[];
    for (final (label, pattern, replacement) in _rules) {
      if (pattern.hasMatch(text)) {
        removed.add(label);
        text = text.replaceAllMapped(pattern, (m) {
          // Suporta $1/$2 na substituição (mantém o nome da rua, tira o número).
          return replacement.replaceAllMapped(
            RegExp(r'\$(\d)'),
            (g) => m.group(int.parse(g.group(1)!)) ?? '',
          );
        });
      }
    }
    return AnonymizedText(text.replaceAll(RegExp(r'\s{2,}'), ' ').trim(), removed);
  }

  /// Token aleatório (não derivado de nenhum dado da pessoa).
  static String randomToken([math.Random? random]) {
    final r = random ?? math.Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
