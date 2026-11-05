/// Limiares configuráveis pelo gestor (formulário "Limiares de alerta").
///
/// Os padrões seguem referências públicas quando existem (OMS para PM2,5,
/// INMET/Defesa Civil para chuva e calor) e são documentados no README.
class AlertThresholds {
  const AlertThresholds({
    this.heatMaxTemp = 32,
    this.heatConsecutiveDays = 3,
    this.rainDailyMm = 30,
    this.pm25 = 25,
    this.anomalyZScore = 2.5,
    this.waterRisePct = 10,
    this.energyRisePct = 10,
    this.healthRisePct = 12,
    this.wasteDropPct = 15,
    this.notifyMinConfidence = 0.6,
  });

  /// °C — temperatura máxima que caracteriza dia de calor intenso.
  final double heatMaxTemp;

  /// Dias seguidos acima de [heatMaxTemp] para caracterizar onda de calor.
  final int heatConsecutiveDays;

  /// mm/dia — chuva que eleva o risco de alagamento.
  final double rainDailyMm;

  /// µg/m³ — média diária de PM2,5.
  final double pm25;

  /// Desvios-padrão acima da linha de base para considerar anomalia.
  final double anomalyZScore;

  /// % de aumento previsto (média 7 dias vs. linha de base).
  final double waterRisePct;
  final double energyRisePct;
  final double healthRisePct;

  /// % de queda prevista na coleta de resíduos.
  final double wasteDropPct;

  /// Só alertas críticos com confiança >= este valor viram notificação.
  final double notifyMinConfidence;

  static const AlertThresholds defaults = AlertThresholds();

  AlertThresholds copyWith({
    double? heatMaxTemp,
    int? heatConsecutiveDays,
    double? rainDailyMm,
    double? pm25,
    double? anomalyZScore,
    double? waterRisePct,
    double? energyRisePct,
    double? healthRisePct,
    double? wasteDropPct,
    double? notifyMinConfidence,
  }) {
    return AlertThresholds(
      heatMaxTemp: heatMaxTemp ?? this.heatMaxTemp,
      heatConsecutiveDays: heatConsecutiveDays ?? this.heatConsecutiveDays,
      rainDailyMm: rainDailyMm ?? this.rainDailyMm,
      pm25: pm25 ?? this.pm25,
      anomalyZScore: anomalyZScore ?? this.anomalyZScore,
      waterRisePct: waterRisePct ?? this.waterRisePct,
      energyRisePct: energyRisePct ?? this.energyRisePct,
      healthRisePct: healthRisePct ?? this.healthRisePct,
      wasteDropPct: wasteDropPct ?? this.wasteDropPct,
      notifyMinConfidence: notifyMinConfidence ?? this.notifyMinConfidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'heatMaxTemp': heatMaxTemp,
        'heatConsecutiveDays': heatConsecutiveDays,
        'rainDailyMm': rainDailyMm,
        'pm25': pm25,
        'anomalyZScore': anomalyZScore,
        'waterRisePct': waterRisePct,
        'energyRisePct': energyRisePct,
        'healthRisePct': healthRisePct,
        'wasteDropPct': wasteDropPct,
        'notifyMinConfidence': notifyMinConfidence,
      };

  factory AlertThresholds.fromJson(Map<String, dynamic> j) {
    double d(String k, double fallback) => (j[k] as num?)?.toDouble() ?? fallback;
    const f = defaults;
    return AlertThresholds(
      heatMaxTemp: d('heatMaxTemp', f.heatMaxTemp),
      heatConsecutiveDays: (j['heatConsecutiveDays'] as num?)?.toInt() ?? f.heatConsecutiveDays,
      rainDailyMm: d('rainDailyMm', f.rainDailyMm),
      pm25: d('pm25', f.pm25),
      anomalyZScore: d('anomalyZScore', f.anomalyZScore),
      waterRisePct: d('waterRisePct', f.waterRisePct),
      energyRisePct: d('energyRisePct', f.energyRisePct),
      healthRisePct: d('healthRisePct', f.healthRisePct),
      wasteDropPct: d('wasteDropPct', f.wasteDropPct),
      notifyMinConfidence: d('notifyMinConfidence', f.notifyMinConfidence),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AlertThresholds && _mapEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }
}
