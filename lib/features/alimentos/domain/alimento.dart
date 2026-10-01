import 'package:foodzy/core/comparaciones.dart';
import 'package:foodzy/core/json.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

/// De dónde salió la fecha de vencimiento de un alimento.
enum FechaOrigen {
  /// La IA la leyó impresa en el empaque.
  leida,

  /// Se calculó según el tipo de producto; es aproximada.
  estimada,

  /// La escribió o confirmó la persona.
  manual;

  static FechaOrigen desde(String? nombre) => FechaOrigen.values.firstWhere(
        (o) => o.name == nombre,
        orElse: () => FechaOrigen.manual,
      );
}

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
    this.origenFecha = FechaOrigen.manual,
  });

  factory Alimento.fromJson(Map<String, dynamic> json) => Alimento(
        id: leerTexto(json, 'id'),
        nombre: leerTexto(json, 'nombre'),
        categoria: leerTexto(json, 'categoria'),
        cantidad: Cantidad.fromJson(leerMapa(json, 'cantidad')),
        fechaVencimiento: leerFecha(json, 'fechaVencimiento'),
        estado: EstadoAlimento.fromJson(leerMapa(json, 'estado')),
        fotos: leerTextos(json, 'fotos'),
        origenFecha: FechaOrigen.desde(leerTextoOpcional(json, 'origenFecha')),
      );

  final String id;
  final String nombre;
  final String categoria;
  final Cantidad cantidad;
  final DateTime fechaVencimiento;
  final EstadoAlimento estado;
  final List<String> fotos;
  final FechaOrigen origenFecha;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'categoria': categoria,
        'cantidad': cantidad.toJson(),
        'fechaVencimiento': fechaVencimiento.toUtc().toIso8601String(),
        'estado': estado.toJson(),
        'fotos': fotos,
        'origenFecha': origenFecha.name,
      };

  // ── Reglas de negocio ───────────────────────────────────────────────────

  bool get tieneFotos => fotos.isNotEmpty;

  bool get esConsumible => estado.esConsumible;

  /// El reloj entra como parámetro, no se lee dentro.
  Duration tiempoRestante(DateTime ahora) => fechaVencimiento.difference(ahora);

  bool estaVencido(DateTime ahora) => tiempoRestante(ahora).isNegative;

  /// Marca interna de "aún no se conoce la fecha de vencimiento".
  static final DateTime sinFecha = DateTime(1970, 1, 1);

  bool get sinFechaVencimiento => fechaVencimiento == sinFecha;

  /// Marca interna de "este alimento no vence" (sal, azúcar, miel...).
  static final DateTime nuncaVence = DateTime(9999, 12, 31);

  bool get noVence => fechaVencimiento.year >= 9999;

  /// Copia con otra fecha de vencimiento y su origen (ej. cuando la persona
  /// la completa o la IA la lee de una foto).
  Alimento conFecha(
    DateTime fecha, {
    FechaOrigen origen = FechaOrigen.manual,
  }) =>
      Alimento(
        id: id,
        nombre: nombre,
        categoria: categoria,
        cantidad: cantidad,
        fechaVencimiento: fecha,
        estado: estado,
        fotos: fotos,
        origenFecha: origen,
      );

  /// Copia marcada como "no vence".
  Alimento sinVencimiento() => conFecha(nuncaVence);

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
        origenFecha: origenFecha,
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
          other.origenFecha == origenFecha &&
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
        origenFecha,
      );

  @override
  String toString() => 'Alimento($id, $nombre, ${estado.etiqueta})';
}
