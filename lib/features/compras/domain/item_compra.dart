/// Un renglón de la lista de compras.
class ItemCompra {
  const ItemCompra({
    required this.id,
    required this.nombre,
    this.cantidad,
    this.comprado = false,
    required this.creado,
  });

  factory ItemCompra.fromJson(Map<String, dynamic> json) => ItemCompra(
        id: json['id'].toString(),
        nombre: json['nombre'].toString(),
        cantidad: json['cantidad']?.toString(),
        comprado: json['comprado'] == true,
        creado: DateTime.tryParse('${json['creado']}') ?? DateTime.now(),
      );

  final String id;
  final String nombre;

  /// Texto libre opcional: "2 L", "1 kg", "3".
  final String? cantidad;
  final bool comprado;
  final DateTime creado;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        if (cantidad != null && cantidad!.isNotEmpty) 'cantidad': cantidad,
        'comprado': comprado,
        'creado': creado.toIso8601String(),
      };

  ItemCompra conComprado(bool valor) => ItemCompra(
        id: id,
        nombre: nombre,
        cantidad: cantidad,
        comprado: valor,
        creado: creado,
      );
}

/// Dónde se guarda la lista (en el teléfono o en la nube).
abstract interface class ListaCompraRepository {
  Future<List<ItemCompra>> obtener();
  Future<void> guardar(ItemCompra item);
  Future<void> eliminar(String id);
}
