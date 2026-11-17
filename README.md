# Foodzy

Despensa inteligente: registra tu compra con la cámara (foto, factura o código
de barras), recibe avisos antes de que algo venza y cocina con lo que tienes.

## Qué hace

- **Escaneo con IA (Gemini):** foto de la compra, factura (con precios) y "sacar comida"
  con porciones, medidas caseras y medición por fotos antes/después.
- **Código de barras:** escaneo en serie con datos de Open Food Facts.
- **Fechas de vencimiento:** leídas del empaque, estimadas por la IA según el tipo de
  producto y dónde se guarda (nevera, congelador, alacena), o puestas a mano.
  Los productos que no vencen (sal, azúcar…) no generan avisos.
- **Notificaciones** locales antes del vencimiento, con pantalla "¿ya lo consumiste?".
- **Recetas con IA:** sugeridas, favoritas y menú semanal, con tus preferencias
  (dieta, alergias, tiempo). Al cocinar se descuentan los ingredientes de la despensa.
- **Historial, lista de compras y estadísticas** (gasto y desperdicio por mes).
- **Cuentas y hogar compartido** con Firebase (opcional).

## Cómo ejecutarla

```bash
flutter pub get
flutter run
```

La IA (Gemini) va por **Firebase AI Logic**: la clave de Gemini la guarda
Firebase y la app no lleva ninguna, ni hay que pegarla. Para que funcione, el
proyecto de Firebase debe tener activado *AI Logic → Gemini Developer API*
(<https://console.firebase.google.com/project/fooddzy/ailogic>).

## Compilar el release (Android)

```bash
flutter build apk --release --obfuscate --split-debug-info=build/simbolos
```

- `--obfuscate` cambia los nombres del código Dart por otros sin sentido, y
  `--split-debug-info` guarda aparte los símbolos para poder leer los errores
  (`flutter symbolize`). No borres `build/simbolos` de una versión publicada.
- Se firma con la llave que indique `android/key.properties`, que no está en el
  repositorio:

  ```properties
  storePassword=...
  keyPassword=...
  keyAlias=subida
  storeFile=C:/ruta/fuera/del/repo/foodzy-subida.jks
  ```

  Sin ese archivo, Gradle avisa y firma con la llave de debug.

## Modo local y modo nube

Sin configurar Firebase, la app funciona en **modo local**: todo se guarda en el
teléfono y el inicio de sesión es simulado.

Con Firebase configurado pasa a **modo nube**: cuentas reales (correo y contraseña),
copia de seguridad, sincronización entre dispositivos y un **hogar compartido**
(la familia comparte despensa y lista de compras con un código de invitación).

### Conectar Firebase (Android)

1. Entra a <https://console.firebase.google.com> y **crea un proyecto**.
2. En el proyecto: **Compilación → Authentication → Comenzar → Correo electrónico/contraseña → Activar**.
3. **Compilación → Firestore Database → Crear base de datos** (modo producción, la región más cercana).
4. En Firestore, pestaña **Reglas**: pega el contenido de [`firestore.rules`](firestore.rules) y **Publica**.
5. **Configuración del proyecto → Tus apps → Android** (ícono de Android):
   - Nombre del paquete: `com.example.foodzy`
   - Registra la app y **descarga `google-services.json`**.
6. Copia `google-services.json` a `android/app/google-services.json`.
7. Vuelve a compilar: `flutter run`. En **Ajustes → Cuenta y hogar** debe decir que tus datos están en la nube.

> `google-services.json` ya viene en el repositorio (identifica el proyecto, no es una contraseña),
> así que al clonar la nube funciona sin más. No hagas público el repositorio.

Para iOS hay que añadir también `GoogleService-Info.plist` (ver la documentación de FlutterFire).

## Seguridad

- La clave de Gemini no va dentro de la app: las peticiones a la IA pasan por
  Firebase AI Logic, que tiene la clave del lado del servidor (hallazgo H-01).
  Para blindarlo del todo hace falta App Check, que exige publicar en Play Store.
- Los datos de la app no entran en las copias de seguridad de Android y el
  release no escribe en el log.
- La auditoría completa (OWASP Mobile Top 10) está en [`docs/seguridad/`](docs/seguridad/).
