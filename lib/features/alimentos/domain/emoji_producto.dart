import 'package:foodzy/features/alimentos/domain/historial.dart';

/// Emoji por producto, para que la miniatura diga qué es ("Banano" → 🍌) y
/// no solo su categoría. Se busca por el comienzo de cada palabra del nombre,
/// sin tildes ni mayúsculas; un prefijo que termina en punto debe ser la
/// palabra completa. El orden importa: va primero lo más específico ("salsa
/// de tomate" es salsa, no tomate; "panela" no es pan). Sin ñ ni tildes:
/// el nombre se compara ya normalizado.
const _porNombre = <(List<String>, String)>[
  // Bebidas, salsas y preparados (antes que sus ingredientes).
  (['jugo', 'zumo', 'nectar'], '🧃'),
  (['gaseosa', 'refresco', 'cola.', 'soda'], '🥤'),
  (['cerveza'], '🍺'),
  (['vino'], '🍷'),
  (['agua.'], '💧'),
  (['cafe', 'tinto.'], '☕'),
  (['te.', 'aromatica', 'infusion'], '🍵'),
  (['salsa', 'ketchup', 'mayonesa', 'mostaza'], '🥫'),
  (['sopa', 'caldo', 'consome'], '🍲'),
  (['helado'], '🍦'),
  (['yogur', 'kumis', 'avena.'], '🥛'),
  (['cereal', 'granola', 'hojuela'], '🥣'),
  (['galleta'], '🍪'),
  (['chocolate', 'chocolatina', 'cacao'], '🍫'),
  (['panela', 'azucar', 'dulce', 'caramelo', 'bocadillo', 'arequipe'], '🍬'),
  (['miel'], '🍯'),
  (['sal.'], '🧂'),
  (['aceite', 'oliva'], '🫒'),
  (['pizza'], '🍕'),
  (['hamburguesa'], '🍔'),
  (['empanada'], '🥟'),
  (['crispeta', 'palomita', 'popcorn'], '🍿'),
  (['mani', 'cacahuate'], '🥜'),
  (['nuez', 'almendra', 'pistacho', 'maranon'], '🌰'),
  // Panadería.
  (['croissant', 'cruasan'], '🥐'),
  (['baguette'], '🥖'),
  (['arepa', 'tortilla'], '🫓'),
  (['pan.', 'pancito', 'tostada', 'mogolla', 'almojabana', 'bunuelo'], '🍞'),
  // Lácteos y huevos.
  (['leche'], '🥛'),
  (['queso', 'cuajada', 'quesillo'], '🧀'),
  (['mantequilla', 'margarina'], '🧈'),
  (['huevo'], '🥚'),
  // Carnes y pescados.
  (['pollo', 'pechuga', 'muslo', 'ala.', 'alas.', 'pavo'], '🍗'),
  (['tocineta', 'tocino', 'bacon'], '🥓'),
  (['salchicha', 'perro.'], '🌭'),
  (['chorizo', 'morcilla', 'longaniza', 'butifarra', 'costilla'], '🍖'),
  (['carne', 'res.', 'lomo', 'cerdo', 'molida', 'bistec', 'chuleta', 'jamon', 'mortadela', 'salami'], '🥩'),
  (['camaron', 'langostino', 'marisco'], '🦐'),
  (['pescado', 'tilapia', 'salmon', 'atun', 'sardina', 'trucha', 'mojarra', 'bagre'], '🐟'),
  // Frutas.
  (['banano', 'banana', 'platano', 'guineo'], '🍌'),
  (['manzana'], '🍎'),
  (['pera.', 'peras.'], '🍐'),
  (['naranja', 'mandarina'], '🍊'),
  (['limon'], '🍋'),
  (['uva.', 'uvas.'], '🍇'),
  (['fresa', 'frutilla'], '🍓'),
  (['sandia', 'patilla'], '🍉'),
  (['pina'], '🍍'),
  (['mango'], '🥭'),
  (['kiwi'], '🥝'),
  (['durazno', 'melocoton'], '🍑'),
  (['cereza'], '🍒'),
  (['coco.'], '🥥'),
  (['mora.', 'moras.', 'arandano'], '🫐'),
  (['melon'], '🍈'),
  (['aguacate', 'palta'], '🥑'),
  // Verduras.
  (['tomate'], '🍅'),
  (['zanahoria'], '🥕'),
  (['papa.', 'papas.', 'patata'], '🥔'),
  (['cebolla', 'cebollin'], '🧅'),
  (['ajo.', 'ajos.'], '🧄'),
  (['brocoli', 'coliflor'], '🥦'),
  (['lechuga', 'espinaca', 'repollo', 'acelga', 'cilantro', 'perejil', 'apio', 'col.'], '🥬'),
  (['pepino', 'calabacin', 'zucchini'], '🥒'),
  (['maiz', 'mazorca', 'choclo'], '🌽'),
  (['pimenton', 'pimiento'], '🫑'),
  (['aji.', 'chile', 'jalapeno'], '🌶️'),
  (['champinon', 'hongo'], '🍄'),
  (['arveja', 'habichuela', 'ejote'], '🫛'),
  (['frijol', 'frejol', 'lenteja', 'garbanzo'], '🫘'),
  // Granos y pastas.
  (['arroz'], '🍚'),
  (['pasta', 'espagueti', 'spaghetti', 'fideo', 'macarron', 'lasana'], '🍝'),
  (['harina'], '🌾'),
  (['lata.', 'enlatado', 'conserva'], '🥫'),
];

/// Emoji del producto según su nombre, o `null` si no se reconoce.
String? emojiPorNombre(String nombre) {
  final palabras = claveNombre(nombre).split(' ');
  for (final (prefijos, emoji) in _porNombre) {
    for (final p in prefijos) {
      final exacta = p.endsWith('.');
      final buscado = exacta ? p.substring(0, p.length - 1) : p;
      for (final palabra in palabras) {
        if (exacta ? palabra == buscado : palabra.startsWith(buscado)) return emoji;
      }
    }
  }
  return null;
}
