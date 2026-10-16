import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foodzy/features/nube/hogar.dart';

/// Hogares guardados en Firestore (`hogares`, `invitaciones` y `usuarios`).
class FirestoreHogarRepository implements HogarRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Future<Hogar?> hogarDe(String uid) async {
    final snap = await _db.collection('usuarios').doc(uid).get();
    final hogarId = snap.data()?['hogarId']?.toString();
    if (hogarId == null) return null;

    final h = await _db.collection('hogares').doc(hogarId).get();
    final miembros = (h.data()?['miembros'] as List?)?.cast<String>() ?? const [];
    if (!h.exists || !miembros.contains(uid)) return null;
    return Hogar(
      id: hogarId,
      codigo: h.data()?['codigo']?.toString() ?? '',
      miembros: miembros.length,
    );
  }

  String _codigoAleatorio() {
    const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => letras[r.nextInt(letras.length)]).join();
  }

  @override
  Future<Hogar> crear({required String uid, String? nombre, String? email}) async {
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
      {'hogarId': hogarRef.id, 'nombre': nombre, 'email': email},
      SetOptions(merge: true),
    );
    await lote.commit();
    return Hogar(id: hogarRef.id, codigo: codigo, miembros: 1);
  }

  @override
  Future<String?> hogarIdPorCodigo(String codigo) async {
    final inv = await _db.collection('invitaciones').doc(codigo).get();
    if (!inv.exists) return null;
    return inv.data()?['hogarId']?.toString();
  }

  @override
  Future<void> agregarMiembro(String hogarId, String uid) =>
      _db.collection('hogares').doc(hogarId).update({
        'miembros': FieldValue.arrayUnion([uid]),
      });

  @override
  Future<void> quitarMiembro(String hogarId, String uid) =>
      _db.collection('hogares').doc(hogarId).update({
        'miembros': FieldValue.arrayRemove([uid]),
      });

  @override
  Future<void> asignar(String uid, String hogarId) =>
      _db.collection('usuarios').doc(uid).set({'hogarId': hogarId}, SetOptions(merge: true));
}
