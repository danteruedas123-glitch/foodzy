# Pruebas de las reglas de Firestore

Comprueban `../firestore.rules` contra el emulador oficial de Firestore, sin
tocar el proyecto real de Firebase. Cubren quién puede crear un hogar, unirse,
salir, quitar a otra persona y acceder a la despensa, y repiten los pasos reales
que hace la app.

## Requisitos

- Node.js 18 o superior
- Java 21 o superior (lo pide el emulador de Firestore)

## Cómo correrlas

```bash
cd firestore-tests
npm install
npm test
```

La primera vez descarga el emulador. Deben pasar todas las pruebas. Los mensajes
`PERMISSION_DENIED` que aparecen en pantalla son normales: son las pruebas que
comprueban que algo **no** se puede hacer.

Cada vez que se cambie `firestore.rules`, hay que correrlas antes de publicar
las reglas en Firebase.
