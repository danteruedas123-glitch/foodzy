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
flutter run --dart-define=GEMINI_API_KEY=tu_clave
```

La clave de Gemini se obtiene gratis en <https://aistudio.google.com/apikey>.
También se puede pegar dentro de la app en **Ajustes → Inteligencia artificial**.

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

> `google-services.json` identifica tu proyecto, no es una contraseña, pero conviene
> no subirlo a un repositorio público. Está en el `.gitignore`.

Para iOS hay que añadir también `GoogleService-Info.plist` (ver la documentación de FlutterFire).

## Seguridad

La clave de Gemini va dentro de la app. Es suficiente para uso personal; si vas a
publicarla, conviene mover las llamadas a la IA a un servidor propio.
