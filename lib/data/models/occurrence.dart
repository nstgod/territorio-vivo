import 'package:flutter/material.dart';

import 'indicator.dart';

enum OccurrenceCategory {
  waterLeak('Vazamento de água', Icons.water_damage_outlined, IndicatorId.water),
  powerOutage('Falta de energia', Icons.power_off_outlined, IndicatorId.energy),
  garbage('Lixo acumulado', Icons.delete_sweep_outlined, IndicatorId.waste),
  flooding('Alagamento', Icons.flood_outlined, IndicatorId.precipitation),
  healthQueue('Fila longa na UBS', Icons.groups_outlined, IndicatorId.healthDemand),
  heat('Calor extremo / falta de sombra', Icons.wb_sunny_outlined, IndicatorId.tempMax),
  other('Outro', Icons.more_horiz, null);

  const OccurrenceCategory(this.label, this.icon, this.relatedIndicator);
  final String label;
  final IconData icon;

  /// Indicador ao qual a ocorrência serve de evidência complementar.
  final IndicatorId? relatedIndicator;
}

/// Ocorrência registrada por um cidadão.
///
/// Privacidade por desenho: não há nome, e-mail, telefone ou GPS. A
/// localização é generalizada para a região e o relato passa pelo
/// anonimizador antes de ser salvo.
class Occurrence {
  const Occurrence({
    required this.id,
    required this.category,
    required this.regionId,
    required this.description,
    required this.severity,
    required this.occurredOn,
    required this.createdAt,
    required this.reporterToken,
    this.redactedItems = const [],
  });

  final String id;
  final OccurrenceCategory category;
  final String regionId;

  /// Texto já anonimizado.
  final String description;

  /// Percepção do cidadão, de 1 (baixa) a 5 (muito grave).
  final int severity;
  final DateTime occurredOn;
  final DateTime createdAt;

  /// Token aleatório do aparelho — permite contar relatos sem identificar
  /// quem relatou.
  final String reporterToken;

  /// Tipos de dado pessoal removidos do texto (ex.: "telefone").
  final List<String> redactedItems;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'regionId': regionId,
        'description': description,
        'severity': severity,
        'occurredOn': occurredOn.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'reporterToken': reporterToken,
        'redactedItems': redactedItems,
      };

  factory Occurrence.fromJson(Map<String, dynamic> json) => Occurrence(
        id: json['id'] as String,
        category: OccurrenceCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => OccurrenceCategory.other,
        ),
        regionId: json['regionId'] as String,
        description: json['description'] as String,
        severity: (json['severity'] as num).toInt(),
        occurredOn: DateTime.parse(json['occurredOn'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        reporterToken: json['reporterToken'] as String,
        redactedItems: ((json['redactedItems'] as List?) ?? const []).cast<String>(),
      );
}
