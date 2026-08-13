# Keep Razorpay classes
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Keep ProGuard annotation classes
-keep class proguard.annotation.Keep
-keep @proguard.annotation.Keep class * { *; }
-keepclassmembers class * {
    @proguard.annotation.Keep *;
}

# ========== Firebase (required for release build – FCM/notifications) ==========
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Gson (used by Firebase for message parsing)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Firebase Messaging – keep service and model classes
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Flutter engine and plugins (avoid stripping plugin registration)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# ========== Printer Support ==========

# Keep AIDL-generated classes for SUNMI printer
-keep class woyou.aidlservice.jiuiv5.** { *; }
-dontwarn woyou.aidlservice.jiuiv5.**

# Keep Sumi printer related classes (if different from Sunmi)
-keep class com.summi.** { *; }
-keep class com.sumi.printer.** { *; }
-dontwarn com.sumi.**
-dontwarn com.sumi.printer.**

# Bluetooth thermal printer support
-keep class com.printbluetooththermal.** { *; }
-dontwarn com.printbluetooththermal.**

# ESC/POS printer support
-keep class com.escpos.** { *; }
-keep class com.epson.** { *; }
-dontwarn com.escpos.**
-dontwarn com.epson.**

# Pinelabs printer support
-keep class com.pinelabs.** { *; }
-keep class com.pinelabs.printer.** { *; }
-dontwarn com.pinelabs.**
-dontwarn com.pinelabs.printer.**

# Generic Bluetooth printer classes
-keep class android.bluetooth.** { *; }
-keep class android.print.** { *; }
-dontwarn android.bluetooth.**
-dontwarn android.print.**

# Keep all printer service implementations
-keep class * implements android.print.PrintService { *; }
-keep class * extends android.print.PrintService { *; }