import 'package:foodzy/features/recetas/domain/recetas_service.dart';

/// La receta como texto para mandar por WhatsApp, correo, etc.
String textoParaCompartir(Receta receta) {
  final b = StringBuffer()
    ..writeln('🍳 ${receta.titulo}')
    ..writeln(
        '⏱ ${receta.minutos} min · ${receta.porciones} ${receta.porciones == 1 ? 'porción' : 'porciones'}');

  if (receta.descripcion.trim().isNotEmpty) {
    b
      ..writeln()
      ..writeln(receta.descripcion.trim());
  }

  b
    ..writeln()
    ..writeln('Ingredientes:');
  for (final i in receta.ingredientes) {
    final cantidad = i.cantidad.trim().isEmpty ? '' : ' · ${i.cantidad.trim()}';
    final falta = i.enDespensa ? '' : ' (por conseguir)';
    b.writeln('- ${i.nombre}$cantidad$falta');
  }

  b
    ..writeln()
    ..writeln('Preparación:');
  for (var n = 0; n < receta.pasos.length; n++) {
    b.writeln('${n + 1}. ${receta.pasos[n]}');
  }

  b
    ..writeln()
    ..write('Hecha con Foodzy');
  return b.toString();
}
