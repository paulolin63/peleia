# ProGuard / R8 rules para PeleIA
# Permitir que o R8 otimize, encolha e ofusque o código DEX acima de 50%+

# Preserva anotações e reflexão necessárias
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Suprime avisos benignos de bibliotecas externas
-dontwarn com.google.**
-dontwarn kotlin.**
-dontwarn io.flutter.**
-dontwarn com.revenuecat.**
-dontwarn org.bouncycastle.**

# Multidex
-keep class androidx.multidex.** { *; }

