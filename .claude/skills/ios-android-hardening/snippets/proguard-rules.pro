# android/app/proguard-rules.pro
# Keep rules for the default template stack. Add per-SDK rules when new pods/AARs land.
# Validated by booting the release App Bundle on a real device (see verify-release-shrinking.sh).

# ---- Flutter ----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**    { *; }
-keep class io.flutter.view.**    { *; }
-keep class io.flutter.**         { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---- Firebase (auth, firestore, messaging, analytics, crashlytics, RC) ----
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Crashlytics: keep file:line info for symbolication
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep public class * extends java.lang.Exception

# ---- Drift (uses sqlite3_flutter_libs + reflection at codegen time) ----
-keep class com.simolus.** { *; }
-keep class drift.** { *; }
-dontwarn drift.**
# sqlite3 NDK
-keep class org.sqlite.** { *; }

# ---- freezed / json_serializable runtime ----
# freezed-generated classes use simple constructors — usually fine.
# json_serializable: if you use fromJsonWithoutRegistry-style reflection, keep model packages:
# -keep class com.your.app.models.** { *; }   # uncomment + replace with your model package
# Otherwise no rule needed (json_serializable generates standard fromJson code).

# ---- Retrofit / dio_http2_adapter ----
# Dio itself doesn't need rules. If using retrofit_generator-style:
# -keepattributes Signature
# -keepattributes Exceptions

# ---- RevenueCat purchases_flutter ----
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# ---- Google Sign In ----
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ---- Sign in with Apple ----
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }

# ---- Sentry ----
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# ---- flutter_secure_storage ----
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ---- app_links (deep links) ----
-keep class com.llfbandit.app_links.** { *; }

# ---- WebView ----
-keepclassmembers class * extends android.webkit.WebViewClient {
  public *;
}

# ---- Kotlin coroutines (often shrunk too aggressively) ----
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ---- Disable some optimizations that break reflection ----
# (Keep this list MINIMAL — every -dontoptimize/-dontshrink reduces size win)

# Strip log statements in release (saves bytes + hides debug info)
-assumenosideeffects class android.util.Log {
  public static *** d(...);
  public static *** v(...);
}

# If you see a release-only crash:
#   1. enable R8 mapping retracing: tools/r8/build/libs/r8.jar retrace mapping.txt < stack.txt
#   2. add the offending class to keep rules
#   3. re-run verify-release-shrinking.sh
