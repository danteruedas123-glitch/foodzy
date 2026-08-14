/// Lectura defensiva de mapas JSON.
///
/// La frontera con el mundo exterior es el sitio donde el compilador deja de
/// ayudar: `jsonDecode` devuelve `dynamic`. Estas funciones devuelven la
/// confianza al otro lado, y cuando no pueden, dicen exactamente por qué.

/// Un campo del JSON no tiene la forma que el modelo espera.
class CampoInvalido implements Exception {
  const CampoInvalido(this.campo, this.motivo, this.valor);

  final String campo;
  final String motivo;
  final Object? valor;

  @override
  String toString() => 'CampoInvalido: \'$campo\' $motivo (llegó: $valor)';
}

String leerTexto(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor is String && valor.trim().isNotEmpty) return valor;
  throw CampoInvalido(campo, 'debe ser un texto no vacío', valor);
}

String? leerTextoOpcional(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor == null) return null;                      // ausente y null: lo mismo
  if (valor is String) return valor;
  throw CampoInvalido(campo, 'debe ser un texto o venir ausente', valor);
}

double leerDecimal(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  // En JSON, 10 y 10.0 son el mismo número. En Dart, int y double NO lo son:
  // `valor as double` revienta con 10. Por eso se pasa por num.
  if (valor is num) return valor.toDouble();
  throw CampoInvalido(campo, 'debe ser un número', valor);
}

DateTime leerFecha(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor is! String) {
    throw CampoInvalido(campo, 'debe ser una fecha ISO 8601 en texto', valor);
  }
  final fecha = DateTime.tryParse(valor);              // tryParse, no parse:
  if (fecha == null) {                                 // el error lo damos nosotros
    throw CampoInvalido(campo, 'no es una fecha ISO 8601', valor);
  }
  return fecha.toUtc();                                // el dominio vive en UTC
}

Map<String, dynamic> leerMapa(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor is Map<String, dynamic>) return valor;
  throw CampoInvalido(campo, 'debe ser un objeto', valor);
}

List<String> leerTextos(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor == null) return const <String>[];          // ausente = lista vacía
  if (valor is! List) throw CampoInvalido(campo, 'debe ser una lista', valor);
  return List<String>.unmodifiable(
    valor.map(
      (e) => e is String
          ? e
          : throw CampoInvalido(campo, 'todos sus elementos deben ser texto', e),
    ),
  );
}
