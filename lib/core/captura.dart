import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// `true` si el dispositivo tiene una cámara que `image_picker` puede abrir.
bool get hayCamara =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Toma una foto con la cámara; en PC y web, donde no hay, abre el selector
/// de archivos. Devuelve null si el usuario cancela o algo falla.
Future<XFile?> capturarImagen(BuildContext context) async {
  final picker = ImagePicker();
  try {
    return await picker.pickImage(
      source: hayCamara ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 85,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la cámara: $e')),
      );
    }
    return null;
  }
}

Future<XFile?> elegirDeGaleria() =>
    ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
