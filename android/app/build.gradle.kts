plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Allineato al package reale
    namespace = "it.xpan.panapp"

    // Richiesto dai plugin recenti (file_picker, geolocator, etc.)
    compileSdk = 36

    defaultConfig {
        applicationId = "it.xpan.panapp"

        // Manteniamo la massima compatibilità con device datati (di default Flutter = 21)
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    // Java/Kotlin moderni per AGP 8.x
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Desugaring per retro-compatibilità su API basse
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    // Tipica configurazione per debug/release locali
    buildTypes {
        release {
            // Per build locali usiamo la firma di debug (evita setup keystore)
            signingConfig = signingConfigs.getByName("debug")
            // Niente minify/shrink per evitare sorprese mentre sviluppi
            isMinifyEnabled = false
        }
        debug {
            // In debug generiamo il classico app-debug.apk (assembleDebug)
            isDebuggable = true
            applicationIdSuffix = ".debug"
        }
    }

    // (facoltativo) Se usi flavor, possiamo forzare l’output APK per ciascun variant.
    // Con AGP 8.x assembleDebug produce comunque l'APK nella cartella standard.
}

flutter {
    source = "../.."
}

dependencies {
    // Librerie per desugaring (retrofit di API Java moderne su device vecchi)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
