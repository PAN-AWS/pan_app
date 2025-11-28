# Mantieni classi base Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase (Auth/Firestore/Storage) – mantieni modelli/serializer riflessivi
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# GSON (nel caso librerie usino riflessione)
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-keep class com.google.gson.** { *; }

# Geolocator/Geocoding (evita warning su riflessione)
-dontwarn androidx.core.**
-dontwarn com.google.android.play.core.tasks.**
