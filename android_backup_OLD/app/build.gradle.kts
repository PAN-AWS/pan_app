// android/app/build.gradle.kts  (MODULE-LEVEL)

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

    // 🔴 Applichiamo il Google Services plugin nel modulo :app
    id("com.google.gms.google-services")
}

// Config Android (usa i valori del template Flutter + i tuoi)
android {
    namespace = "com.example.pan_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID deve coincidere con quello registrato in Firebase
        applicationId = "com.example.pan_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Per ora firmiamo con la debug key, come da template Flutter
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ⚠️ NIENTE dipendenze manuali Firebase qui: i plugin Flutter (firebase_core, cloud_firestore)
// vengono gestiti dal sistema di plugin di Flutter. Il Google Services plugin usa il file
// android/app/google-services.json che è stato (o sarà) scaricato da `flutterfire configure`.
