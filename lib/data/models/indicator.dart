import 'package:flutter/material.dart';

/// Painéis (dashboards) do app. Cada indicador pertence a um.
enum DashboardKind {
  climate('Clima e ar', Icons.thermostat_outlined),
  resources('Água e energia', Icons.water_drop_outlined),
  services('Serviços públicos', Icons.local_hospital_outlined);

  const DashboardKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Origem do dado — exibida em todo gráfico para deixar claro o que é real
/// e o que é simulado.
enum DataOrigin {
  real('Dado real · Open-Meteo'),
  synthetic('Dado sintético · simulação');

  const DataOrigin(this.label);
  final String label;
}

/// Catálogo dos indicadores monitorados.
enum IndicatorId {
  tempMax(
    label: 'Temperatura máxima',
    shortName: 'Temp. máx.',
    unit: '°C',
    dashboard: DashboardKind.climate,
    origin: DataOrigin.real,
    icon: Icons.thermostat,
    decimals: 1,
    description:
        'Temperatura máxima diária a 2 m do solo. Histórico (30 dias) e previsão '
        'meteorológica (7 dias) do modelo da Open-Meteo.',
  ),
  precipitation(
    label: 'Chuva acumulada',
    shortName: 'Chuva',
    unit: 'mm',
    dashboard: DashboardKind.climate,
    origin: DataOrigin.real,
    icon: Icons.water,
    decimals: 1,
    description:
        'Precipitação acumulada por dia. Volumes altos em poucos dias elevam o '
        'risco de alagamento em áreas de várzea.',
  ),
  pm25(
    label: 'Material particulado PM2,5',
    shortName: 'PM2,5',
    unit: 'µg/m³',
    dashboard: DashboardKind.climate,
    origin: DataOrigin.real,
    icon: Icons.air,
    decimals: 1,
    description:
        'Concentração média diária de partículas finas (modelo CAMS via '
        'Open-Meteo Air Quality). Referência OMS 2021: 15 µg/m³ em 24 h.',
  ),
  water(
    label: 'Consumo de água',
    shortName: 'Água',
    unit: 'mil m³/dia',
    dashboard: DashboardKind.resources,
    origin: DataOrigin.synthetic,
    icon: Icons.water_drop,
    decimals: 1,
    description:
        'Volume distribuído por dia na região. Série sintética calibrada em '
        '~150 L/hab/dia, com sazonalidade semanal e eventos simulados.',
  ),
  energy(
    label: 'Consumo de energia',
    shortName: 'Energia',
    unit: 'MWh/dia',
    dashboard: DashboardKind.resources,
    origin: DataOrigin.synthetic,
    icon: Icons.bolt,
    decimals: 0,
    description:
        'Energia residencial consumida por dia. Série sintética calibrada em '
        '~6 kWh/hab/dia.',
  ),
  waste(
    label: 'Resíduos coletados',
    shortName: 'Resíduos',
    unit: 't/dia',
    dashboard: DashboardKind.services,
    origin: DataOrigin.synthetic,
    icon: Icons.delete_outline,
    decimals: 0,
    description:
        'Toneladas de resíduos domiciliares coletadas por dia. Queda brusca '
        'pode indicar falha de coleta e acúmulo nas ruas.',
  ),
  healthDemand(
    label: 'Atendimentos nas UBS',
    shortName: 'UBS',
    unit: 'atend./dia',
    dashboard: DashboardKind.services,
    origin: DataOrigin.synthetic,
    icon: Icons.medical_services_outlined,
    decimals: 0,
    description:
        'Atendimentos diários somados das Unidades Básicas de Saúde da região. '
        'Série sintética com queda nos fins de semana.',
  );

  const IndicatorId({
    required this.label,
    required this.shortName,
    required this.unit,
    required this.dashboard,
    required this.origin,
    required this.icon,
    required this.decimals,
    required this.description,
  });

  final String label;
  final String shortName;
  final String unit;
  final DashboardKind dashboard;
  final DataOrigin origin;
  final IconData icon;
  final int decimals;
  final String description;

  static List<IndicatorId> of(DashboardKind kind) =>
      values.where((i) => i.dashboard == kind).toList();

  static IndicatorId? tryParse(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
