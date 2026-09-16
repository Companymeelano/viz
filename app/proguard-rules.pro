# ═══════════════════════════════════════════════════════════════════════════
#  Vizitor — آتیران ویزیتور | ProGuard / R8 Rules
#  Developed by Milano Technical Team, Milad Yaghoobi
# ═══════════════════════════════════════════════════════════════════════════
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*

# ── Retrofit ───────────────────────────────────────────────────────────────
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# ── Gson: نگه‌داشتن تمام DTOهای قرارداد سرور (بستهٔ واقعی: data.remote) ────
-keep class ir.atiran.vizitor.data.remote.** { *; }
-keepclassmembers class ir.atiran.vizitor.data.remote.** { *; }
# نگه‌داشتن نام فیلدهای Gson-annotated در سراسر اپ
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── Room ───────────────────────────────────────────────────────────────────
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-dontwarn androidx.room.paging.**

# ── WorkManager ────────────────────────────────────────────────────────────
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class ir.atiran.vizitor.data.sync.SyncWorker { *; }

# ── AndroidX CameraX (کارخانه‌های بازتابی) ─────────────────────────────────
-dontwarn androidx.camera.**

# ── OkHttp / Okio ──────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ── Kotlin / Coroutines ────────────────────────────────────────────────────
-dontwarn kotlinx.coroutines.**
-dontwarn org.jetbrains.annotations.**

# ── ML Kit ─────────────────────────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ── ViewModel اپ (بازتاب از طریق Navigation/Compose) ───────────────────────
-keep class ir.atiran.vizitor.VizitorViewModel { *; }
