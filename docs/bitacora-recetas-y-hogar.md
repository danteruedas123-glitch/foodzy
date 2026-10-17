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
| 2026-10-16 | 14fbc66 | **Reglas de seguridad del hogar más estrictas.** Crear: solo un hogar propio y quedando como dueño. Cambiar: solo la lista de miembros, y solo de tres formas (una persona se une a un hogar con gente, una persona sale, o el dueño quita a otra). Antes cualquier miembro podía reescribir los miembros y el código, y se podía unir alguien a un hogar vacío | `firestore.rules` | Evitar que un miembro pueda meter o sacar gente a su gusto, cambiar el código o quedarse con un hogar | `firestore-tests`: 30 de 30 pasan con las reglas nuevas; con las viejas pasaban 19 de 30 |
| 2026-10-16 | 14fbc66 | Pruebas de las reglas con el emulador de Firestore (Node) | `firestore-tests/` (`pruebas.js`, `package.json`, `firebase.json`, `README.md`) y `.gitignore` | Las reglas no se podían probar y un error ahí puede dejar la app sin nube | `cd firestore-tests`, `npm install`, `npm test` |
| 2026-10-17 | b97a798 | **Botón "Compartir" en cada receta.** Manda por WhatsApp, correo, etc. el título, tiempo y porciones, los ingredientes (marcando los que hay que conseguir) y los pasos numerados | `lib/features/recetas/domain/receta_texto.dart`, `lib/features/recetas/presentation/widgets/receta_card.dart` | Poder pasarle una receta a alguien sin copiarla a mano. Usa `share_plus`, que ya estaba en el proyecto | Abrir una receta, tocar "Compartir" y revisar el texto en WhatsApp |
| 2026-10-17 | b97a798 | **`_confirmar` ya no deja la hoja bloqueada.** Si falla el guardado, avisa ("No pude descontar…" o "Solo se descontaron 1 de 2…") y se puede reintentar sin descontar de más | `lib/features/recetas/presentation/widgets/hoja_cocinar.dart` | Antes, un fallo dejaba el botón y "Ahora no" desactivados. Ver la corrección en "Problemas encontrados" | `flutter test test/widgets/hoja_cocinar_test.dart` |
| 2026-10-17 | b97a798 | Pruebas del texto para compartir y de la hoja de cocinar (esta es de widget) | `test/domain/receta_texto_test.dart`, `test/widgets/hoja_cocinar_test.dart` | Ninguna de las dos tenía pruebas | `flutter test` |
| 2026-10-17 | e4a92d0 | **Mensaje claro al unirse cuando las reglas rechazan la entrada.** Con las reglas nuevas, unirse a un hogar que quedó vacío falla; ahora se explica "No pude unirte a ese hogar. Puede que el código ya no esté activo…" en vez de mostrar el error técnico de Firebase | `lib/features/nube/hogar.dart`, `test/domain/hogar_service_test.dart` | Efecto directo de las reglas nuevas: sin esto la persona vería algo como `[cloud_firestore/permission-denied]` | Prueba "si las reglas rechazan la entrada" |
| 2026-10-17 | e4a92d0 | **`Salir del hogar` ya no falla en silencio.** Si no se puede salir, muestra "No pude salir del hogar. Revisa tu conexión…" | `lib/features/configuracion/presentation/pantallas/pantalla_configuracion.dart` | Antes la excepción no se manejaba. Es un cambio de una función, para no chocar con el rediseño de Kevin | Salir del hogar sin conexión: debe aparecer el mensaje |
| 2026-10-17 | e4a92d0 | Nuevo `.gitattributes` con `* text=auto` | `.gitattributes` | Que los saltos de línea se guarden igual en todos los computadores y las ramas no choquen por eso | Ver "Problemas encontrados" |

## Pruebas automáticas del área

