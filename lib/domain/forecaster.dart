import 'dart:math' as math;

import '../data/models/time_series.dart';
import 'statistics.dart';

/// Previsão de um dia, com intervalo de 95%.
class ForecastPoint {
  const ForecastPoint({
    required this.date,
    required this.value,
    required this.lower,
    required this.upper,
  });

  final DateTime date;
  final double value;
  final double lower;
  final double upper;
}

/// Resultado do modelo para um indicador, incluindo métricas de validação.
class ForecastResult {
  const ForecastResult({
    required this.points,
    required this.trendPerDay,
    required this.trendSignificant,
    required this.r2,
    required this.residualStd,
    required this.trainingDays,
    required this.backtestMae,
    required this.backtestWape,
    required this.method,
  });

  final List<ForecastPoint> points;

  /// Inclinação estimada (unidade do indicador por dia).
  final double trendPerDay;

  /// Se a inclinação passou no teste |b| > 2·erro-padrão. Quando não passa,
  /// a previsão usa só o nível recente + padrão semanal (sem extrapolar
  /// ruído como se fosse tendência).
  final bool trendSignificant;

  /// Coeficiente de determinação do ajuste (tendência + dia da semana).
  final double r2;
  final double residualStd;
  final int trainingDays;

  /// Erro absoluto médio prevendo os últimos 7 dias "às cegas".
  final double backtestMae;

  /// WAPE do backtest (0–1): Σ|erro| / Σ|real|. Preferido ao MAPE porque
  /// não explode em dias de valor baixo (ex.: UBS no domingo).
  final double backtestWape;
  final String method;

  double get meanForecast =>
      points.isEmpty ? double.nan : Stats.mean(points.map((p) => p.value).toList());
}

/// Modelo de previsão leve e explicável:
/// nível + tendência linear amortecida (só quando significativa) + efeito
/// do dia da semana, com intervalo de predição a partir dos resíduos.
/// Escolhido no lugar de um modelo "caixa-preta" para que o gestor consiga
/// entender e auditar o que gerou cada alerta.
class Forecaster {
  const Forecaster({this.trainingWindow = 28, this.horizon = 7, this.damping = 0.85});

  final int trainingWindow;
  final int horizon;

  /// Fator de amortecimento da tendência (damped trend, Gardner & McKenzie).
  final double damping;

  static const String methodName =
      'Nível + tendência amortecida (se significativa) + padrão semanal · janela de 28 dias';

  ForecastResult? forecast(List<DataPoint> history) {
    if (history.length < 10) return null;

    final backtest = _backtest(history);
    final model = _fit(history);
    final last = history.last.date;
    final points = <ForecastPoint>[];
    for (var h = 1; h <= horizon; h++) {
      final date = DateTime(last.year, last.month, last.day + h);
      final value = model.predict(h, date);
      final margin = 1.96 * model.residualStd * math.sqrt(1 + 1 / model.n + 0.08 * h);
      points.add(ForecastPoint(
        date: date,
        value: math.max(0, value),
        lower: math.max(0, value - margin),
        upper: value + margin,
      ));
    }

    return ForecastResult(
      points: points,
      trendPerDay: model.slope,
      trendSignificant: model.trendSignificant,
      r2: model.r2,
      residualStd: model.residualStd,
      trainingDays: model.n,
      backtestMae: backtest.$1,
      backtestWape: backtest.$2,
      method: methodName,
    );
  }

