import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/codigo_barras_service.dart';

void main() {
  // Hallazgo de seguridad H-10: el código va dentro de la ruta de la URL.
  group('el código de barras se valida antes de llamar a Open Food Facts', () {
    final servicio = CodigoBarrasService();

    for (final codigo in [
      'abc/../../v0/product/1',
      '../../../cgi/search.pl?x=1#a',
      '7702004003508/../1',
      '',
      '12345',
      '123456789012345',
    ]) {
      test('rechaza "$codigo" sin hacer ninguna petición', () async {
        expect(await servicio.buscar(codigo), isNull);
      });
    }
  });
}
