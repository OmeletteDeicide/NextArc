-keep class com.dexterous.** { *; }
# Fournisseur SafetyNet exclu du build (voir build.gradle.kts) : référencé par
# le plugin App Check mais jamais utilisé.
-dontwarn com.google.firebase.appcheck.safetynet.**
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
