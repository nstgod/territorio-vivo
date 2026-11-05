import 'indicator.dart';

enum AlertSeverity {
  info('Informativo', 0),
  attention('Atenção', 1),
  critical('Crítico', 2);

  const AlertSeverity(this.label, this.rank);
  final String label;
  final int rank;
}

enum AlertKind {
  heatWave('Onda de calor'),
  heavyRain('Chuva forte / alagamento'),
  airQuality('Qualidade do ar'),
  anomaly('Anomalia no consumo'),
  forecastRise('Alta prevista na demanda'),
  forecastDrop('Queda prevista no serviço');

  const AlertKind(this.label);
  final String label;
}

enum ConfidenceLevel {
  high('Alta'),
  medium('Média'),
  low('Baixa');

  const ConfidenceLevel(this.label);
  final String label;

  static ConfidenceLevel fromScore(double score) {
    if (score >= 0.75) return high;
    if (score >= 0.5) return medium;
    return low;
  }
}

/// Um fator que compõe a nota de confiança, exibido para transparência.
class ConfidenceFactor {
  const ConfidenceFactor(this.label, this.score, this.explanation);

  final String label;

  /// 0 a 1.
  final double score;
  final String explanation;
}

class AlertConfidence {
  const AlertConfidence({required this.score, required this.factors});

  /// 0 a 1, média ponderada dos fatores.
  final double score;
  final List<ConfidenceFactor> factors;

  ConfidenceLevel get level => ConfidenceLevel.fromScore(score);

  /// Abaixo deste valor o app avisa que a previsão não é confiável para
  /// embasar decisão.
  static const double reliableThreshold = 0.5;
  bool get isReliable => score >= reliableThreshold;
}

/// Alerta preditivo. É sempre uma *recomendação de análise*: o app nunca
/// executa ação sobre o território; a decisão é registrada por um humano.
class TerritoryAlert {
  const TerritoryAlert({
    required this.id,
    required this.kind,
    required this.severity,
    required this.regionId,
    required this.indicator,
    required this.title,
    required this.summary,
    required this.evidence,
    required this.confidence,
    required this.limitations,
    required this.suggestedActions,
    required this.generatedAt,
    required this.observedValue,
    required this.referenceValue,
    required this.thresholdLabel,
    this.excessVolume = 0,
  });

  /// Determinístico (tipo + região + indicador + dia) para que a decisão
  /// humana registrada continue associada ao alerta após recarregar.
  final String id;
  final AlertKind kind;
  final AlertSeverity severity;
  final String regionId;
  final IndicatorId indicator;
  final String title;
  final String summary;

  /// Evidências numéricas que justificam o alerta.
  final List<String> evidence;
  final AlertConfidence confidence;
  final List<String> limitations;

  /// Sugestões para o gestor avaliar — nunca executadas pelo app.
  final List<String> suggestedActions;
  final DateTime generatedAt;

  /// Valor observado/previsto que disparou a regra.
  final double observedValue;

  /// Valor de referência (linha de base ou limiar).
  final double referenceValue;
  final String thresholdLabel;

  /// Para anomalias de água: volume excedente estimado (mil m³), usado no
  /// indicador de benefício social quando o alerta é confirmado.
  final double excessVolume;
}

enum DecisionStatus {
  pending('Aguardando análise humana'),
  confirmed('Confirmado pelo gestor'),
  dismissed('Descartado pelo gestor');

  const DecisionStatus(this.label);
  final String label;
}

/// Registro da decisão humana sobre um alerta (persistido localmente).
class AlertDecision {
  const AlertDecision({
    required this.alertId,
    required this.status,
    required this.note,
    required this.decidedAt,
    this.reviewerRole = 'Gestor(a) público(a)',
  });

  final String alertId;
  final DecisionStatus status;
  final String note;
  final DateTime decidedAt;

  /// Apenas o papel, nunca o nome: a decisão é auditável sem expor pessoas.
  final String reviewerRole;

  Map<String, dynamic> toJson() => {
        'alertId': alertId,
        'status': status.name,
        'note': note,
        'decidedAt': decidedAt.toIso8601String(),
        'reviewerRole': reviewerRole,
      };

  factory AlertDecision.fromJson(Map<String, dynamic> json) => AlertDecision(
        alertId: json['alertId'] as String,
        status: DecisionStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => DecisionStatus.pending,
        ),
        note: json['note'] as String? ?? '',
        decidedAt: DateTime.parse(json['decidedAt'] as String),
        reviewerRole: json['reviewerRole'] as String? ?? 'Gestor(a) público(a)',
      );
}
