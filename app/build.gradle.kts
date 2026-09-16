/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  Vizitor — آتیران ویزیتور | اپ‌ماژول (app/build.gradle.kts)
 *  Developed by Milano Technical Team, Milad Yaghoobi
 *  ─────────────────────────────────────────────────────────────────────────
 *  Jetpack Compose + Room + Retrofit + WorkManager + CameraX + ML Kit
 *
 *  یادداشت‌های بیلد (نسخه ۲٫۱۷٫۱):
 *   • نسخه‌گذاری: versionCode از الگوی major*10000 + minor*100 + patch ساخته
 *     می‌شود و باید همیشه صعودی بماند (نسخه ۲٫۱۷٫۱ ← 21701).
 *   • core library desugaring فعال است تا java.time روی اندروید ۷ (API 24/25)
 *     هم کار کند؛ بدون آن AuthStore روی API < 26 کرش می‌کرد.
 *   • امضای release: اگر فایل keystore.properties در ریشه پروژه باشد از کلید
 *     واقعی استفاده می‌شود، در غیر این صورت به کلید debug سقوط می‌کند تا
 *     assembleRelease همیشه یک APK نصب‌شدنی تولید کند (برای انتشار در گوگل‌پلی
 *     باید keystore.properties تنظیم شود).
 * ═══════════════════════════════════════════════════════════════════════════
 */
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

// ── کلید امضای release (اختیاری — از keystore.properties خوانده می‌شود) ────
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) keystorePropsFile.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystorePropsFile.exists() &&
        keystoreProps.getProperty("storeFile") != null

android {
    namespace = "ir.atiran.vizitor"
    compileSdk = 35

    defaultConfig {
        applicationId = "ir.atiran.vizitor"
        minSdk = 24
        targetSdk = 35
        versionCode = 21701
        versionName = "2.17.1"
        vectorDrawables { useSupportLibrary = true }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // اگر کلید واقعی تنظیم شده باشد از آن، وگرنه از کلید debug استفاده می‌شود
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ضروری برای java.time روی minSdk 24 (اندروید ۷)
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    // ── Core Library Desugaring (java.time روی API 24/25) ─────────────────
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.3")

    // ── Compose BOM ────────────────────────────────────────────────────────
    implementation(platform("androidx.compose:compose-bom:2024.09.03"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // ── Core / Navigation / Lifecycle ─────────────────────────────────────
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.navigation:navigation-compose:2.8.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.6")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")

    // ── Room (Offline-First Database) ─────────────────────────────────────
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    // ── WorkManager (Background Sync Service) ─────────────────────────────
    implementation("androidx.work:work-runtime-ktx:2.9.1")

    // ── Retrofit / OkHttp / Gson (Network Layer) ──────────────────────────
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("com.google.code.gson:gson:2.11.0")

    // ── Coroutines ────────────────────────────────────────────────────────
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // ── DataStore (Server Config / Settings) ──────────────────────────────
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // ── CameraX + ML Kit (Barcode Scanner) ────────────────────────────────
    implementation("androidx.camera:camera-core:1.3.4")
    implementation("androidx.camera:camera-camera2:1.3.4")
    implementation("androidx.camera:camera-lifecycle:1.3.4")
    implementation("androidx.camera:camera-view:1.3.4")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
}
