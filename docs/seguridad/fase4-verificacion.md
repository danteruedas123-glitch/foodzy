# Fase 4 · Verificación

Cada hallazgo corregido se verificó repitiendo **la misma prueba** sobre la
versión de antes y la de después. Un hallazgo se da por cerrado solo si la
prueba repetida ya no lo reproduce.

## Entorno

| | Antes | Después |
|---|---|---|
| Código | commit `0322978` (rama `soporte-iphone`) | rama `seguridad` (`17abfff`) |
| APK | `app-release.apk` del 29-oct-2026 | `app-release.apk` del 4-nov-2026 |
| Compilación | `--dart-define-from-file=claves.json` | `--obfuscate --split-debug-info=build/simbolos --dart-define-from-file=claves.json` |

- **Emulador:** Android 17, imagen `sdk_gphone64_x86_64` (`userdebug`), con `adb root` para leer los datos de la app.
- **Cuenta:** una de prueba (`prueba.seguridad@example.com`).
- **Clave de Gemini:** una falsa (`CLAVE-FALSA-H02`).
- **Valor de `GEMINI_API_KEY` en `claves.json`:** el texto de ejemplo `PEGA_AQUI_TU_CLAVE`.

Ninguna evidencia contiene secretos reales.

## Resumen

| ID | Prueba | Antes | Después | Estado |
|---|---|---|---|---|
| H-01 | Buscar en `libapp.so` el valor pasado con `--dart-define` y abrir Ajustes | El valor está en el binario (offset `0x9cd13`) y la app lo muestra como "API Key configurada" | 0 apariciones; la app dice "Falta la API Key de Gemini" | ✅ Cerrado |
| H-02 | Guardar una clave en Ajustes y leer los datos de la app con root | `<string name="flutter.gemini_api_key">CLAVE-FALSA-H02</string>` en texto plano | `grep -r` no la encuentra en ningún archivo; solo está cifrada en `FlutterSecureStorage.xml` | ✅ Cerrado |
| H-05 | `apksigner verify --print-certs` | `CN=Android Debug` | `CN=Foodzy, O=Foodzy, C=CO` | ✅ Cerrado |
| H-06 | `dumpsys package` (flags de la app instalada) | `ALLOW_BACKUP` | Sin `ALLOW_BACKUP` | ✅ Cerrado |
| H-07 | Buscar nombres de clases Dart en `libapp.so` | `PremiumNotifier`=2, `ApiKeyNotifier`=2, `GeminiClient`=1, `CodigoBarrasService`=1 | Todos en 0 | ✅ Cerrado |
| H-08 | "Generar recetas" con la clave falsa y `adb logcat -s flutter` | `[IA] gemini-3.5-flash-lite falló tras 1421ms: 400: INVALID_ARGUMENT API key not valid…` | Log vacío (la app muestra el mismo error en pantalla) | ✅ Cerrado |
| H-10 | `flutter test test/domain/codigo_barras_test.dart` | 4 de 6 fallan: el servicio hace la petición con `../` | 6 de 6 pasan | ✅ Cerrado |

## Detalle por hallazgo

### H-01 · Clave de Gemini compilada en el binario

Los dos APK se compilaron con el mismo `claves.json`. Se buscó el valor de
`GEMINI_API_KEY` dentro de `libapp.so`:

```text
===== ANTES (29-oct)
  [arm64-v8a] H-01 valor de la clave en el binario: 1 vez (offset 0x9cd13)
  [x86_64]    H-01 valor de la clave en el binario: 1 vez (offset 0x9cdaa)
===== DESPUÉS (4-nov)
  [arm64-v8a] H-01 valor de la clave en el binario: 0 veces
  [x86_64]    H-01 valor de la clave en el binario: 0 veces
```

En la app instalada, antes Ajustes mostraba "API Key de Gemini configurada" con
el valor compilado (`PEGA_AQUI_TU_CLAVE`) sin haber pegado nada. Después muestra
"Falta la API Key de Gemini".

Capturas: `H-01-antes-clave-compilada-visible.png` y `H-01-despues-sin-clave-compilada.png`.

