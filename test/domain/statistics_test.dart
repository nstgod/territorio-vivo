import 'package:flutter_test/flutter_test.dart';
import 'package:territorio_vivo/data/models/time_series.dart';
import 'package:territorio_vivo/domain/forecaster.dart';
import 'package:territorio_vivo/domain/statistics.dart';

void main() {
  group('Stats', () {
    test('média e desvio-padrão amostral', () {
      expect(Stats.mean([2, 4, 6]), 4);
      expect(Stats.stdDev([2, 4, 4, 4, 5, 5, 7, 9]), closeTo(2.138, 0.001));
    });

    test('regressão linear recupera inclinação e R²', () {
      final fit = Stats.linearFit([for (var i = 0; i < 20; i++) 3 + 2.0 * i]);
      expect(fit.slope, closeTo(2, 1e-9));
      expect(fit.intercept, closeTo(3, 1e-9));
      expect(fit.r2, closeTo(1, 1e-9));
    });

    test('MAE e WAPE', () {
      expect(Stats.mae([10, 20], [12, 18]), 2);
      expect(Stats.wape([10, 20], [11, 18]), closeTo(0.1, 1e-9));
    });
  });

  group('Forecaster', () {
    final start = DateTime(2026, 9, 1);

    test('captura tendência e sazonalidade semanal com erro baixo', () {
      final history = [
        for (var i = 0; i < 60; i++)
          DataPoint(
            start.add(Duration(days: i)),
            100 + 0.5 * i + (start.add(Duration(days: i)).weekday >= 6 ? 8 : 0),
          ),
      ];
      final r = const Forecaster().forecast(history)!;
      expect(r.points, hasLength(7));
      expect(r.trendPerDay, closeTo(0.5, 0.15));
      expect(r.trendSignificant, isTrue);
      expect(r.backtestWape, lessThan(0.02));
      for (final p in r.points) {
        expect(p.lower, lessThanOrEqualTo(p.value));
        expect(p.upper, greaterThanOrEqualTo(p.value));
      }
    });

    test('histórico curto não gera previsão', () {
      final history = [for (var i = 0; i < 5; i++) DataPoint(start.add(Duration(days: i)), 1.0)];
      expect(const Forecaster().forecast(history), isNull);
    });
  });
}
