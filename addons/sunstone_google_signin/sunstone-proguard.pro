# R8 for Sunstone's release builds (copied into the Gradle build and enabled by
# addons/sunstone_google_signin/export_plugin.gd _enable_r8). Shrink and
# optimise, but don't rename: Crashlytics then needs no mapping upload.
-dontobfuscate
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

# Godot calls into Java by name (JNI, plugin reflection, JavaClassWrapper).
-keep class org.godotengine.** { *; }
-keep class com.godot.game.** { *; }
# Our plugin and the other Godot plugins: their methods are called by name.
-keep class com.pranta.sunstone.** { *; }
-keep class com.poingstudios.** { *; }
-dontwarn org.godotengine.**
