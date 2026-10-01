import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foodzy/features/compras/domain/item_compra.dart';

/// Lista de compras compartida por el hogar.
class FirestoreListaCompraRepository implements ListaCompraRepository {
  FirestoreListaCompraRepository(this.hogarId);

  final String hogarId;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('hogares')
      .doc(hogarId)
      .collection('lista');

  @override
  Future<List<ItemCompra>> obtener() async {
    final s = await _col.get();
    return s.docs.map((d) => ItemCompra.fromJson(d.data())).toList();
  }

  /// Avisa cada vez que alguien cambia la lista.
  Stream<void> cambios() => _col.snapshots().map((_) {});

  @override
  Future<void> guardar(ItemCompra item) => _col.doc(item.id).set(item.toJson());

  @override
  Future<void> eliminar(String id) => _col.doc(id).delete();
}
