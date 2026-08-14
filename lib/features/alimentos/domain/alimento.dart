import 'package:foodzy/core/comparaciones.dart';
import 'package:foodzy/core/json.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

/// Un alimento registrado.
///
/// Es una **entidad**: tiene identidad propia. Dos alimentos con los mismos
/// datos son distintos si tienen `id` distinto.
class Alimento {
  const Alimento({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.cantidad,
    required this.fechaVencimiento,
    required this.estado,
    this.fotos = const <String>[],
  });

  factory Alimento.fromJson(Map<String, dynamic> json) => Alimento(
        id: leerTexto(json, 'id'),
        nombre: leerTexto(json, 'nombre'),
        categoria: leerTexto(json, 'categoria'),
        cantidad: Cantidad.fromJson(leerMapa(json, 'cantidad')),
        fechaVencimiento: leerFecha(json, 'fechaVencimiento'),
        estado: EstadoAlimento.fromJson(leerMapa(json, 'estado')),
        fotos: leerTextos(json, 'fotos'),
      );

  final String id;
  final String nombre;
  final String categoria;
  final Cantidad cantidad;
  final DateTime fechaVencimiento;
  final EstadoAlimento estado;
  final List<String> fotos;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'categoria': categoria,
        'cantidad': cantidad.toJson(),
        'fechaVencimiento': fechaVencimiento.toUtc().toIso8601String(),
        'estado': estado.toJson(),
        'fotos': fotos,
      };

  // ── Reglas de negocio ───────────────────────────────────────────────────

  bool get tieneFotos => fotos.isNotEmpty;

  bool get esConsumible => estado.esConsumible;

  /// El reloj entra como parámetro, no se lee dentro.
  Duration tiempoRestante(DateTime ahora) => fechaVencimiento.difference(ahora);

  bool estaVencido(DateTime ahora) => tiempoRestante(ahora).isNegative;

  // ── Copia ───────────────────────────────────────────────────────────────

  Alimento copyWith({
    String? nombre,
    String? categoria,
    Cantidad? cantidad,
    EstadoAlimento? estado,
    List<String>? fotos,
  }) =>
      Alimento(
        id: id,                            // la identidad NO se copia con cambios
        nombre: nombre ?? this.nombre,
        categoria: categoria ?? this.categoria,
        cantidad: cantidad ?? this.cantidad,
        fechaVencimiento: fechaVencimiento, // ni la fecha de vencimiento
        estado: estado ?? this.estado,
        fotos: fotos ?? this.fotos,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alimento &&
          other.id == id &&
          other.nombre == nombre &&
          other.categoria == categoria &&
          other.cantidad == cantidad &&
          other.fechaVencimiento == fechaVencimiento &&
          other.estado == estado &&
          listasIguales(other.fotos, fotos);

  @override
  int get hashCode => Object.hash(
        id,
        nombre,
        categoria,
        cantidad,
        fechaVencimiento,
        estado,
        Object.hashAll(fotos),
      );

  @override
  String toString() => 'Alimento($id, $nombre, ${estado.etiqueta})';
}