### H-02 · Clave guardada sin cifrar

Se pegó `CLAVE-FALSA-H02` en Ajustes → Guardar clave, y luego se leyeron los
datos de la app como root.

**Antes:**

```text
$ adb shell cat /data/data/com.example.foodzy/shared_prefs/FlutterSharedPreferences.xml
<map>
    <string name="flutter.gemini_api_key">CLAVE-FALSA-H02</string>
    <boolean name="flutter.semilla_demo" value="true" />
</map>
```

**Después:**

```text
$ adb shell grep -rl CLAVE-FALSA-H02 /data/data/com.example.foodzy/
(ningún archivo la contiene en texto plano)

$ adb shell cat /data/data/com.example.foodzy/shared_prefs/FlutterSecureStorage.xml
<map>
    <string name="VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg_gemini_api_key">0Opt05jYX8F9NjEsRWQfYIdeDNv4BFC2eFM4NpawlcQyueVN9lsHY0Nbcw==</string>
</map>
```

La app sigue usando la clave: al generar recetas responde "La API Key de Gemini
no es válida", así que la leyó del almacenamiento seguro y se la envió a
Gemini. Las pruebas automáticas (`clave_gemini_test.dart`, 2 de 2) comprueban
además que una clave antigua se migra y se borra de SharedPreferences.

### H-05 · Firma con la llave de debug

```text
ANTES:   Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
         SHA-256: 7ac6ac6674cea0e83e2abc4bef620b43c6d53ff00bdf55e31e78b61d63ca3094
DESPUÉS: Signer #1 certificate DN: CN=Foodzy, O=Foodzy, C=CO
         SHA-256: 9e4cb98a9beae8502f5ce99fdd4bdcfa30922173b33a28a583e5b861c740ad42
```

### H-06 · Copias de seguridad

```text
ANTES:   pkgFlags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP KILL_AFTER_RESTORE ]
DESPUÉS: pkgFlags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ]
```

### H-07 · Ofuscación

```text
ANTES:   PremiumNotifier=2, ApiKeyNotifier=2, GeminiClient=1, CodigoBarrasService=1
         R8: 8226 de 11759 clases Java/Kotlin ofuscadas
DESPUÉS: PremiumNotifier=0, ApiKeyNotifier=0, GeminiClient=0, CodigoBarrasService=0
         R8: 8250 de 11796 clases Java/Kotlin ofuscadas
```

Los símbolos para leer errores quedan fuera del APK, en `build/simbolos`
(`flutter symbolize`); se comprobó que `libapp.so` no tiene secciones `.debug_*`.

### H-08 · Logs en el release

La misma acción en los dos APK: tocar "Generar recetas" con la clave falsa.

```text
ANTES:
$ adb logcat -d -s flutter
I flutter : [IA] gemini-3.5-flash-lite falló tras 1421ms: 400: INVALID_ARGUMENT API key not valid. Please pass a valid API key.

DESPUÉS:
$ adb logcat -d -s flutter
(fin del log de flutter)
```

Capturas: `H-08-antes-pantalla.png` y `H-08-despues-pantalla.png` (la segunda
muestra que la llamada a la IA sí ocurrió).

### H-10 · Código de barras sin validar

La misma prueba, `test/domain/codigo_barras_test.dart`, sobre los dos códigos:

```text
ANTES (0322978):  rechaza "abc/../../v0/product/1"        [E]
                  rechaza "../../../cgi/search.pl?x=1#a"  [E]
                  rechaza ""                              [E]
                  rechaza "12345"                         [E]  Expected: null  Actual: <Instance of 'ProductoCodigo'>
                  01:01 +2 -4: Some tests failed.
DESPUÉS:          00:00 +6: All tests passed!
```

## Archivos de evidencia

Están fuera del repositorio, en `evidencia-seguridad/` (junto a la carpeta
`foodzy/`):

- `antes/` y `despues/`: los dos APK.
- `capturas/`: las capturas del emulador.
- `salidas/`: la salida completa de cada comando (`H-0X-antes.txt` y `H-0X-despues.txt`).
