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

## Pruebas automáticas del área

| Archivo de prueba | Qué verifica | Estado |
| --- | --- | --- |
| `test/domain/recetas_parsear_test.dart` | Receta válida; objeto único en vez de lista; `alimento_id` inventado; cantidad usada limitada a lo disponible; cantidades 0/negativas/nulas; recetas sin ingredientes o pasos; elementos que no son objetos; valores por defecto; respuesta vacía; JSON de ida y vuelta | 11 pruebas, todas pasan |

Para correrlas: `flutter test`. Para revisar el código: `flutter analyze`.

## Problemas encontrados y decisiones

Cosas que se descubrieron mientras se trabajaba y cómo se resolvieron o por qué
se dejaron para después.

- **Ingredientes repetidos (sin verificar).** `parsear` limita la cantidad usada de
  cada ingrediente al total disponible, pero lo hace por separado. Si la IA devuelve
  dos ingredientes con el mismo `alimento_id`, la suma podría superar lo que hay en
  la despensa. Falta revisar `hoja_cocinar.dart`, donde se descuenta, para saber si
  es un problema real. Hallado el 2026-10-15 al escribir las pruebas.

## Pendiente

- [ ] Revisar `hoja_cocinar.dart`: ¿se descuenta de más cuando un alimento aparece dos veces en una receta?
- [ ] Pruebas del descuento de ingredientes al cocinar.
- [ ] Manejo de error cuando la IA no responde en recetas.
- [ ] Hogar: `unirse()` puede dejar a la persona en dos hogares si falla a mitad.
- [ ] Hogar: `salir()` deja hogares e invitaciones huérfanos cuando se va el único miembro.
- [ ] Reglas de Firestore: restringir qué puede modificar un miembro en `hogares`.
