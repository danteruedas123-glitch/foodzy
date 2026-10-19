# Bitácora: Despensa

Registro de los cambios del área **Despensa** de Foodzy. Sirve para que
cualquier persona del equipo (o quien revise el proyecto) sepa qué se cambió,
dónde, por qué y cómo comprobarlo.

- **Responsable del área:** Sebastian
- **Rama de trabajo:** `feat/despensa-confiable`
- **Última actualización:** 2026-10-18

## Alcance del área

| Tema | Carpetas y archivos principales |
| --- | --- |
| Modelo del alimento | `lib/features/alimentos/domain/` (`alimento.dart`, `cantidad.dart`, `estado_alimento.dart`) |
| Lista de la despensa, búsqueda y filtros | `pantalla_alimentos.dart`, `alimentos_provider.dart`, `busqueda.dart`, `alimento_card.dart`, `estado_visual.dart` |
| Detalle, consumir y desechar | `pantalla_detalle.dart`, `consumo.dart` |
| Sacar comida (retiro) | `pantalla_retiro.dart`, `habitos_provider.dart` |
| Historial | `historial.dart`, `pantalla_historial.dart` |
| Estadísticas | `estadisticas.dart`, `pantalla_estadisticas.dart` |
| Por reponer | `pantalla_por_reponer.dart`, `reposicion_provider.dart` |
| Utilidades | `lib/core/formato.dart`, `lib/core/json.dart`, `lib/core/comparaciones.dart` |

Las pantallas y providers están en `lib/features/alimentos/presentation/` y la
lógica (sin pantallas) en `lib/features/alimentos/domain/`.

## Cómo se llena esta bitácora

Una fila por cada cambio terminado. Un cambio corresponde a un commit o a un
Pull Request. No se registran cosas que no se hicieron.

## Registro de cambios

