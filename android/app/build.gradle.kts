import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Llave de firma del release (hallazgo de seguridad H-05). La llave y sus
// contraseñas viven fuera del repositorio: android/key.properties (en
// .gitignore) dice dónde está el .jks. Sin ese archivo el release se firma con
// la llave de debug, que es pública, y Gradle lo advierte.
val firmaRelease = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) FileInputStream(archivo).use { load(it) }
}

android {
    namespace = "com.example.foodzy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.foodzy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!firmaRelease.isEmpty) {
            create("release") {
                keyAlias = firmaRelease.getProperty("keyAlias")
                keyPassword = firmaRelease.getProperty("keyPassword")
                storeFile = file(firmaRelease.getProperty("storeFile"))
                storePassword = firmaRelease.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (firmaRelease.isEmpty) {
                logger.warn("AVISO: falta android/key.properties; el release se firma con la llave de debug.")
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Firebase se activa solo si existe google-services.json (ver README).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

flutter {
    source = "../.."
}
