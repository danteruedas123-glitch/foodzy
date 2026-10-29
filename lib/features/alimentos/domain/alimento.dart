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

/// Dónde se guarda un alimento. Cambia mucho cuánto dura.
enum Ubicacion {
  nevera('Nevera', '🧊'),
  congelador('Congelador', '❄️'),
  alacena('Alacena', '🗄️');

  const Ubicacion(this.etiqueta, this.emoji);
  final String etiqueta;
  final String emoji;

  /// `null` si el texto no corresponde a ninguna (datos antiguos).
  static Ubicacion? desde(String? nombre) {
    for (final u in Ubicacion.values) {
      if (u.name == nombre) return u;
    }
    return null;
  }
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
    this.ubicacion,
    this.precio,
    this.fechaCompra,
    this.cantidadInicial,
    this.emoji,
    this.ticket,
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
        ubicacion: Ubicacion.desde(leerTextoOpcional(json, 'ubicacion')),
        precio: (json['precio'] as num?)?.toDouble(),
        fechaCompra:
            DateTime.tryParse(leerTextoOpcional(json, 'fechaCompra') ?? ''),
        cantidadInicial: (json['cantidadInicial'] as num?)?.toDouble(),
        emoji: leerTextoOpcional(json, 'emoji'),
        ticket: leerTextoOpcional(json, 'ticket'),
      );

  final String id;
  final String nombre;
  final String categoria;
  final Cantidad cantidad;
  final DateTime fechaVencimiento;
  final EstadoAlimento estado;
  final List<String> fotos;
  final FechaOrigen origenFecha;

  /// Dónde se guarda (nevera, congelador, alacena). `null` si no se indicó.
  final Ubicacion? ubicacion;

  /// Lo que costó este producto (el total de su renglón en la factura).
  final double? precio;

  /// Cuándo se compró o registró.
  final DateTime? fechaCompra;

  /// Cantidad con la que entró, para saber qué parte se desperdició.
  final double? cantidadInicial;

  /// Emoji que eligió la IA para este producto concreto (🧀, 🍌...). Se usa
  /// de miniatura cuando no hay foto del producto.
  final String? emoji;

  /// Foto de la factura de la que salió, si se registró escaneando una. Va
  /// aparte de [fotos] porque no muestra el producto.
  final String? ticket;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'categoria': categoria,
        'cantidad': cantidad.toJson(),
        'fechaVencimiento': fechaVencimiento.toUtc().toIso8601String(),
        'estado': estado.toJson(),
        'fotos': fotos,
        'origenFecha': origenFecha.name,
        if (ubicacion != null) 'ubicacion': ubicacion!.name,
        if (precio != null) 'precio': precio,
        if (fechaCompra != null) 'fechaCompra': fechaCompra!.toIso8601String(),
        if (cantidadInicial != null) 'cantidadInicial': cantidadInicial,
        if (emoji != null) 'emoji': emoji,
        if (ticket != null) 'ticket': ticket,
      };

  // ── Reglas de negocio ───────────────────────────────────────────────────

  bool get tieneFotos => fotos.isNotEmpty;

  bool get esConsumible => estado.esConsumible;

  /// El reloj entra como parámetro, no se lee dentro.
  Duration tiempoRestante(DateTime ahora) => fechaVencimiento.difference(ahora);

  /// Días de calendario que faltan para el día de vencimiento: 0 si vence
  /// hoy, negativo si ya venció. La fecha se guarda en UTC, así que se pasa a
  /// hora local antes de tomar el día (si no, en algunos países caía en el
  /// día anterior). Se resta en UTC para que un cambio de horario de verano
  /// no le quite un día a la cuenta.
  int diasParaVencer(DateTime ahora) {
    final f = fechaVencimiento.toLocal();
    final a = ahora.toLocal();
    return DateTime.utc(f.year, f.month, f.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
  }

  /// Vencido es que ya pasó el día de vencimiento: el día mismo aún "vence
  /// hoy" (una etiqueta que dice "vence el 30" sirve hasta el final del 30).
  /// Lo que no tiene fecha o no vence nunca está vencido. Es la misma regla
  /// de las etiquetas, Inicio, las recetas y los avisos.
  bool estaVencido(DateTime ahora) =>
      !sinFechaVencimiento && !noVence && diasParaVencer(ahora) < 0;

  /// Marca interna de "aún no se conoce la fecha de vencimiento".
  static final DateTime sinFecha = DateTime(1970, 1, 1);

  /// Se compara el año y no con `==`: al guardarse, la fecha vuelve en UTC y
  /// `==` exige además la misma zona horaria, así que un alimento "sin fecha"
  /// dejaba de serlo al leerlo de la base.
  bool get sinFechaVencimiento => fechaVencimiento.year <= 1970;

  /// Marca interna de "este alimento no vence" (sal, azúcar, miel...).
  static final DateTime nuncaVence = DateTime(9999, 12, 31);

  bool get noVence => fechaVencimiento.year >= 9999;

  /// Cuándo entró a la despensa: la fecha de compra o, en registros antiguos,
  /// la de ingreso del estado "disponible".
  DateTime? get ingreso {
    if (fechaCompra != null) return fechaCompra;
    final e = estado;
    return e is Disponible ? e.fechaIngreso : null;
  }

  /// Copia con otra fecha de vencimiento y su origen (ej. cuando la persona
  /// la completa o la IA la lee de una foto).
  Alimento conFecha(
    DateTime fecha, {
    FechaOrigen origen = FechaOrigen.manual,
  }) =>
      _copiar(fechaVencimiento: fecha, origenFecha: origen);

  /// Copia con otro id y otras fotos (al guardar lo detectado por la IA).
  /// Con [ticket] guarda también la foto de la factura de la que salió.
  Alimento conIdYFotos(String nuevoId, List<String> nuevasFotos, {String? ticket}) =>
      Alimento(
        id: nuevoId,
        nombre: nombre,
        categoria: categoria,
        cantidad: cantidad,
        fechaVencimiento: fechaVencimiento,
        estado: estado,
        fotos: nuevasFotos,
        origenFecha: origenFecha,
        ubicacion: ubicacion,
        precio: precio,
        fechaCompra: fechaCompra,
        cantidadInicial: cantidadInicial,
        emoji: emoji,
        ticket: ticket ?? this.ticket,
      );

  /// Copia marcada como "no vence".
  Alimento sinVencimiento() => conFecha(nuncaVence);

  // ── Copia ───────────────────────────────────────────────────────────────

  /// Copia de uso general. La identidad (`id`) no cambia nunca, ni la fecha de
  /// vencimiento: para eso están [conFecha] y [sinVencimiento].
  Alimento copyWith({
    String? nombre,
    String? categoria,
    Cantidad? cantidad,
    EstadoAlimento? estado,
    List<String>? fotos,
    Ubicacion? ubicacion,
    double? precio,
  }) =>
      _copiar(
        nombre: nombre,
        categoria: categoria,
        cantidad: cantidad,
        estado: estado,
        fotos: fotos,
        ubicacion: ubicacion,
        precio: precio,
      );

  Alimento _copiar({
    String? nombre,
    String? categoria,
    Cantidad? cantidad,
    DateTime? fechaVencimiento,
    EstadoAlimento? estado,
    List<String>? fotos,
    FechaOrigen? origenFecha,
    Ubicacion? ubicacion,
    double? precio,
  }) =>
      Alimento(
        id: id,
        nombre: nombre ?? this.nombre,
        categoria: categoria ?? this.categoria,
        cantidad: cantidad ?? this.cantidad,
        fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
        estado: estado ?? this.estado,
        fotos: fotos ?? this.fotos,
        origenFecha: origenFecha ?? this.origenFecha,
        ubicacion: ubicacion ?? this.ubicacion,
        precio: precio ?? this.precio,
        fechaCompra: fechaCompra,
        cantidadInicial: cantidadInicial,
        emoji: emoji,
        ticket: ticket,
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
          other.ubicacion == ubicacion &&
          other.precio == precio &&
          other.fechaCompra == fechaCompra &&
          other.cantidadInicial == cantidadInicial &&
          other.emoji == emoji &&
          other.ticket == ticket &&
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
        ubicacion,
        precio,
        fechaCompra,
        cantidadInicial,
        emoji,
        ticket,
      );

  @override
  String toString() => 'Alimento($id, $nombre, ${estado.etiqueta})';
}
