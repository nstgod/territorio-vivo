/// Falha ao obter dados de uma fonte externa.
class ApiException implements Exception {
  const ApiException(this.message, {this.offline = false});

  final String message;

  /// Verdadeiro quando a falha é de conectividade (ou modo offline simulado).
  final bool offline;

  @override
  String toString() => 'ApiException: $message';
}
