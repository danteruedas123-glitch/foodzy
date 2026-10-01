import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/nube/data/firestore_alimentos.dart';

/// El grupo (familia, pareja, compañeros) que comparte una despensa.
class Hogar {
  const Hogar({required this.id, required this.codigo, required this.miembros});

  final String id;

  /// Código corto que se comparte para invitar a otra persona.
  final String codigo;
  final int miembros;
}

class HogarError implements Exception {
  const HogarError(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Hogar de la persona con sesión iniciada. Cada cuenta nueva tiene el suyo
/// propio; puede unirse al de otra persona con un código.
class HogarNotifier extends AsyncNotifier<Hogar?> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Future<Hogar?> build() async {
    final auth = ref.watch(authProvider);
    if (!Nube.disponible || !auth.esNube) return null;
    return _asegurar(auth);
  }

  Future<Hogar> _asegurar(AuthState auth) async {
    final uid = auth.uid!;
    final snap = await _db.collection('usuarios').doc(uid).get();
    final hogarId = snap.data()?['hogarId']?.toString();
    if (hogarId != null) {
      final h = await _db.collection('hogares').doc(hogarId).get();
      final miembros = (h.data()?['miembros'] as List?)?.cast<String>() ?? const [];
      if (h.exists && miembros.contains(uid)) {
        return Hogar(
          id: hogarId,
          codigo: h.data()?['codigo']?.toString() ?? '',
          miembros: miembros.length,
        );
      }
    }
    return _crear(auth);
  }

  String _codigoAleatorio() {
    const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => letras[r.nextInt(letras.length)]).join();
  }

  Future<Hogar> _crear(AuthState auth) async {
    final uid = auth.uid!;
    var codigo = _codigoAleatorio();
    for (var i = 0; i < 5; i++) {
      final existe = await _db.collection('invitaciones').doc(codigo).get();
      if (!existe.exists) break;
      codigo = _codigoAleatorio();
    }
    final hogarRef = _db.collection('hogares').doc();
    final lote = _db.batch();
    lote.set(hogarRef, {
      'miembros': [uid],
      'codigo': codigo,
      'creadoPor': uid,
      'creado': FieldValue.serverTimestamp(),
    });
    lote.set(_db.collection('invitaciones').doc(codigo), {'hogarId': hogarRef.id});
    lote.set(
      _db.collection('usuarios').doc(uid),
      {'hogarId': hogarRef.id, 'nombre': auth.userName, 'email': auth.email},
      SetOptions(merge: true),
    );
    await lote.commit();
    return Hogar(id: hogarRef.id, codigo: codigo, miembros: 1);
  }

  /// Une a la persona al hogar de [codigo]. Con [copiarMisDatos] lleva su
  /// despensa actual al hogar nuevo.
  Future<void> unirse(String codigo, {bool copiarMisDatos = false}) async {
    final auth = ref.read(authProvider);
    final actual = state.value;
    if (!auth.esNube || actual == null) throw const HogarError('Inicia sesión primero.');

    final limpio = codigo.trim().toUpperCase();
    if (limpio.length < 4) throw const HogarError('Escribe el código completo.');

    final inv = await _db.collection('invitaciones').doc(limpio).get();
    final nuevoId = inv.data()?['hogarId']?.toString();
    if (!inv.exists || nuevoId == null) {
      throw const HogarError('Ese código no existe. Revísalo con quien te invitó.');
    }
    if (nuevoId == actual.id) throw const HogarError('Ya perteneces a ese hogar.');

    // Se entra primero al hogar nuevo (lo permiten las reglas de seguridad).
    await _db.collection('hogares').doc(nuevoId).update({
      'miembros': FieldValue.arrayUnion([auth.uid]),
    });

    if (copiarMisDatos) {
      final viejos = await FirestoreAlimentosRepository(actual.id).obtenerTodos();
      await FirestoreAlimentosRepository(nuevoId).guardarVarios(viejos);
    }

    await _db.collection('usuarios').doc(auth.uid).set({'hogarId': nuevoId}, SetOptions(merge: true));
    // Se sale del hogar anterior.
    await _db.collection('hogares').doc(actual.id).update({
      'miembros': FieldValue.arrayRemove([auth.uid]),
    });

    ref.invalidateSelf();
    await future;
  }

  /// Sale del hogar compartido y vuelve a tener uno propio, vacío.
  Future<void> salir() async {
    final auth = ref.read(authProvider);
    final actual = state.value;
    if (!auth.esNube || actual == null) return;
    final nuevo = await _crear(auth);
    await _db.collection('hogares').doc(actual.id).update({
      'miembros': FieldValue.arrayRemove([auth.uid]),
    });
    state = AsyncData(nuevo);
  }
}

final hogarProvider = AsyncNotifierProvider<HogarNotifier, Hogar?>(HogarNotifier.new);