| Archivo de prueba | Qué verifica | Estado |
| --- | --- | --- |
| `test/domain/recetas_parsear_test.dart` | Receta válida; objeto único en vez de lista; `alimento_id` inventado; cantidad usada limitada a lo disponible; cantidades 0/negativas/nulas; recetas sin ingredientes o pasos; elementos que no son objetos; valores por defecto; respuesta vacía; JSON de ida y vuelta | 11 pruebas, todas pasan |
| `test/domain/descuento_receta_test.dart` | Descuento por ingrediente; suma de ingredientes del mismo alimento; tope en lo disponible; ingredientes sin cantidad medible; ingredientes que no son de la despensa; receta vacía | 6 pruebas, todas pasan |
| `test/domain/lista_compra_agregar_test.dart` | Añadir varios; no repetir lo que ya está; ignorar mayúsculas y tildes; volver a añadir lo ya comprado; no repetir dentro del mismo lote; nombres vacíos; ids distintos | 7 pruebas, todas pasan |
| `test/domain/hogar_service_test.dart` | Crear o reutilizar el hogar; unirse (cambio de hogar, código en minúsculas, errores claros, copia de despensa solo si se pide); deshacer la entrada si falla la copia o el guardado; seguir en el hogar nuevo si no puede salir del anterior; salir; no hacer nada si es la única persona; explicar en español si las reglas rechazan la entrada | 13 pruebas, todas pasan |
| `test/domain/receta_texto_test.dart` | Texto para compartir: título, tiempo, ingredientes, pasos numerados; marca lo que hay que conseguir; "1 porción" en singular; sin descripción vacía; sin "·" suelto | 5 pruebas, todas pasan |
| `test/widgets/hoja_cocinar_test.dart` | Hoja de cocinar: descuenta y cierra; si falla el guardado avisa y se puede reintentar; si falla a mitad dice cuántos se descontaron y reintentar no descuenta dos veces. Con la versión anterior del archivo fallaban las 2 de error | 3 pruebas, todas pasan |
| `firestore-tests/pruebas.js` | Reglas de Firestore: crear hogar, leer, unirse, salir, quitar a otra persona (solo el dueño), campos que no se pueden cambiar, acceso a la despensa y los pasos reales de la app | 30 pruebas, todas pasan (con las reglas anteriores pasaban 19) |

Para correrlas: `flutter test`. Para revisar el código: `flutter analyze`.

## Problemas encontrados y decisiones

Cosas que se descubrieron mientras se trabajaba y cómo se resolvieron o por qué
se dejaron para después.

- **Ingredientes repetidos: descartado.** Se sospechó que dos ingredientes con el
  mismo `alimento_id` podían descontar más de lo que hay. Al revisar
  `hoja_cocinar.dart` se vio que ya los suma y limita el total a lo disponible, así
  que no era un problema. Ahora queda cubierto con pruebas en
  `descuento_receta_test.dart`.
- **`_confirmar` sin manejo de errores (arreglado, con una corrección).** En
  `hoja_cocinar.dart`, si `actualizar` fallaba a mitad, una parte ya se descontaba y la
  hoja quedaba bloqueada porque `_guardando` nunca volvía a `false`. Corrección del
  2026-10-17: al principio se anotó que pasaba "sin conexión en modo nube", y eso es
  falso. En modo nube `actualizar` guarda al instante y deja que Firestore confirme
  después, sin lanzar errores. El bloqueo solo podía pasar en modo local, si fallaba
  la base de datos del teléfono, que es poco común. Se arregló igual porque es una
  defensa barata.
- **`actualizar` en modo nube no avisa si el guardado falla (sin tocar; archivo de
  Sebastian).** `alimentos_provider.dart` usa
  `unawaited(_repo.guardar(...).catchError((_) {}))`. Si Firestore rechaza un guardado
  (por ejemplo por las reglas de seguridad), el cambio se muestra al instante y el
  error se descarta sin mensaje. Corrección del 2026-10-17: al principio se anotó que
  el cambio "quedaba como hecho". Firestore revierte solo su copia local cuando el
  servidor rechaza una escritura, y el listener de la despensa lo refleja, así que lo
  más probable es que la pantalla se corrija sola; lo que falta es el mensaje, y eso
  necesita cambios de pantalla. No está verificado en el teléfono. Conviene
  comentárselo a Sebastian.

- **Decisión: salir del hogar anterior es "lo mejor posible".** Después de entrar al
  hogar nuevo, si falla quitar a la persona del anterior no se revierte nada: ya usa el
  hogar nuevo. Lo contrario la dejaría sin poder unirse por un detalle menor. Queda
  la posibilidad de figurar todavía como miembro del hogar viejo.
- **Código de invitación de un hogar abandonado seguía activo (resuelto en las
  reglas nuevas).** Si la única persona de un hogar se unía a otro, el hogar viejo
  quedaba con 0 miembros pero su código seguía funcionando, y las reglas dejaban que
  alguien se añadiera a un hogar vacío y viera lo que quedó guardado allí. Las reglas
  nuevas no permiten unirse a un hogar sin miembros. Verificado con el emulador de
  Firestore (ver `firestore-tests`). **Falta publicarlas en Firebase.**
