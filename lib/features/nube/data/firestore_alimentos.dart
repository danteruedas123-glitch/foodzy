import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/alimentos_repository.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

/// Despensa guardada en Firestore, compartida por todos los miembros del
/// hogar. Firestore guarda una copia en el teléfono, así que sigue
/// funcionando sin internet y se sincroniza al volver la conexión.
class FirestoreAlimentosRepository implements AlimentosRepository {
  FirestoreAlimentosRepository(this.hogarId);

  final String hogarId;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('hogares')
      .doc(hogarId)
      .collection('alimentos');

  Alimento? _leer(DocumentSnapshot<Map<String, dynamic>> d) {
    final datos = d.data();
    if (datos == null) return null;
    try {
      return Alimento.fromJson(datos);
    } catch (_) {
      return null; // un documento dañado no debe tumbar toda la lista
    }
  }

  List<Alimento> _lista(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(_leer).whereType<Alimento>().toList();

  @override
  Future<List<Alimento>> obtenerTodos() async => _lista(await _col.get());

  /// Emite la despensa completa cada vez que alguien del hogar la cambia.
  Stream<List<Alimento>> flujo() => _col.snapshots().map(_lista);

  @override
  Future<Alimento?> obtenerPorId(String id) async => _leer(await _col.doc(id).get());

  @override
  Future<List<Alimento>> obtenerDisponibles() async {
    final todos = await obtenerTodos();
    return todos.where((a) => a.estado is Disponible).toList();
  }

  @override
  Future<void> guardar(Alimento alimento) => _col.doc(alimento.id).set({
        ...alimento.toJson(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> eliminar(String id) => _col.doc(id).delete();

  /// Copia varios alimentos de una vez (migración de datos locales).
  Future<void> guardarVarios(Iterable<Alimento> alimentos) async {
    final lista = alimentos.toList();
    for (var i = 0; i < lista.length; i += 400) {
      final lote = FirebaseFirestore.instance.batch();
      for (final a in lista.skip(i).take(400)) {
        lote.set(_col.doc(a.id), {
          ...a.toJson(),
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }
      await lote.commit();
    }
  }
}