| Fecha | Commit / PR | Qué cambió | Archivos | Por qué | Cómo probarlo |
| --- | --- | --- | --- | --- | --- |
| 2026-10-18 | 3e893bb | Se crea esta bitácora con el alcance del área y lo pendiente | `docs/bitacora-despensa.md` | Dejar constancia de qué se hace, dónde y por qué | Leer este archivo |
| 2026-10-18 | a9a265c | **Una sola cuenta para consumir.** Nueva función `consumir(alimento, usado, ahora)`: resta lo usado, redondea a 3 decimales y, si no queda nada, lo marca como consumido. La usan el detalle y "Sacar comida" | `lib/features/alimentos/domain/consumo.dart`, `pantalla_detalle.dart`, `pantalla_retiro.dart` | Las dos pantallas hacían la misma cuenta por separado. El detalle no redondeaba y guardaba cantidades como `0.30000000000000004` (lo que da `1 - 0.7` en el computador) | `flutter test test/domain/consumo_test.dart`; en la app, consumir 0.7 de 1 kg desde el detalle: debe quedar 0.3 kg |
| 2026-10-18 | a9a265c | Pruebas de `consumir` | `test/domain/consumo_test.dart` | El consumo no tenía pruebas | `flutter test test/domain/consumo_test.dart` |
| 2026-10-18 | d9fe123 | **Cantidades bien escritas.** El detalle dice "1 kg" en vez de "1.0 kg" (también en "Tienes … ¿Cuánto vas a consumir?") y la tarjeta muestra "0.25 kg" en vez de redondearlo a "0.3 kg". Ambos usan `fmtCantidad`, que ya existía | `pantalla_detalle.dart`, `alimento_card.dart` | Se mostraban los números tal cual o redondeados a un decimal | Abrir un alimento de 1 kg y uno de 0.25 kg; `flutter test test/widgets/alimento_card_test.dart` |
| 2026-10-18 | d9fe123 | Pruebas de `fmtNum`, `fmtCantidad` y `pasoPara`, y primera prueba de widget de la tarjeta | `test/domain/formato_test.dart`, `test/widgets/alimento_card_test.dart` | `formato.dart` no tenía pruebas | `flutter test` |
| 2026-10-18 | c7d3a98 | **Búsqueda sin tildes.** Nueva función `coincideBusqueda`: compara sin mayúsculas, tildes ni espacios de más, por nombre o categoría. El filtro de la despensa la usa | `lib/features/alimentos/domain/busqueda.dart`, `alimentos_provider.dart` | "lacteos" no encontraba "Lácteos" y "jamon" no encontraba "Jamón"; en el teléfono es común escribir sin tildes | Buscar "lacteos" en la despensa; `flutter test test/domain/busqueda_test.dart` |
| 2026-10-18 | c7d3a98 | Pruebas de la búsqueda | `test/domain/busqueda_test.dart` | La búsqueda no tenía pruebas | `flutter test test/domain/busqueda_test.dart` |
| 2026-10-18 | 7505ce2 | **Estadísticas agrupan bien.** "Lo que más se perdió" y "En qué gastas" juntan el mismo producto o categoría aunque se escriba distinto ("Leche" y "leche ", "Lácteos" y "lacteos"). Se muestra el primer nombre que aparezca | `lib/features/alimentos/domain/estadisticas.dart` | La IA no siempre escribe igual el mismo producto y salían repetidos, cada uno con una parte del dinero | `flutter test test/domain/estadisticas_test.dart` (con el código anterior fallaban las 2 pruebas nuevas) |
| 2026-10-18 | 7505ce2 | 2 pruebas nuevas en el archivo de estadísticas | `test/domain/estadisticas_test.dart` | Cubrir el arreglo | `flutter test test/domain/estadisticas_test.dart` |
| 2026-10-18 | 9a836c9 | **Deshacer al consumir o desechar.** Desde el detalle, después de "Consumir" o "Desechar" aparece un aviso que dice qué pasó ("Usaste 1 u de Huevos. Quedan 5 u.") con el botón "Deshacer", que deja el alimento exactamente como estaba | `pantalla_detalle.dart` | "Desechar" no pedía confirmación y no había forma de volver atrás si se tocaba por error | Desechar algo y tocar "Deshacer": debe volver a la despensa; `flutter test test/widgets/pantalla_detalle_test.dart` |
| 2026-10-18 | 9a836c9 | Pruebas de widget del detalle: desechar y deshacer, consumir una parte y deshacer, consumir lo último, cancelar | `test/widgets/pantalla_detalle_test.dart` | El detalle no tenía pruebas | `flutter test test/widgets/pantalla_detalle_test.dart` |
| 2026-10-18 | 2717bbe | **La nube ya no descarta los errores en silencio** (pendiente que dejó Keiver). Si Firestore rechaza un guardado o un borrado, se deja un aviso en `avisoGuardadoProvider` y se vuelve a leer la despensa para no mostrar algo que no quedó guardado. La pestaña Despensa muestra el aviso | `alimentos_provider.dart`, `pantalla_alimentos.dart` | Antes `.catchError((_) {})` tiraba el error y la persona no se enteraba | `flutter test test/domain/alimentos_nube_test.dart` |
| 2026-10-18 | 2717bbe | Pruebas con una nube falsa que puede rechazar cambios | `test/domain/alimentos_nube_test.dart` | Probar el caso sin necesitar Firebase | `flutter test test/domain/alimentos_nube_test.dart` |

## Pruebas automáticas del área

| Archivo de prueba | Qué verifica | Estado |
| --- | --- | --- |
| `test/domain/alimento_test.dart` | Ida y vuelta a JSON, errores claros al leer, origen de la fecha, igualdad, reglas de negocio | Ya existía, pasa |
| `test/domain/estadisticas_test.dart` | Gasto del mes por categoría, desperdicio proporcional, porcentaje, últimos 6 meses; mismo producto o categoría escritos distinto | 7 pruebas (2 nuevas), todas pasan |
| `test/domain/consumo_test.dart` | Usar una parte; redondeo (`1 - 0.7`); usar todo o más de lo que hay; restos minúsculos; conserva unidad, precio y fechas | 7 pruebas, todas pasan |
| `test/domain/formato_test.dart` | Números sin `.0`; dos decimales; el error de los decimales no se ve; número con unidad; pasos del selector por unidad | 7 pruebas, todas pasan |
| `test/domain/busqueda_test.dart` | Sin tildes, sin mayúsculas, espacios de más, con tilde, lo que no está, buscador vacío | 7 pruebas, todas pasan |
| `test/domain/alimentos_nube_test.dart` | La nube acepta: sin aviso; rechaza un cambio o un borrado: avisa y vuelve a lo guardado; dos fallos, dos avisos | 4 pruebas, todas pasan |
| `test/widgets/alimento_card_test.dart` | La tarjeta muestra "0.25 kg" y "2 u" | 2 pruebas, todas pasan |
| `test/widgets/pantalla_detalle_test.dart` | Desechar y deshacer; consumir una parte y deshacer; consumir lo último; cancelar no cambia nada | 4 pruebas, todas pasan |

