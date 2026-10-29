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

  List<ItemCompra> _lista(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => ItemCompra.fromJson(d.data())).toList();

  @override
  Future<List<ItemCompra>> obtener() async => _lista(await _col.get());

  /// Emite la lista completa cada vez que alguien del hogar la cambia. Trae
  /// los datos del propio evento, sin volver a leer la colección.
  Stream<List<ItemCompra>> flujo() => _col.snapshots().map(_lista);

  @override
  Future<void> guardar(ItemCompra item) => _col.doc(item.id).set(item.toJson());

  @override
  Future<void> eliminar(String id) => _col.doc(id).delete();

  /// Guarda varios renglones en una sola escritura (un solo aviso a los
  /// demás teléfonos del hogar en vez de uno por renglón).
  Future<void> guardarVarios(Iterable<ItemCompra> items) {
    final lote = FirebaseFirestore.instance.batch();
    for (final i in items) {
      lote.set(_col.doc(i.id), i.toJson());
    }
    return lote.commit();
  }

  /// Borra varios renglones en una sola escritura.
  Future<void> eliminarVarios(Iterable<String> ids) {
    final lote = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      lote.delete(_col.doc(id));
    }
    return lote.commit();
  }
}
