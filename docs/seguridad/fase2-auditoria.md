# Fase 2 · Auditoría OWASP Mobile Top 10 (2024)

Auditoría de Foodzy sobre la rama `soporte-iphone`, hecha el 4 de noviembre de 2026.
Ninguna evidencia de este documento muestra secretos reales: las llaves aparecen
cortadas (`AIzaSyC6****`) y la prueba del binario se hizo con un valor de
ejemplo.

## 1. Técnicas usadas

| # | Técnica | Herramienta | Qué se revisó |
|---|---|---|---|
| T1 | Buscar secretos en el código y en el historial de Git | `git log --all -p` con expresiones regulares para llaves de Google (`AIza…`), RevenueCat (`goog_`, `appl_`), GitHub (`ghp_`), Stripe y llaves privadas | Las 91 versiones del repositorio |
| T2 | Analizar el APK de release | `aapt2 dump`, `apksigner verify`, extracción de `libapp.so` y `classes.dex` | `app-release.apk` compilado el 29 de octubre de 2026 |
| T3 | Revisar dependencias | `flutter pub outdated` y la base de vulnerabilidades [OSV](https://osv.dev) (`api.osv.dev/v1/querybatch`) | Los 146 paquetes de `pubspec.lock` |
| T4 | Revisar la configuración nativa y los permisos | `AndroidManifest.xml`, `build.gradle.kts`, `Info.plist`, `manifest-merger-release-report.txt` | Android e iPhone |
| T5 | Revisar el código | Búsqueda dirigida en `lib/`, `firestore.rules` y `.github/workflows/` | Almacenamiento, red, logs, validaciones y CI |

## 2. Resultado por riesgo

| ID | Riesgo | Resultado | Justificación |
|---|---|---|---|
| M1 | Improper Credential Usage | **No cumple** | La llave de Gemini se compila en el binario con `--dart-define` y queda en texto plano dentro de `libapp.so` (H-01). La app llama a Gemini directamente desde el teléfono, sin un servidor intermedio. La llave de Gemini nunca se subió a Git; las tres llaves `AIza…` del historial son las de Firebase, que son públicas por diseño. |
| M2 | Inadequate Supply Chain Security | **Cumple** | OSV no reporta vulnerabilidades en ninguno de los 146 paquetes. Hay 14 paquetes con versiones de parche pendientes, sin fallas conocidas (H-13, mejora preventiva). |
| M3 | Insecure Authentication/Authorization | **Cumple (con un riesgo aceptado)** | Los datos protegidos (hogares, despensa y lista) se validan en el servidor con reglas de Firestore que tienen pruebas automáticas. Premium y el cupo de IA gratis se deciden en el teléfono, pero eso es a propósito: es el modo de demostración de la monetización (H-03 y H-04, riesgo aceptado). |
| M4 | Insufficient Input/Output Validation | **No cumple (parcial)** | Las reglas de Firestore limitan campos y tamaños, los formularios validan y la respuesta de Gemini se lee con cuidado. En cambio, el servicio de código de barras mete el texto en la URL sin validarlo (H-10). |
| M5 | Insecure Communication | **Cumple** | Todo va por HTTPS. No hay `usesCleartextTraffic` ni `NSAllowsArbitraryLoads`, no se usa `badCertificateCallback` ni `HttpOverrides`, y rigen los valores seguros por defecto de Android y de App Transport Security. No hay certificate pinning (es una mejora opcional). |
| M6 | Inadequate Privacy Controls | **No cumple (parcial)** | Los permisos son los mínimos (cámara y fotos, con textos claros en `Info.plist`). Pero la foto completa de la factura se envía a Gemini sin avisar al usuario (H-09). |
| M7 | Insufficient Binary Protections | **No cumple** | R8 sí está activo en la parte Java/Kotlin (8.226 de 11.759 clases ofuscadas), pero el código Dart no está ofuscado: en `libapp.so` se leen `PremiumNotifier`, `ApiKeyNotifier`, `premium_activo` y `gemini_api_key` (H-07). |
| M8 | Security Misconfiguration | **No cumple** | El release se firma con la llave de debug (H-05). El IPA público se compila con compras de prueba (H-04, riesgo aceptado). El `applicationId` sigue siendo de ejemplo (H-11). No hay App Check (H-12). Sin `debuggable` en release, y los componentes exportados son solo el launcher y los de las librerías (Firebase Auth, Google Sign-In, RevenueCat). |
| M9 | Insecure Data Storage | **No cumple** | La llave de Gemini y el estado Premium están en SharedPreferences sin cifrar (H-02). Las copias de seguridad de Android están activas (H-06). `debugPrint` escribe errores en el log del release (H-08). |
| M10 | Insufficient Cryptography | **Cumple** | No hay MD5, SHA-1 ni criptografía propia, ni llaves de cifrado en el código. Los códigos de invitación usan `Random.secure()`; `Random()` solo se usa para animaciones. |

## 3. Hallazgos

Ordenados de mayor a menor severidad.

| ID | OWASP | Descripción | Evidencia | Severidad | Corrección propuesta |
|---|---|---|---|---|---|
| H-01 | M1, M7 | La llave de Gemini se compila en el binario con `--dart-define=GEMINI_API_KEY`, y cualquiera que tenga el APK o el IPA puede sacarla. | `lib/core/env.dart:5`. En `app-release.apk` el valor pasado (uno de prueba de 18 caracteres) aparece en texto plano en `lib/arm64-v8a/libapp.so`, offset `0x9cd13` (T2). | **Alta** | No compilar ninguna llave de Gemini en la app. La llave que pega el usuario va en almacenamiento seguro (H-02); a futuro, llamar a la IA por un servidor (Firebase AI Logic con App Check o una Cloud Function). |
| H-02 | M9 | La llave de Gemini que pega el usuario se guarda en SharedPreferences, en texto plano. | `api_key_provider.dart:24` (`prefs.setString('gemini_api_key', …)`). Con root se lee en `/data/data/<paquete>/shared_prefs/FlutterSharedPreferences.xml`. | **Alta** | Pasar a `flutter_secure_storage` (Android Keystore / iOS Keychain) y migrar los valores existentes. |
| H-03 | M3 | Premium y el cupo de 15 usos de IA gratis se deciden solo en el teléfono: editando SharedPreferences se obtiene Premium o se reinicia el contador. Si RevenueCat no responde, se respeta el valor local. | `premium_provider.dart:139-156` (`verificarCupo` y `registrarUso` leen y escriben SharedPreferences), `:162` (`vigente != null`) y `:181` (`setBool('premium_activo', …)`). | **Riesgo aceptado** | Es a propósito: el Premium simulado es el **modo de demostración** con el que el grupo enseña cómo se monetiza la app. En una versión comercial, el estado Premium lo daría RevenueCat validado en el servidor y el cupo de IA lo llevaría un backend que haga las llamadas a Gemini. |
| H-04 | M8, M3 | El IPA que GitHub publica se compila con `COMPRAS_PRUEBA=true`, así que activa Premium sin cobrar. | `.github/workflows/iphone.yml:47` (`--dart-define=COMPRAS_PRUEBA=true`) y `premium_provider.dart:97` (`habilitado => kDebugMode \|\| Env.comprasDePrueba`). | **Riesgo aceptado** | Es a propósito, por el mismo **modo de demostración** de H-03: así cualquiera del curso puede probar el flujo de compra sin pagar. Para publicar en la tienda, la bandera se quita del workflow. |
| H-05 | M8 | El APK de release se firma con la llave pública de debug de Android. | `build.gradle.kts:37` (`signingConfig = signingConfigs.getByName("debug")`). `apksigner verify --print-certs` muestra `CN=Android Debug`, SHA-256 `7ac6ac66…`. | **Alta** | Crear una llave de subida propia, leerla desde `key.properties` (fuera del repositorio, en `.gitignore`) y firmar el release con ella. |
| H-06 | M9 | Las copias de seguridad de Android están activas (`allowBackup` no está desactivado), así que el backup incluye SharedPreferences y la base SQLite. | El manifiesto del APK no declara `allowBackup`, `fullBackupContent` ni `dataExtractionRules`, y el valor por defecto es `true` (T2, T4). | **Media** | `android:allowBackup="false"` y reglas de `dataExtractionRules` que excluyan los datos de la app. |
| H-07 | M7 | El código Dart del release no está ofuscado. | En `libapp.so` se leen `PremiumNotifier` (2 veces), `ApiKeyNotifier` (2), `GeminiClient` (1), `premium_activo` (1) y `gemini_api_key` (1). | **Media** | Compilar con `--obfuscate --split-debug-info=…` y mantener R8 (`isMinifyEnabled`, `isShrinkResources`) explícito en Gradle. |
| H-08 | M9 | `debugPrint` también escribe en el log del release: errores completos de Gemini, de Open Food Facts y de Firebase. | `gemini_client.dart:133`, `:150` y `:244`; `pantalla_codigo_barras.dart:66` (incluye el stack trace); `nube.dart:32`. Se ve con `adb logcat -s flutter`. | **Media** | Una función de log que solo escriba en `kDebugMode`, y nunca la respuesta cruda de la API. |
| H-09 | M6 | La foto completa de la factura (que puede traer nombre, documento, dirección o datos de pago) se envía a Gemini sin avisar ni pedir permiso. | `scanner_service.dart:178` (`analizarFactura`) y `gemini_client.dart:108` (la imagen va como `inlineData` a `generativelanguage.googleapis.com`); no hay ningún aviso en el flujo de escaneo. | **Media** | Aviso y consentimiento la primera vez, y borrar los archivos temporales después de usarlos. |
| H-10 | M4 | El servicio de código de barras mete el código en la ruta de la URL sin validarlo, así que un valor con `../` cambia el endpoint. | `codigo_barras_service.dart:35-38`. Prueba con Dart: `abc/../../v0/product/1` se convierte en `https://world.openfoodfacts.org/api/v2/v0/product/1.json`. Hoy lo limitan el escáner (solo formatos EAN y UPC) y el teclado de solo dígitos. | **Baja** | Validar `^\d{6,14}$` dentro del servicio (defensa en profundidad). |
| H-11 | M8 | El `applicationId` y el `namespace` siguen siendo los de ejemplo (`com.example.foodzy`). | `build.gradle.kts:8` y `:20`; `aapt2` muestra `package="com.example.foodzy"`. | **Baja** | Usar `com.foodzy.app`, igual que en iPhone. Hay que registrar esa app Android en Firebase y descargar su nuevo `google-services.json`. |
| H-12 | M8 | No hay Firebase App Check, y falta comprobar que las llaves de cliente de Firebase estén restringidas en Google Cloud. | No aparece `firebase_app_check` en `pubspec.yaml`. Las restricciones solo se ven en la consola. | **Media** | Activar App Check (Play Integrity / App Attest) y restringir las llaves por app y por API. Es la mejora opcional de integridad. |
| H-13 | M2 | 14 dependencias tienen parches pendientes (sin vulnerabilidades conocidas). | `flutter pub outdated`: `cloud_firestore` 6.10.0 → 6.10.2, `firebase_auth` 6.7.0 → 6.7.1, `purchases_flutter` 10.14.0 → 10.19.0, etc. | **Baja** | `flutter pub upgrade` y volver a probar la app. |

## 4. Lo que está bien

Conviene mostrarlo en la sustentación como ejemplos de buenos controles:

- **Reglas de Firestore** (`firestore.rules`): cada hogar solo lo leen sus miembros, solo se entra con el código vigente, las invitaciones no se pueden listar, solo el dueño saca a otros o cambia el código, y hay límites de tamaño. Tienen pruebas automáticas en `firestore-tests/`.
- **Sin secretos en Git:** `claves.json` está en `.gitignore` desde el principio y no aparece en ninguna versión.
- **Red:** solo HTTPS y sin excepciones.
- **Componentes de Android:** los receptores de notificaciones están en `exported="false"`.
- **Dependencias:** ninguna con vulnerabilidades conocidas.

## 5. Plan para la Fase 3

Mejoras obligatorias de la tarea y qué hallazgo cubre cada una:

| Mejora obligatoria | Hallazgos |
|---|---|
| Ningún secreto en el código ni en el repositorio | H-01 |
| Tokens y datos sensibles en Keystore o Keychain | H-02, H-06 |
| Todo el tráfico por HTTPS | Ya cumple (M5); se deja como evidencia |
| Validación de entradas en la app y de permisos en el servidor | H-10 (las reglas de Firestore ya cumplen la parte del servidor) |
| Release sin debug, sin logs sensibles y con R8 | H-05, H-07, H-08 |

Se corrigen, de mayor a menor severidad: **H-01, H-02, H-05, H-06, H-07, H-08 y H-10**. H-03 y H-04 quedan como riesgo aceptado (modo demostración). Para puntos extra: H-12 (App Check).
