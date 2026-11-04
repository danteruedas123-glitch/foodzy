# Fase 3 · Correcciones

Se corrigieron 7 hallazgos de la [auditoría](fase2-auditoria.md), de mayor a
menor severidad. Cada corrección está en su propio commit de la rama
`seguridad`, con el ID del hallazgo en el mensaje.

H-03 y H-04 (Premium simulado) quedan como **riesgo aceptado**: son el modo de
demostración de la monetización.

## 1. Correcciones

| ID | Severidad | Qué se cambió | Archivos | Commit |
|---|---|---|---|---|
| H-01 | Alta | `Env.geminiApiKey` vale `''` fuera de debug, así que el compilador descarta el valor de `--dart-define` y no llega al binario. En desarrollo se sigue usando. | `lib/core/env.dart` | `e82f8c4` |
| H-02 | Alta | La clave de Gemini se guarda con `flutter_secure_storage`: AES-GCM con la llave en el Android Keystore, y Keychain en iPhone. Al abrir la app, una clave que quedara en SharedPreferences se pasa al almacenamiento seguro y se borra de ahí. | `api_key_provider.dart`, `main.dart`, `pubspec.yaml` | `5c07de0`, pruebas en `f62d5d8` |
| H-05 | Alta | El release se firma con una llave propia (RSA 4096, `CN=Foodzy`). La llave y sus contraseñas están fuera del repositorio; Gradle las lee de `android/key.properties`, que está en `.gitignore` igual que `*.jks` y `*.keystore`. | `android/app/build.gradle.kts`, `.gitignore` | `bbecb6c` |
| H-06 | Media | `android:allowBackup="false"` y `dataExtractionRules`, que excluyen todos los datos de la copia en la nube y del paso a otro teléfono (Android 12+). | `AndroidManifest.xml`, `res/xml/data_extraction_rules.xml` | `74dde98` |
| H-07 | Media | R8 explícito (`isMinifyEnabled`, `isShrinkResources`) y código Dart ofuscado con `--obfuscate --split-debug-info` en el IPA y en el comando documentado del APK. | `build.gradle.kts`, `.github/workflows/iphone.yml`, `README.md` | `97ddef0` |
| H-08 | Media | En release, `debugPrint` queda sin efecto, así que no se escriben errores de la IA, de la red ni de Firebase en el log. | `lib/main.dart` | `9dca64c` |
| H-10 | Baja | `CodigoBarrasService.buscar` solo acepta de 6 a 14 dígitos; si no, devuelve `null` sin hacer la petición. | `codigo_barras_service.dart`, `test/domain/codigo_barras_test.dart` | `94efb95` |

## 2. Mejoras obligatorias de la tarea

| Mejora | Estado | Cómo se cumple |
|---|---|---|
| Ningún secreto en el código ni en el repositorio | ✅ | H-01. Nunca se subió un secreto real (comprobado en las 91 versiones del historial), así que no hubo nada que rotar. La llave de firma nueva tampoco está en el repositorio. |
| Tokens y datos sensibles con Keystore o Keychain | ✅ | H-02. Los tokens de sesión los guarda el SDK de Firebase Auth. H-06 impide que salgan del teléfono por las copias de seguridad. |
| Todo el tráfico por HTTPS | ✅ | Ya se cumplía (M5): no hay `usesCleartextTraffic` ni `NSAllowsArbitraryLoads`, y todos los servicios usan `https`. |
| Validación de entradas en la app y de permisos en el servidor | ✅ | H-10 en la app. En el servidor, las reglas de Firestore validan membresía, campos y tamaños, y tienen pruebas en `firestore-tests/`. |
| Release sin modo debug, sin logs sensibles y con R8 | ✅ | H-05, H-07 y H-08. `aapt2` confirma que el release no es `debuggable`. |

## 3. Pendientes fuera del código

- **Inicio de sesión con Google en el release de Android:** Google comprueba la
  huella SHA-1 del certificado con el que se firma la app. Hay que agregar la
  huella de la llave nueva en *Firebase → Configuración del proyecto → Tus apps
  → Android → Agregar huella digital* y volver a descargar
  `google-services.json`. Las compilaciones de debug no cambian.
- **Copia de la llave de firma:** si se pierde `foodzy-subida.jks` o su
  contraseña, ya no se pueden publicar actualizaciones con la misma firma.
  Guardarla en un lugar seguro, fuera del repositorio.

## 4. Lo que no se corrigió y por qué

| ID | Motivo |
|---|---|
| H-03, H-04 | Riesgo aceptado: modo demostración de la monetización. |
| H-09 | Necesita un cambio de interfaz (aviso y consentimiento antes de enviar la factura). Queda propuesto. |
| H-11 | Cambiar el `applicationId` obliga a registrar otra app Android en Firebase. Queda propuesto. |
| H-12 | App Check es la mejora opcional para puntos extra. Queda propuesta. |
| H-13 | Son parches sin vulnerabilidades conocidas; se actualizarán con el mantenimiento normal. |
