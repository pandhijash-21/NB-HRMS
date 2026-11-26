# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress Play Store deferred component warnings
-dontwarn com.google.android.play.core.**

# Keep AppWidget Providers and RemoteViews
-keep class com.nbdeveloper.nb_crm_flutter.AttendanceWidgetProvider {
    public <init>();
    public *;
}
-keep class * extends android.appwidget.AppWidgetProvider {
    public <init>();
    public *;
}

# Keep home_widget classes
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# Keep all R classes and drawables/layouts referenced by RemoteViews
-keepclassmembers class **.R$* {
    public static <fields>;
}
