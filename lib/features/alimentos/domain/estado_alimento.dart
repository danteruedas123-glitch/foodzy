import 'package:foodzy/core/json.dart';

/// En qué punto de su vida está un alimento.
sealed class EstadoAlimento {
  const EstadoAlimento();

  /// El ÚNICO sitio donde un texto del JSON se convierte en un tipo.
  factory EstadoAlimento.fromJson(Map<String, dynamic> json) {
    final tipo = leerTexto(json, 'tipo');
    return switch (tipo) {
      'disponible' => Disponible(leerFecha(json, 'fechaIngreso')),
      'consumido' => Consumido(leerFecha(json, 'fechaConsumo')),
      'desechado' => Desechado(leerTexto(json, 'motivo')),
      _ => throw CampoInvalido('estado.tipo', 'no es un estado conocido', tipo),
    };
  }

  /// Y el único sitio donde vuelve a ser texto. Simétrico a fromJson.
  Map<String, dynamic> toJson() => switch (this) {
        Disponible(:final fechaIngreso) => {
            'tipo': 'disponible',
            'fechaIngreso': fechaIngreso.toIso8601String(),
          },
        Consumido(:final fechaConsumo) => {
            'tipo': 'consumido',
            'fechaConsumo': fechaConsumo.toIso8601String(),
          },
        Desechado(:final motivo) => {'tipo': 'desechado', 'motivo': motivo},
      };

  /// Regla de negocio, no de interfaz: si el alimento aún se puede consumir.
  bool get esConsumible => switch (this) {
        Disponible() => true,
        Consumido() || Desechado() => false,
      };

  /// Texto para la pantalla.
  String get etiqueta => switch (this) {
        Disponible() => 'Disponible',
        Consumido() => 'Consumido',
        Desechado(:final motivo) => 'Desechado: $motivo',
      };
}

final class Disponible extends EstadoAlimento {
  const Disponible(this.fechaIngreso);

  final DateTime fechaIngreso;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Disponible && other.fechaIngreso == fechaIngreso;

  @override
  int get hashCode => Object.hash(runtimeType, fechaIngreso);

  @override
  String toString() => 'Disponible($fechaIngreso)';
}

final class Consumido extends EstadoAlimento {
  const Consumido(this.fechaConsumo);

  final DateTime fechaConsumo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Consumido && other.fechaConsumo == fechaConsumo;

  @override
  int get hashCode => Object.hash(runtimeType, fechaConsumo);

  @override
  String toString() => 'Consumido($fechaConsumo)';
}

final class Desechado extends EstadoAlimento {
  const Desechado(this.motivo) : assert(motivo != '', 'desechar exige motivo');

  final String motivo;   // desechar SIN motivo no se puede ni escribir

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Desechado && other.motivo == motivo;

  @override
  int get hashCode => Object.hash(runtimeType, motivo);

  @override
  String toString() => 'Desechado($motivo)';
}
