# Bitácora: Recetas, lista de compras y hogar

Registro de los cambios del área **Recetas y Hogar** de Foodzy. Sirve para que
cualquier persona del equipo (o quien revise el proyecto) sepa qué se cambió,
dónde, por qué y cómo comprobarlo.

- **Responsable del área:** Keiver Santiago (GitHub: KsantyHA)
- **Rama de trabajo:** `feat/recetas-confiables-y-hogar-seguro`
- **Última actualización:** 2026-10-15

## Alcance del área

| Tema | Carpetas y archivos principales |
| --- | --- |
| Recetas con IA y menú semanal | `lib/features/recetas/` (`recetas_service.dart`, `pantalla_recetas.dart`, `hoja_cocinar.dart`) |
| Lista de compras | `lib/features/compras/` |
| Hogar compartido | `lib/features/nube/hogar_provider.dart`, `lib/core/nube.dart` |
| Reglas de seguridad | `firestore.rules` |

## Cómo se llena esta bitácora

Una fila por cada cambio terminado, el mismo día en que se hace. Un cambio
corresponde a un commit o a un Pull Request. No se registran cosas que no se
hicieron.

## Registro de cambios

| Fecha | Commit / PR | Qué cambió | Archivos | Por qué | Cómo probarlo |
| --- | --- | --- | --- | --- | --- |
| 2026-10-15 | d15edde | `RecetasService._parsear` pasa a ser pública con `@visibleForTesting` (`parsear`) para poder probarla; no cambia su lógica | `lib/features/recetas/domain/recetas_service.dart` | Era privada y no había forma de probar cómo se interpreta la respuesta de la IA | `flutter test` |
| 2026-10-15 | d15edde | Pruebas de `parsear` y de la ida y vuelta a JSON de `Receta` | `test/domain/recetas_parsear_test.dart` | La lectura de la respuesta de Gemini no tenía ninguna prueba | `flutter test test/domain/recetas_parsear_test.dart` |
| 2026-10-15 | 657fd71 | Se crea esta bitácora con el alcance del área y los dos primeros cambios | `docs/bitacora-recetas-y-hogar.md` | Dejar constancia de qué se hace, dónde y por qué | Leer este archivo |
| 2026-10-15 | ec6dd75 | El cálculo de qué se descuenta al cocinar sale del widget a una función `calcularDescuento`; `hoja_cocinar.dart` ahora la usa. El comportamiento no cambia | `lib/features/recetas/domain/descuento_receta.dart`, `lib/features/recetas/presentation/widgets/hoja_cocinar.dart` | La lógica estaba dentro de `initState` de una pantalla y no se podía probar | `flutter test`; cocinar una receta en la app y ver que se descuenta igual |
| 2026-10-15 | 9762f57 | **Nueva función:** botón "Añadir lo que falta a mi lista" en cada receta que tiene ingredientes por conseguir. Pasa esos ingredientes (con su cantidad) a la lista de compras, omite los que ya están, y avisa cuántos añadió. Funciona en Sugeridas, Favoritas, Semana y en la alerta de vencimiento porque vive en la tarjeta de receta | `lib/features/recetas/presentation/widgets/receta_card.dart`, `lib/features/compras/presentation/lista_compra_provider.dart` | Las recetas mostraban lo que faltaba solo como texto; la persona tenía que copiarlo a mano a la lista. Si hay hogar compartido, la lista la ve toda la familia | Generar recetas con productos que no tengas, abrir una y tocar el botón; ir a Lista de compras y ver los productos. Tocarlo otra vez: debe decir que ya estaban |
| 2026-10-15 | 9762f57 | `ListaCompraNotifier.agregar` ahora devuelve `true` si añadió el producto; nuevo `agregarVarios`; los ids de producto se generan siempre distintos | `lib/features/compras/presentation/lista_compra_provider.dart` | Poder contar cuántos eran nuevos y evitar ids repetidos al añadir varios seguidos | `flutter test test/domain/lista_compra_agregar_test.dart` |
| 2026-10-15 | 9762f57 | Pruebas de `agregarVarios` | `test/domain/lista_compra_agregar_test.dart` | La lista de compras no tenía pruebas | `flutter test test/domain/lista_compra_agregar_test.dart` |
| 2026-10-15 | ec6dd75 | Pruebas de `calcularDescuento` | `test/domain/descuento_receta_test.dart` | El descuento de la despensa no tenía pruebas | `flutter test test/domain/descuento_receta_test.dart` |
| 2026-10-15 | 46bedc0 | La lógica del hogar sale de `HogarNotifier` a tres piezas: `HogarService` (las reglas), `HogarRepository` (la interfaz) y `FirestoreHogarRepository` (Firestore). La app se usa igual; `hogar_provider.dart` sigue exportando `Hogar` y `HogarError`, así que los demás archivos no cambian | `lib/features/nube/hogar.dart`, `lib/features/nube/data/firestore_hogar.dart`, `lib/features/nube/hogar_provider.dart` | La lógica estaba pegada a Firestore y no se podía probar sin Firebase | `flutter test test/domain/hogar_service_test.dart`; en la app, crear cuenta, ver el código del hogar y unirse con otro |
| 2026-10-15 | 46bedc0 | **Arreglo en `unirse`:** si falla algo después de entrar al hogar nuevo (copiar la despensa o guardar el hogar), se deshace la entrada y se muestra "No pude unirte al hogar. Todo quedó como estaba". Antes la persona quedaba como miembro de los dos hogares | `lib/features/nube/hogar.dart` | Evitar un estado a medias: figurar en un hogar ajeno sin haberse unido de verdad | Pruebas "si falla la copia" y "si falla guardar su hogar nuevo" |
| 2026-10-15 | 46bedc0 | **Arreglo en `salir`:** si la persona es la única del hogar, no hace nada. Antes creaba un hogar nuevo y dejaba el anterior abandonado | `lib/features/nube/hogar.dart` | No dejar hogares huérfanos. La pantalla ya ocultaba el botón en ese caso, pero la función no se protegía sola | Prueba "si es la única persona del hogar" |
| 2026-10-15 | 46bedc0 | Pruebas del servicio del hogar | `test/domain/hogar_service_test.dart` | La lógica del hogar no tenía ninguna prueba | `flutter test test/domain/hogar_service_test.dart` |

