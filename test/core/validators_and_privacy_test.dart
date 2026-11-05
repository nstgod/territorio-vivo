import 'package:flutter_test/flutter_test.dart';
import 'package:territorio_vivo/core/utils/anonymizer.dart';
import 'package:territorio_vivo/core/utils/validators.dart';
import 'package:territorio_vivo/data/models/alert_thresholds.dart';

void main() {
  group('Validators', () {
    final now = DateTime(2026, 11, 5);

    test('descrição: vazia, curta, só números e válida', () {
      expect(Validators.description(''), isNotNull);
      expect(Validators.description('vazou'), contains('pelo menos 15'));
      expect(Validators.description('1234567890123456'), isNotNull);
      expect(Validators.description('Água vazando na calçada desde ontem'), isNull);
    });

    test('data: futuro, muito antiga e válida', () {
      expect(Validators.occurrenceDate(null, now: now), isNotNull);
      expect(Validators.occurrenceDate(DateTime(2026, 11, 6), now: now), contains('futuro'));
      expect(Validators.occurrenceDate(DateTime(2026, 9, 1), now: now), contains('30 dias'));
      expect(Validators.occurrenceDate(DateTime(2026, 11, 1), now: now), isNull);
    });

    test('decimal aceita vírgula e respeita a faixa', () {
      expect(Validators.decimalInRange('2,5', min: 1.5, max: 5), isNull);
      expect(Validators.decimalInRange('abc', min: 0, max: 10), contains('números'));
      expect(Validators.decimalInRange('60', min: 25, max: 45, unit: '°C'), contains('entre 25 °C e 45 °C'));
    });

    test('justificativa da decisão é obrigatória', () {
      expect(Validators.decisionNote('ok'), isNotNull);
      expect(Validators.decisionNote('Vistoria solicitada à Sabesp'), isNull);
    });
  });

  group('Anonymizer', () {
    test('remove e-mail, telefone e CPF', () {
      final r = Anonymizer.anonymize(
        'Falar com joao.silva@email.com ou (11) 98765-4321, CPF 123.456.789-09.',
      );
      expect(r.text, isNot(contains('joao')));
      expect(r.text, isNot(contains('98765')));
      expect(r.text, isNot(contains('123.456')));
      expect(r.removed, containsAll(['e-mail', 'telefone', 'CPF']));
    });

    test('mantém o nome da rua e remove o número', () {
      final r = Anonymizer.anonymize('Vazamento na Rua das Flores, 123 perto da escola');
      expect(r.text, contains('Rua das Flores'));
      expect(r.text, isNot(contains('123')));
    });

    test('texto sem dados pessoais não é alterado', () {
      const text = 'Lixo acumulado na praça há três dias';
      final r = Anonymizer.anonymize(text);
      expect(r.text, text);
      expect(r.changed, isFalse);
    });

    test('token aleatório tem 12 caracteres', () {
      expect(Anonymizer.randomToken(), hasLength(12));
    });
  });

  test('limiares sobrevivem à serialização (persistência)', () {
    final t = AlertThresholds.defaults.copyWith(heatMaxTemp: 31.5, heatConsecutiveDays: 2);
    expect(AlertThresholds.fromJson(t.toJson()), t);
  });
}