Para correrlas: `flutter test`. Para revisar el código: `flutter analyze`.

- Punto de partida (`main` en `bc53497`): `flutter analyze` sin problemas y 72 pruebas, todas pasan.
- Al terminar (`2717bbe`): `flutter analyze` sin problemas y 105 pruebas (33 nuevas), todas pasan.

## Problemas encontrados y decisiones

- **El aviso de la nube solo se ve con la pestaña Despensa abierta.** Lo muestra
  `pantalla_alimentos.dart`, así que se ve en la despensa y en lo que se abre
  encima de ella (detalle, "Sacar comida"). Si el fallo ocurre estando en Inicio
  no se muestra. Para cubrir toda la app hay que escuchar `avisoGuardadoProvider`
  en `pantalla_principal.dart`, que es de Kevin. No se tocó para no pisar su
  parte; queda pedírselo.
- **El caso de la nube no se ha probado con Firebase de verdad.** Las pruebas usan
  una nube falsa. Para verlo en el teléfono habría que hacer que las reglas
  rechacen un cambio (por ejemplo, salir del hogar desde otro teléfono y luego
  intentar consumir algo).
- **Decisión: "Deshacer" en vez de pedir confirmación.** Un cuadro de "¿Seguro?"
  agrega un toque cada vez; el aviso con "Deshacer" no estorba al uso normal y
  cubre el toque por error.
- **Decisión: se reutilizó `claveNombre`** (ya existía en `historial.dart` para
  "Por reponer") en la búsqueda y en las estadísticas, en lugar de escribir otra
  función para quitar tildes. Así todo el área compara nombres de la misma forma.
- **Saltos de línea:** al hacer `git add` en Windows sale el aviso "LF will be
  replaced by CRLF". Es normal con el `.gitattributes` del equipo y no cambia el
  contenido. Los archivos de `linux/`, `macos/` y `windows/` que Flutter vuelve a
  escribir no se suben.

## Pendiente

- [x] Consumir desde el detalle calcula lo que queda distinto que "Sacar comida" y puede dejar cantidades como `0.29999999999999993`.
- [x] El detalle muestra las cantidades sin formato (`1.0 kg`) y la tarjeta redondea mal (`0.25 kg` se ve como `0.3 kg`).
- [x] La búsqueda no encuentra "Lácteos" si se escribe "lacteos".
- [x] En estadísticas, "Lo que más se perdió" separa "Leche" y "leche" como si fueran productos distintos.
- [x] Consumir o desechar desde el detalle no se puede deshacer si se toca por error.
- [x] Aviso de Keiver: en modo nube, `actualizar` descarta sin mensaje los errores de guardado (`alimentos_provider.dart`).
- [ ] Avisarle a Keiver que su pendiente sobre `actualizar` en la nube quedó resuelto (commit `2717bbe`).
- [ ] **Kevin:** escuchar `avisoGuardadoProvider` en `pantalla_principal.dart` para que el aviso de la nube se vea en todas las pestañas.
- [ ] `pantalla_retiro.dart`: `_confirmar` no maneja errores; si falla un guardado, el botón queda desactivado (el mismo caso que Keiver arregló en `hoja_cocinar.dart`).
- [ ] Borrar un alimento desde el detalle no borra sus fotos del teléfono (`eliminar` no llama a `borrarFotosHuerfanas`, `eliminarVarios` sí).
- [ ] Historial: borrar deslizando no se puede deshacer.
- [ ] "Desechar" siempre guarda el motivo "Vencido o en mal estado"; se podría dejar elegir el motivo.
- [ ] Probar en el teléfono todo lo de esta bitácora.
