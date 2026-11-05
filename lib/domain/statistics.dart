import 'dart:math' as math;

/// Funções estatísticas puras usadas pelo motor de alertas.
abstract final class Stats {
  static double mean(List<double> xs) {
    if (xs.isEmpty) return double.nan;
    return xs.reduce((a, b) => a + b) / xs.length;
  }

  /// Desvio-padrão amostral (n - 1).
  static double stdDev(List<double> xs) {
    if (xs.length < 2) return 0;
    final m = mean(xs);
    final ss = xs.fold<double>(0, (acc, x) => acc + (x - m) * (x - m));
    return math.sqrt(ss / (xs.length - 1));
  }

  /// Erro absoluto médio.
  static double mae(List<double> actual, List<double> predicted) {
    final n = math.min(actual.length, predicted.length);
    if (n == 0) return double.nan;
    double s = 0;
    for (var i = 0; i < n; i++) {
      s += (actual[i] - predicted[i]).abs();
    }
    return s / n;
  }

  /// Erro percentual absoluto ponderado (0–1): Σ|real − previsto| / Σ|real|.
  static double wape(List<double> actual, List<double> predicted) {
    final n = math.min(actual.length, predicted.length);
    double err = 0, total = 0;
    for (var i = 0; i < n; i++) {
      err += (actual[i] - predicted[i]).abs();
      total += actual[i].abs();
    }
    return total == 0 ? double.nan : err / total;
  }

  /// Regressão linear simples y = a + b·x, com x = 0..n-1.
  static LinearFit linearFit(List<double> ys) {
    final n = ys.length;
    if (n < 2) {
      return LinearFit(intercept: n == 1 ? ys.first : 0, slope: 0, r2: 0, n: n, sxx: 0);
    }
    final xMean = (n - 1) / 2;
    final yMean = mean(ys);
    double sxy = 0, sxx = 0, sst = 0;
    for (var i = 0; i < n; i++) {
      final dx = i - xMean;
      sxy += dx * (ys[i] - yMean);
      sxx += dx * dx;
      sst += (ys[i] - yMean) * (ys[i] - yMean);
    }
    final slope = sxx == 0 ? 0.0 : sxy / sxx;
    final intercept = yMean - slope * xMean;
    double sse = 0;
    for (var i = 0; i < n; i++) {
      final e = ys[i] - (intercept + slope * i);
      sse += e * e;
    }
    final r2 = sst == 0 ? 0.0 : (1 - sse / sst).clamp(0.0, 1.0);
    return LinearFit(intercept: intercept, slope: slope, r2: r2, n: n, sxx: sxx);
  }

  static double clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);
}

class LinearFit {
  const LinearFit({
    required this.intercept,
    required this.slope,
    required this.r2,
    required this.n,
    required this.sxx,
  });

  final double intercept;
  final double slope;
  final double r2;
  final int n;
  final double sxx;

  double predict(num x) => intercept + slope * x;
}