  /// Regressão por mínimos quadrados com tendência + um intercepto por dia
  /// da semana (estimador "within"). Estimar tendência e sazonalidade
  /// juntas evita o viés que surge quando a janela começa no meio da semana.
  _Model _fit(List<DataPoint> history) {
    final window = history.length > trainingWindow
        ? history.sublist(history.length - trainingWindow)
        : history;
    final n = window.length;
    final ys = window.map((p) => p.value).toList();
    final wd = window.map((p) => p.date.weekday).toList();

    final xs = <int, List<int>>{};
    final yv = <int, List<double>>{};
    for (var i = 0; i < n; i++) {
      xs.putIfAbsent(wd[i], () => []).add(i);
      yv.putIfAbsent(wd[i], () => []).add(ys[i]);
    }
    final mx = {for (final d in xs.keys) d: Stats.mean(xs[d]!.map((e) => e.toDouble()).toList())};
    final my = {for (final d in yv.keys) d: Stats.mean(yv[d]!)};

    double sxy = 0, sxx = 0;
    for (var i = 0; i < n; i++) {
      final dx = i - mx[wd[i]]!;
      sxy += dx * (ys[i] - my[wd[i]]!);
      sxx += dx * dx;
    }
    final slope = sxx == 0 ? 0.0 : sxy / sxx;
    final intercept = {for (final d in my.keys) d: my[d]! - slope * mx[d]!};

    double predictAt(int i) => intercept[wd[i]]! + slope * i;
    final residuals = [for (var i = 0; i < n; i++) ys[i] - predictAt(i)];
    // Graus de liberdade: n − (7 interceptos + 1 inclinação).
    final dof = math.max(1, n - intercept.length - 1);
    final residualStd = math.sqrt(residuals.fold<double>(0, (a, e) => a + e * e) / dof);
    final yMean = Stats.mean(ys);
    final sst = ys.fold<double>(0, (a, y) => a + (y - yMean) * (y - yMean));
    final sse = residuals.fold<double>(0, (a, e) => a + e * e);
    final r2 = sst == 0 ? 0.0 : (1 - sse / sst).clamp(0.0, 1.0);

    // Teste de significância da inclinação: |b| > 2·EP(b).
    final slopeSe = sxx == 0 ? double.infinity : residualStd / math.sqrt(sxx);
    final significant = slope.abs() > 2 * slopeSe;

    // Sem tendência significativa, cada dia da semana fica na sua média.
    final base = <int, double>{
      for (final d in intercept.keys)
        d: significant ? intercept[d]! + slope * (n - 1) : my[d]!,
    };
    return _Model(
      slope: slope,
      r2: r2,
      n: n,
      baseByWeekday: base,
      fallback: yMean,
      residualStd: residualStd,
      trendSignificant: significant,
      damping: damping,
    );
  }

  /// Treina sem os últimos [horizon] dias e mede o erro neles.
  (double, double) _backtest(List<DataPoint> history) {
    if (history.length < horizon + 10) return (double.nan, double.nan);
    final train = history.sublist(0, history.length - horizon);
    final test = history.sublist(history.length - horizon);
    final model = _fit(train);
    final predicted = <double>[
      for (var h = 1; h <= horizon; h++) model.predict(h, test[h - 1].date),
    ];
    final actual = test.map((p) => p.value).toList();
    return (Stats.mae(actual, predicted), Stats.wape(actual, predicted));
  }
}

class _Model {
  const _Model({
    required this.slope,
    required this.r2,
    required this.n,
    required this.baseByWeekday,
    required this.fallback,
    required this.residualStd,
    required this.trendSignificant,
    required this.damping,
  });

  final double slope;
  final double r2;
  final int n;

  /// Valor de cada dia da semana no fim da janela de treino.
  final Map<int, double> baseByWeekday;
  final double fallback;
  final double residualStd;
  final bool trendSignificant;
  final double damping;

  /// Valor previsto [h] dias à frente, para a data [date]
  /// (tendência amortecida: b·(φ + φ² + … + φʰ)).
  double predict(int h, DateTime date) {
    var trend = 0.0;
    if (trendSignificant) {
      var phi = damping;
      for (var k = 1; k <= h; k++) {
        trend += slope * phi;
        phi *= damping;
      }
    }
    return (baseByWeekday[date.weekday] ?? fallback) + trend;
  }
}
