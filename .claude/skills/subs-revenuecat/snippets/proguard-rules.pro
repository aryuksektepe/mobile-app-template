# ProGuard / R8 rules for purchases_flutter (Android release builds).
# RC SDK ships its own consumer rules — these are only needed if you see
# runtime crashes from missing classes after enabling minification.
#
# Place at: android/app/proguard-rules.pro
# Reference in: android/app/build.gradle.kts
#   buildTypes {
#     release {
#       isMinifyEnabled = true
#       proguardFiles(
#         getDefaultProguardFile("proguard-android-optimize.txt"),
#         "proguard-rules.pro"
#       )
#     }
#   }

# RevenueCat SDK
-keep class com.revenuecat.purchases.** { *; }
-keep interface com.revenuecat.purchases.** { *; }

# Google Play Billing Library (8.x)
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.api.**

# Kotlinx coroutines used by RC
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
