import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// El cuadrado (en píxeles) que se recorta para un producto.
///
/// [caja] es `[ymin, xmin, ymax, xmax]` en milésimas de la imagen (0 a 1000),
/// como lo devuelve Gemini. Se agranda un poco ([margen]) para que el
/// producto no quede pegado al borde, se hace cuadrado (la miniatura lo es) y
/// se mantiene dentro de la imagen. `null` si la caja no sirve.
ui.Rect? cuadroDeRecorte(List<num> caja, int ancho, int alto, {double margen = 0.1}) {
  if (caja.length != 4 || ancho <= 0 || alto <= 0) return null;
  double px(num v, int total) => (v.clamp(0, 1000) / 1000) * total;
  final y0 = px(caja[0], alto), x0 = px(caja[1], ancho);
  final y1 = px(caja[2], alto), x1 = px(caja[3], ancho);
  if (x1 - x0 < 8 || y1 - y0 < 8) return null;

  final lado = min(
    max(x1 - x0, y1 - y0) * (1 + 2 * margen),
    min(ancho, alto).toDouble(),
  );
  final izquierda = ((x0 + x1) / 2 - lado / 2).clamp(0.0, ancho - lado);
  final arriba = ((y0 + y1) / 2 - lado / 2).clamp(0.0, alto - lado);
  return ui.Rect.fromLTWH(izquierda, arriba, lado, lado);
}

/// Recorta de la foto en [ruta] una miniatura por producto, según sus
/// [cajas], y las guarda como PNG pequeños en la carpeta temporal (donde
/// están las demás fotos, y de donde se borran cuando ningún alimento las
/// usa). Devuelve la ruta de cada recorte en el mismo orden, o `null` en los
/// que no tenían caja o no se pudieron hacer. La foto se decodifica una sola
/// vez para todos.
Future<List<String?>> recortarProductos(
  String ruta,
  List<List<num>?> cajas, {
  int tamano = 320,
}) async {
  final nada = List<String?>.filled(cajas.length, null);
  if (kIsWeb || cajas.every((c) => c == null)) return nada;
  ui.Image? imagen;
  try {
    final codec = await ui.instantiateImageCodec(await File(ruta).readAsBytes());
    imagen = (await codec.getNextFrame()).image;
    final carpeta = (await getTemporaryDirectory()).path;
    final marca = DateTime.now().microsecondsSinceEpoch;
    final destino = ui.Rect.fromLTWH(0, 0, tamano.toDouble(), tamano.toDouble());
    final pincel = ui.Paint()..filterQuality = ui.FilterQuality.medium;

    final salida = <String?>[];
    for (var i = 0; i < cajas.length; i++) {
      final caja = cajas[i];
      final cuadro = caja == null ? null : cuadroDeRecorte(caja, imagen.width, imagen.height);
      if (cuadro == null) {
        salida.add(null);
        continue;
      }
      final grabadora = ui.PictureRecorder();
      ui.Canvas(grabadora).drawImageRect(imagen, cuadro, destino, pincel);
      final recorte = await grabadora.endRecording().toImage(tamano, tamano);
      final png = await recorte.toByteData(format: ui.ImageByteFormat.png);
      recorte.dispose();
      if (png == null) {
        salida.add(null);
        continue;
      }
      final archivo = File('$carpeta/recorte_${marca}_$i.png');
      await archivo.writeAsBytes(png.buffer.asUint8List());
      salida.add(archivo.path);
    }
    return salida;
  } catch (e) {
    // Sin recortes la app sigue igual: se muestra el emoji del producto.
    debugPrint('No se pudieron recortar los productos: $e');
    return nada;
  } finally {
    imagen?.dispose();
  }
}
