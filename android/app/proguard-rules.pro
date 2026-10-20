# ProGuard rules para PeleIA
# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# RevenueCat
-keep class com.revenuecat.** { *; }

# Google Generative AI
-keep class com.google.** { *; }
-dontwarn com.google.**

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**
