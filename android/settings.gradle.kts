pluginManagement {
    val localProps = java.util.Properties()
    val localPropsFile = java.io.File(rootDir, "local.properties")
    if (localPropsFile.exists()) {
        localPropsFile.inputStream().use { localProps.load(it) }
    }
    val flutterSdkPath = localProps.getProperty("flutter.sdk")
        ?: throw IllegalStateException("flutter.sdk non impostato in local.properties")

    // Necessario per i tool di Flutter
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.2" apply false
    // Allineato a 2.1.0
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
