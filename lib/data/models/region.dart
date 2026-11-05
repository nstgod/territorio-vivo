/// Uma região (subprefeitura) do território monitorado.
class Region {
  const Region({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.seed,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// População aproximada (ordem de grandeza, Censo IBGE 2022 por
  /// subprefeitura). Usada apenas para dimensionar a série sintética e o
  /// indicador de benefício social.
  final int population;

  /// Semente que torna a série sintética determinística por região.
  final int seed;
}

/// Território escolhido: Zona Leste de São Paulo, região populosa com
/// histórico de alagamentos, ilhas de calor e alta demanda por serviços.
abstract final class Territory {
  static const String name = 'Zona Leste · São Paulo';

  static const List<Region> regions = [
    Region(
      id: 'itaquera',
      name: 'Itaquera',
      latitude: -23.5365,
      longitude: -46.4555,
      population: 523000,
      seed: 11,
    ),
    Region(
      id: 'sao-mateus',
      name: 'São Mateus',
      latitude: -23.6100,
      longitude: -46.4750,
      population: 426000,
      seed: 23,
    ),
    Region(
      id: 'guaianases',
      name: 'Guaianases',
      latitude: -23.5420,
      longitude: -46.4120,
      population: 268000,
      seed: 37,
    ),
    Region(
      id: 'cidade-tiradentes',
      name: 'Cidade Tiradentes',
      latitude: -23.5820,
      longitude: -46.4090,
      population: 211000,
      seed: 41,
    ),
    Region(
      id: 'penha',
      name: 'Penha',
      latitude: -23.5240,
      longitude: -46.5420,
      population: 474000,
      seed: 53,
    ),
  ];

  static Region byId(String id) =>
      regions.firstWhere((r) => r.id == id, orElse: () => regions.first);

  static int get totalPopulation =>
      regions.fold(0, (sum, r) => sum + r.population);
}