## Pruebas automáticas del área

| Archivo de prueba | Qué verifica | Estado |
| --- | --- | --- |
| `test/domain/recetas_parsear_test.dart` | Receta válida; objeto único en vez de lista; `alimento_id` inventado; cantidad usada limitada a lo disponible; cantidades 0/negativas/nulas; recetas sin ingredientes o pasos; elementos que no son objetos; valores por defecto; respuesta vacía; JSON de ida y vuelta | 11 pruebas, todas pasan |
| `test/domain/descuento_receta_test.dart` | Descuento por ingrediente; suma de ingredientes del mismo alimento; tope en lo disponible; ingredientes sin cantidad medible; ingredientes que no son de la despensa; receta vacía | 6 pruebas, todas pasan |
| `test/domain/lista_compra_agregar_test.dart` | Añadir varios; no repetir lo que ya está; ignorar mayúsculas y tildes; volver a añadir lo ya comprado; no repetir dentro del mismo lote; nombres vacíos; ids distintos | 7 pruebas, todas pasan |
| `test/domain/hogar_service_test.dart` | Crear o reutilizar el hogar; unirse (cambio de hogar, código en minúsculas, errores claros, copia de despensa solo si se pide); deshacer la entrada si falla la copia o el guardado; seguir en el hogar nuevo si no puede salir del anterior; salir; no hacer nada si es la única persona | 12 pruebas, todas pasan |

Para correrlas: `flutter test`. Para revisar el código: `flutter analyze`.

## Problemas encontrados y decisiones

Cosas que se descubrieron mientras se trabajaba y cómo se resolvieron o por qué
se dejaron para después.

- **Ingredientes repetidos: descartado.** Se sospechó que dos ingredientes con el
  mismo `alimento_id` podían descontar más de lo que hay. Al revisar
  `hoja_cocinar.dart` se vio que ya los suma y limita el total a lo disponible, así
  que no era un problema. Ahora queda cubierto con pruebas en
  `descuento_receta_test.dart`.
- **`_confirmar` sin manejo de errores (confirmado en el código).** En
  `hoja_cocinar.dart`, si `actualizar` falla a mitad (por ejemplo sin conexión en
  modo nube), una parte ya se descontó y la hoja queda bloqueada porque
  `_guardando` nunca vuelve a `false`. Hallado el 2026-10-15; pendiente de arreglar.

- **Decisión: salir del hogar anterior es "lo mejor posible".** Después de entrar al
  hogar nuevo, si falla quitar a la persona del anterior no se revierte nada: ya usa el
  hogar nuevo. Lo contrario la dejaría sin poder unirse por un detalle menor. Queda
  la posibilidad de figurar todavía como miembro del hogar viejo.
- **Código de invitación de un hogar abandonado sigue activo (sin arreglar).** Si la
  única persona de un hogar se une a otro, el hogar viejo queda con 0 miembros pero su
  código sigue funcionando, y las reglas de `firestore.rules` dejan que alguien se
  añada a un hogar vacío. Esa persona vería lo que quedó guardado allí. Arreglarlo
  exige cambiar las reglas, y no se pueden probar aquí (hace falta el simulador de
  Firebase), así que se deja como pendiente.
- **`salir` en la pantalla no maneja errores.** `pantalla_configuracion.dart` llama a
  `salir()` sin `try/catch`. Esa pantalla la está rediseñando Kevin, así que se
  arregla cuando él haga merge para no pisarnos.

## Pendiente

- [x] Revisar `hoja_cocinar.dart`: ¿se descuenta de más cuando un alimento aparece dos veces? No.
- [x] Pruebas del descuento de ingredientes al cocinar.
- [ ] `hoja_cocinar.dart`: manejar errores en `_confirmar` (`try/catch/finally`) para no dejar la hoja bloqueada.
- [ ] Manejo de error cuando la IA no responde en recetas.
- [x] Hogar: `unirse()` puede dejar a la persona en dos hogares si falla a mitad.
- [x] Hogar: `salir()` crea un hogar nuevo y deja el anterior abandonado cuando se va el único miembro.
- [ ] Hogar: el código de un hogar abandonado (por `unirse`) sigue activo. Requiere cambiar `firestore.rules`.
- [ ] Reglas de Firestore: restringir qué puede modificar un miembro en `hogares` (hoy cualquier miembro puede reescribir la lista de miembros y el código). Probar en el simulador de reglas de Firebase antes de publicar.
- [ ] `pantalla_configuracion.dart`: manejar errores de `salir()` (coordinar con Kevin).
- [ ] Sacar la tarjeta del hogar de `pantalla_configuracion.dart` a `features/nube/tarjeta_hogar.dart` (después del merge de Kevin).
