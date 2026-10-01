import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Borra del dispositivo las fotos [candidatas] que ya no usa ningún
/// alimento ([enUso]). Solo toca archivos de la carpeta temporal de la app
/// (donde la cámara y la galería dejan sus copias), nunca fotos del usuario.
Future<int> borrarFotosHuerfanas(
  Iterable<String> candidatas,
  Set<String> enUso,
) async {
  if (kIsWeb) return 0;
  var borradas = 0;
  try {
    final temporal = (await getTemporaryDirectory()).path;
    for (final ruta in candidatas.toSet()) {
      if (enUso.contains(ruta)) continue;
      if (ruta.startsWith('http') || ruta.startsWith('blob:')) continue;
      if (!ruta.startsWith(temporal)) continue;
      final archivo = File(ruta);
      if (await archivo.exists()) {
        await archivo.delete();
        borradas++;
      }
    }
  } catch (_) {
    // Limpiar fotos es un extra: un fallo aquí no debe afectar a nada más.
  }
  return borradas;
}
