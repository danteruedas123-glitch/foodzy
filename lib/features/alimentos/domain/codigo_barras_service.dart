import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final codigoBarrasServiceProvider = Provider<CodigoBarrasService>((ref) {
  return CodigoBarrasService();
});

/// Lo que se sabe de un producto a partir de su código de barras.
class ProductoCodigo {
  const ProductoCodigo({
    required this.codigo,
    required this.nombre,
    required this.categoria,
    this.cantidad,
    this.unidad,
  });

  final String codigo;
  final String nombre;
  final String categoria;

  /// Contenido neto de UN paquete y su unidad (g, kg, ml, L). Puede faltar.
  final double? cantidad;
  final String? unidad;
}

/// Consulta Open Food Facts, una base de datos abierta y gratuita de
/// productos alimenticios de todo el mundo.
class CodigoBarrasService {
  /// Devuelve el producto o `null` si el código no está en la base.
  /// Lanza una excepción si no hay conexión.
  Future<ProductoCodigo?> buscar(String codigo) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$codigo.json',
      {
        'fields': 'product_name,product_name_es,brands,quantity,'
            'product_quantity,product_quantity_unit,categories_tags',
      },
    );
    final r = await http
        .get(uri, headers: {'User-Agent': 'Foodzy/1.0 (proyectomovil123@gmail.com)'})
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw Exception('El servicio de productos respondió ${r.statusCode}.');
    }
    final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (json['status'] != 1) return null;
    final p = json['product'] as Map<String, dynamic>? ?? const {};

    final nombreBase = _texto(p['product_name_es']) ?? _texto(p['product_name']);
    if (nombreBase == null) return null;
    final marca = _texto(p['brands'])?.split(',').first.trim();
    final nombre = (marca != null &&
            marca.isNotEmpty &&
            !nombreBase.toLowerCase().contains(marca.toLowerCase()))
        ? '$nombreBase $marca'
        : nombreBase;

    final (cantidad, unidad) = _contenido(p);
    final tags = (p['categories_tags'] as List?)?.map((e) => '$e').toList() ?? const [];

    return ProductoCodigo(
      codigo: codigo,
      nombre: nombre,
      categoria: _categoria(tags),
      cantidad: cantidad,
      unidad: unidad,
    );
  }

  String? _texto(Object? v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Saca el contenido neto en g, kg, ml o L.
  (double?, String?) _contenido(Map<String, dynamic> p) {
    final num = double.tryParse('${p['product_quantity'] ?? ''}');
    final un = _texto(p['product_quantity_unit'])?.toLowerCase();
    if (num != null && num > 0 && un != null) {
      final r = _normalizar(num, un);
      if (r.$1 != null) return r;
    }
    final texto = _texto(p['quantity']);
    if (texto != null) {
      final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|l|oz)\b', caseSensitive: false)
          .firstMatch(texto);
      if (m != null) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
        if (v != null) return _normalizar(v, m.group(2)!.toLowerCase());
      }
    }
    return (null, null);
  }

  (double?, String?) _normalizar(double v, String unidad) {
    switch (unidad) {
      case 'g':
        return (v, 'g');
      case 'kg':
        return (v, 'kg');
      case 'ml':
        return (v, 'ml');
      case 'cl':
        return (v * 10, 'ml');
      case 'l':
        return (v, 'L');
      default:
        return (null, null);
    }
  }

  String _categoria(List<String> tags) {
    bool tiene(List<String> ps) => tags.any((t) => ps.any(t.contains));
    if (tiene(['dairies', 'milk', 'cheese', 'yogurt'])) return 'Lácteos';
    if (tiene(['meats', 'poultry', 'sausages'])) return 'Carnes';
    if (tiene(['fish', 'seafood'])) return 'Pescados';
    if (tiene(['fruits', 'vegetables', 'plant-based-foods'])) return 'Frutas y verduras';
    if (tiene(['beverages', 'waters', 'juices', 'sodas'])) return 'Bebidas';
    if (tiene(['breads', 'bakery', 'biscuits', 'cakes'])) return 'Panadería';
    if (tiene(['canned'])) return 'Enlatados';
    if (tiene(['cereals', 'pasta', 'rice', 'flours', 'legumes'])) return 'Cereales y granos';
    if (tiene(['snacks', 'chocolates', 'sweet'])) return 'Snacks y dulces';
    if (tiene(['sauces', 'condiments', 'spices', 'salt'])) return 'Salsas y condimentos';
    if (tiene(['frozen'])) return 'Congelados';
    return 'Otros';
  }
}
