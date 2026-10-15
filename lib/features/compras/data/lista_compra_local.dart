import 'dart:convert';

import 'package:foodzy/features/compras/domain/item_compra.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lista de compras guardada solo en este teléfono.
class ListaCompraLocal implements ListaCompraRepository {
  ListaCompraLocal(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'lista_compra';

  List<ItemCompra> _leer() {
    final texto = _prefs.getString(_key);
    if (texto == null) return [];
    try {
      return (jsonDecode(texto) as List)
          .map((e) => ItemCompra.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _escribir(List<ItemCompra> items) =>
      _prefs.setString(_key, jsonEncode(items.map((i) => i.toJson()).toList()));

  @override
  Future<List<ItemCompra>> obtener() async => _leer();

  @override
  Future<void> guardar(ItemCompra item) async {
    final items = _leer();
    final i = items.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      items[i] = item;
    } else {
      items.add(item);
    }
    await _escribir(items);
  }

  @override
  Future<void> eliminar(String id) async {
    final items = _leer()..removeWhere((e) => e.id == id);
    await _escribir(items);
  }
}
