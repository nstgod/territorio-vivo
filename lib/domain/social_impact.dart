import '../data/models/alert.dart';
import '../data/models/indicator.dart';
import '../data/models/occurrence.dart';
import '../data/models/region.dart';

/// Indicadores de benefício social: ligam o desempenho analítico ao que
/// importa para a população.
class SocialImpact {
  const SocialImpact({
    required this.populationMonitored,
    required this.populationInAlertAreas,
    required this.waterSavedM3,
    required this.alertsTotal,
    required this.alertsReviewed,
    required this.alertsConfirmed,
    required this.citizenReports,
    required this.heatAlertRegions,
  });

  /// Habitantes das regiões com dados disponíveis.
  final int populationMonitored;

  /// Habitantes em regiões com alerta de atenção ou crítico.
  final int populationInAlertAreas;

  /// m³ de água potencialmente preservados se as anomalias confirmadas
  /// pelo gestor forem corrigidas (excedente estimado de 3 dias).
  final double waterSavedM3;

  final int alertsTotal;
  final int alertsReviewed;
  final int alertsConfirmed;
  final int citizenReports;

  /// Regiões com onda de calor prevista — preparo antecipado de acolhimento.
  final int heatAlertRegions;

  double get reviewRate => alertsTotal == 0 ? 0 : alertsReviewed / alertsTotal;

  static SocialImpact compute({
    required List<TerritoryAlert> alerts,
    required Map<String, AlertDecision> decisions,
    required List<Occurrence> occurrences,
    required Set<String> regionsWithData,
  }) {
    final regions = Territory.regions.where((r) => regionsWithData.contains(r.id));
    final alertRegions = alerts
        .where((a) => a.severity != AlertSeverity.info)
        .map((a) => a.regionId)
        .toSet();
    double water = 0;
    var reviewed = 0, confirmed = 0;
    for (final a in alerts) {
      final d = decisions[a.id];
      if (d == null || d.status == DecisionStatus.pending) continue;
      reviewed++;
      if (d.status == DecisionStatus.confirmed) {
        confirmed++;
        if (a.indicator == IndicatorId.water) water += a.excessVolume * 1000;
      }
    }
    return SocialImpact(
      populationMonitored: regions.fold(0, (s, r) => s + r.population),
      populationInAlertAreas: Territory.regions
          .where((r) => alertRegions.contains(r.id))
          .fold(0, (s, r) => s + r.population),
      waterSavedM3: water,
      alertsTotal: alerts.length,
      alertsReviewed: reviewed,
      alertsConfirmed: confirmed,
      citizenReports: occurrences.length,
      heatAlertRegions: alerts.where((a) => a.kind == AlertKind.heatWave).length,
    );
  }
}