- **Decisión: dueño y permisos.** Se evaluó que solo el dueño del hogar pudiera hacer
  cualquier cambio, pero eso impediría que otras personas se unan o salgan por su
  cuenta. Quedó así: cualquiera se une o sale por sí mismo; solo el dueño (quien creó
  el hogar) puede quitar a otra persona; el código y el dueño no cambian nunca. Dar
  permisos del dueño a otros miembros (administradores) no se hizo: la app no tiene
  hoy ninguna pantalla para quitar miembros y sería código sin uso.
- **`salir` en la pantalla no maneja errores.** `pantalla_configuracion.dart` llama a
  `salir()` sin `try/catch`. Esa pantalla la está rediseñando Kevin, así que se
  arregla cuando él haga merge para no pisarnos.
- **La rama de Kevin choca con todo por los saltos de línea (hallado el 2026-10-17).**
  Probado con `git merge-tree`: mi rama contra `main` no tiene choques, pero contra
  `Design-Prevew` choca en 7 archivos que Kevin ni siquiera modificó. Causa: su commit
  `c77b481` cambió 158 archivos y solo 6 tienen cambios de verdad; en los demás solo
  cambió los saltos de línea (guardó CRLF, estilo Windows, donde `main` guarda LF).
  Solución: Kevin crea una rama nueva desde `main` actualizado, copia solo sus archivos
  reales (`auth_provider.dart`, `pantalla_configuracion.dart`, `pantalla_inicio.dart`,
  `insignias_premium.dart`, `.vscode/settings.json`) y NO incluye
  `build/reports/problems/problems-report.html`. Con `.gitattributes` ya no debería
  repetirse.
- **La huella de firma de este computador no está en Firebase (hallado el
  2026-10-17).** La app se instaló bien en el teléfono, pero Google Play Services
  avisó que el certificado de este equipo no está permitido. Afecta "Iniciar sesión
  con Google" (probable, no probado); correo y contraseña, recetas, compras y hogar no
  dependen de eso.

## Pendiente

- [x] Revisar `hoja_cocinar.dart`: ¿se descuenta de más cuando un alimento aparece dos veces? No.
- [x] Pruebas del descuento de ingredientes al cocinar.
- [x] `hoja_cocinar.dart`: manejar errores en `_confirmar` para no dejar la hoja bloqueada.
- [ ] Avisar a Sebastian de que `actualizar` (modo nube) descarta los errores de guardado sin mensaje.
- [ ] **Kevin:** su rama `Design-Prevew` guarda los archivos con saltos de línea de Windows (CRLF) y cambió 158 archivos solo por eso, así que choca con casi todo lo demás. Debe rehacerla con solo sus 5 archivos de verdad (ver "Problemas encontrados") y sin el reporte de `build/`.
- [ ] **Firebase:** registrar la huella SHA-1 de cada computador del equipo (en la consola de Firebase) para que "Iniciar sesión con Google" funcione al probar en el teléfono, y bajar el `google-services.json` nuevo.
- [ ] Manejo de error cuando la IA no responde en recetas.
- [x] Hogar: `unirse()` puede dejar a la persona en dos hogares si falla a mitad.
- [x] Hogar: `salir()` crea un hogar nuevo y deja el anterior abandonado cuando se va el único miembro.
- [x] Hogar: el código de un hogar abandonado (por `unirse`) sigue activo. Resuelto en `firestore.rules`.
- [x] Reglas de Firestore: restringir qué puede modificar un miembro en `hogares`. Hecho y probado con el emulador.
- [ ] **Publicar `firestore.rules` en Firebase** (Console → Firestore Database → Reglas → Publicar) y comprobar en la app con dos cuentas que unirse y salir siguen funcionando.
- [ ] Reglas: la colección `invitaciones` deja que cualquier persona con sesión cree un código. No es grave (el hogar es un id aleatorio que no se conoce), pero se puede ajustar más adelante.
- [x] `pantalla_configuracion.dart`: manejar errores de `salir()`. Hecho con un cambio mínimo.
- [ ] Sacar la tarjeta del hogar de `pantalla_configuracion.dart` a `features/nube/tarjeta_hogar.dart` (después del merge de Kevin).
