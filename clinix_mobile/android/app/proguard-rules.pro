# R8 / ProGuard rules for Clinix release builds.
# Without these, isMinifyEnabled = true would strip classes that the runtime
# loads via reflection (Firebase, Agora, AndroidX startup, etc) and the app
# would crash on launch.

# ---- Flutter -------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---- Firebase ------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---- Agora RTC -----------------------------------------------------------
-keep class io.agora.** { *; }
-keep class io.agora.rtc2.** { *; }
-keep class io.agora.spatialaudio.** { *; }
-dontwarn io.agora.**

# ---- CallKit / ConnectionService -----------------------------------------
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-keep class android.telecom.** { *; }
-dontwarn android.telecom.**

# ---- Google Play Services / OAuth ----------------------------------------
-keep class com.google.api.** { *; }
-keep class com.google.auth.** { *; }
-keep class com.google.cloud.** { *; }

# ---- AndroidX --------------------------------------------------------------
-keep class androidx.** { *; }
-dontwarn androidx.**

# ---- Suppress warnings for classes we know aren't on this platform --------
-dontwarn java.lang.invoke.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# Generic safety: keep enums + Parcelables intact (reflective ops).
-keepclassmembers enum * { *; }
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep custom Application, Activity, Service entry points
-keep public class * extends android.app.Application
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
