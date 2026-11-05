/// Validadores dos formulários. Retornam a mensagem de erro (pt-BR) ou
/// `null` quando o valor é válido — contrato do `TextFormField.validator`.
abstract final class Validators {
  static String? required(Object? value, {String field = 'Este campo'}) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return '$field é obrigatório.';
    }
    return null;
  }

  static String? description(String? value, {int min = 15, int max = 500}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Descreva o que está acontecendo.';
    if (text.length < min) {
      return 'Descreva com pelo menos $min caracteres (faltam ${min - text.length}).';
    }
    if (text.length > max) return 'Use no máximo $max caracteres.';
    if (!RegExp(r'[A-Za-zÀ-ÿ]{3,}').hasMatch(text)) {
      return 'Use palavras para descrever o problema.';
    }
    return null;
  }

  static String? occurrenceDate(DateTime? value, {DateTime? now}) {
    if (value == null) return 'Informe quando aconteceu.';
    final today = _day(now ?? DateTime.now());
    final day = _day(value);
    if (day.isAfter(today)) return 'A data não pode estar no futuro.';
    if (today.difference(day).inDays > 30) {
      return 'Registre ocorrências dos últimos 30 dias.';
    }
    return null;
  }

  /// Número decimal (aceita vírgula) dentro de [min, max].
  static String? decimalInRange(
    String? value, {
    required double min,
    required double max,
    String unit = '',
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe um valor.';
    final parsed = parseDecimal(text);
    if (parsed == null) return 'Use apenas números (ex.: 32 ou 2,5).';
    final u = unit.isEmpty ? '' : ' $unit';
    if (parsed < min || parsed > max) {
      return 'Use um valor entre ${_fmt(min)}$u e ${_fmt(max)}$u.';
    }
    return null;
  }

  static String? integerInRange(String? value, {required int min, required int max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe um valor.';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Use um número inteiro.';
    if (parsed < min || parsed > max) return 'Use um valor entre $min e $max.';
    return null;
  }

  static String? decisionNote(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 10) {
      return 'Justifique a decisão (mín. 10 caracteres) — ela fica registrada para auditoria.';
    }
    if (text.length > 300) return 'Use no máximo 300 caracteres.';
    return null;
  }

  static double? parseDecimal(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
