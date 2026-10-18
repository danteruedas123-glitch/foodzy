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
| Lista de la despensa, búsqueda y filtros | `pantalla_alimentos.dart`, `alimentos_provider.dart`, `alimento_card.dart`, `estado_visual.dart` |
| Detalle, consumir y desechar | `pantalla_detalle.dart` |
| Sacar comida (retiro) | `pantalla_retiro.dart`, `habitos_provider.dart` |
| Historial | `historial.dart`, `pantalla_historial.dart` |
| Estadísticas | `estadisticas.dart`, `pantalla_estadisticas.dart` |
| Por reponer | `pantalla_por_reponer.dart`, `reposicion_provider.dart` |
| Utilidades | `lib/core/formato.dart`, `lib/core/json.dart`, `lib/core/comparaciones.dart` |

Todas las pantallas y providers están en `lib/features/alimentos/presentation/`.

## Cómo se llena esta bitácora

Una fila por cada cambio terminado. Un cambio corresponde a un commit o a un
Pull Request. No se registran cosas que no se hicieron.

## Registro de cambios

| Fecha | Commit / PR | Qué cambió | Archivos | Por qué | Cómo probarlo |
| --- | --- | --- | --- | --- | --- |

## Pruebas automáticas del área

| Archivo de prueba | Qué verifica | Estado |
| --- | --- | --- |
| `test/domain/alimento_test.dart` | Ida y vuelta a JSON, errores claros al leer, origen de la fecha, igualdad, reglas de negocio | Ya existía, pasa |
| `test/domain/estadisticas_test.dart` | Gasto del mes por categoría, desperdicio proporcional, porcentaje, últimos 6 meses | Ya existía, pasa |

Para correrlas: `flutter test`. Para revisar el código: `flutter analyze`.
Punto de partida (2026-10-18, `main` en `bc53497`): `flutter analyze` sin
problemas y 72 pruebas en total, todas pasan.

## Problemas encontrados y decisiones

## Pendiente

- [ ] Consumir desde el detalle calcula lo que queda distinto que "Sacar comida" y puede dejar cantidades como `0.29999999999999993`.
- [ ] El detalle muestra las cantidades sin formato (`1.0 kg`) y la tarjeta redondea mal (`0.25 kg` se ve como `0.3 kg`).
- [ ] La búsqueda no encuentra "Lácteos" si se escribe "lacteos".
- [ ] En estadísticas, "Lo que más se perdió" separa "Leche" y "leche" como si fueran productos distintos.
- [ ] Consumir o desechar desde el detalle no se puede deshacer si se toca por error.
- [ ] Aviso de Keiver: en modo nube, `actualizar` descarta sin mensaje los errores de guardado (`alimentos_provider.dart`).
