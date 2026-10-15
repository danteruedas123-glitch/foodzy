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
| 2026-10-15 | ec6dd75 | Pruebas de `calcularDescuento` | `test/domain/descuento_receta_test.dart` | El descuento de la despensa no tenía pruebas | `flutter test test/domain/descuento_receta_test.dart` |

## Pruebas automáticas del área

| Archivo de prueba | Qué verifica | Estado |
| --- | --- | --- |
| `test/domain/recetas_parsear_test.dart` | Receta válida; objeto único en vez de lista; `alimento_id` inventado; cantidad usada limitada a lo disponible; cantidades 0/negativas/nulas; recetas sin ingredientes o pasos; elementos que no son objetos; valores por defecto; respuesta vacía; JSON de ida y vuelta | 11 pruebas, todas pasan |
| `test/domain/descuento_receta_test.dart` | Descuento por ingrediente; suma de ingredientes del mismo alimento; tope en lo disponible; ingredientes sin cantidad medible; ingredientes que no son de la despensa; receta vacía | 6 pruebas, todas pasan |

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

## Pendiente

- [x] Revisar `hoja_cocinar.dart`: ¿se descuenta de más cuando un alimento aparece dos veces? No.
- [x] Pruebas del descuento de ingredientes al cocinar.
- [ ] `hoja_cocinar.dart`: manejar errores en `_confirmar` (`try/catch/finally`) para no dejar la hoja bloqueada.
- [ ] Manejo de error cuando la IA no responde en recetas.
- [ ] Hogar: `unirse()` puede dejar a la persona en dos hogares si falla a mitad.
- [ ] Hogar: `salir()` deja hogares e invitaciones huérfanos cuando se va el único miembro.
- [ ] Reglas de Firestore: restringir qué puede modificar un miembro en `hogares`.
