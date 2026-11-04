# Foodzy en iPhone, gratis y sin Mac

Hay dos formas de usar Foodzy en un iPhone. Las dos son gratis.

| | App nativa (Sideloadly) | App web (Safari) |
|---|---|---|
| Avisos de vencimiento con la app cerrada | Sí | No |
| Cámara, escáner de código de barras | Sí | Sí, con el selector de fotos de Safari |
| Hace falta un computador | Sí, Windows y un cable | No |
| Caduca | Cada 7 días (se reinstala en 2 minutos) | Nunca |

## App nativa con Sideloadly (desde Windows)

La app se compila sola en un Mac de GitHub cada vez que cambia el código
(`.github/workflows/iphone.yml`). El resultado es `Foodzy.ipa`, sin firmar.
Sideloadly la firma con tu Apple ID y la instala.

### Una sola vez

1. Instala **iTunes** e **iCloud** descargándolos de apple.com, **no** de la
   Microsoft Store (Sideloadly no funciona con las versiones de la tienda):
   - https://www.apple.com/itunes/download/win64
   - https://support.apple.com/es-es/103232
2. Instala **Sideloadly**: https://sideloadly.io
3. En el iPhone (iOS 16 o más nuevo): **Ajustes → Privacidad y seguridad →
   Modo de desarrollador → Activar**. El iPhone se reinicia y pide confirmar.

### Instalar (y repetir cada 7 días)

1. Descarga la última versión:
   https://github.com/danteruedas123-glitch/foodzy/releases/download/iphone-ultima/Foodzy.ipa
2. Conecta el iPhone al computador con el cable y, si lo pregunta, toca
   **Confiar en esta computadora**.
3. Abre Sideloadly, arrastra `Foodzy.ipa` a la ventana, escribe tu **Apple ID**
   y toca **Start**. Te pide la contraseña del Apple ID y, si tienes
   verificación en dos pasos, el código que llega a tu iPhone.
4. La primera vez, en el iPhone: **Ajustes → General → VPN y gestión de
   dispositivos →** toca tu Apple ID → **Confiar**.
5. Abre Foodzy. En **Ajustes → Inteligencia artificial** pega tu clave de
   Gemini (la app no trae ninguna).

Con un Apple ID gratuito la firma dura **7 días**: después la app no abre
hasta reinstalarla con los pasos 2 y 3. Tus datos no se pierden (la despensa
está en la nube y la app se instala encima de la anterior).

Límites del Apple ID gratuito: hasta 3 apps instaladas así a la vez.

**Si Sideloadly dice que el identificador `com.foodzy.app` no está
disponible**, abre **Advanced options** y activa **Change bundle ID** (deja el
que sugiere).

## App web (cualquier iPhone, sin cables)

1. Abre en **Safari**: https://fooddzy.web.app
2. Toca **Compartir** (el cuadrado con la flecha) → **Agregar a inicio**.
3. Queda el ícono de Foodzy en la pantalla de inicio y se abre como una app.

La versión web usa la misma cuenta, despensa y hogar que la app. Lo que no
tiene son los avisos de vencimiento con la app cerrada.

## Para quien mantiene el proyecto

- La configuración de Firebase de iPhone y web está en
  `lib/core/firebase_opciones.dart` (proyecto `fooddzy`). El identificador de
  iPhone es `com.foodzy.app`.
- La compilación de iPhone corre sola al subir cambios a `main`,
  `mejoras-foodzy` o `soporte-iphone`, y también a mano desde la pestaña
  **Actions → App para iPhone → Run workflow**.
- La versión web se publica en Firebase Hosting (https://fooddzy.web.app):
  `flutter build web --release --dart-define=COMPRAS_PRUEBA=true` y luego
  `firebase deploy --only hosting` (configuración en `firebase.json`).
