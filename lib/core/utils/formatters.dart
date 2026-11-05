import 'package:intl/intl.dart';

/// Formatação pt-BR sem depender de dados de locale carregados em tempo de
/// execução (funciona igual no app, nos testes e offline).
abstract final class Fmt {
  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  static const _months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  static String number(double value, {int decimals = 1}) {
    if (value.isNaN || value.isInfinite) return '—';
    final f = NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: decimals);
    return f.format(value);
  }

  static String withUnit(double value, String unit, {int decimals = 1}) =>
      '${number(value, decimals: decimals)} $unit';

  static String percent(double ratio, {int decimals = 0, bool signed = false}) {
    if (ratio.isNaN) return '—';
    final s = number(ratio * 100, decimals: decimals);
    return signed && ratio > 0 ? '+$s%' : '$s%';
  }

  static String integer(num value) =>
      NumberFormat.decimalPattern('pt_BR').format(value.round());

  static String two(int v) => v.toString().padLeft(2, '0');

  /// 05/11
  static String dayMonth(DateTime d) => '${two(d.day)}/${two(d.month)}';

  /// qui, 05/11
  static String weekdayDayMonth(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${dayMonth(d)}';

  /// 5 nov 2026
  static String longDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// 05/11 14:32
  static String dateTime(DateTime d) =>
      '${dayMonth(d)} ${two(d.hour)}:${two(d.minute)}';

  static String ymd(DateTime d) => '${d.year}${two(d.month)}${two(d.day)}';

  /// "há 3 h", "há 2 dias"…
  static String relative(DateTime from, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(from);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    final days = diff.inDays;
    return days == 1 ? 'há 1 dia' : 'há $days dias';
  }
}
