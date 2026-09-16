/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  Vizitor — آتیران ویزیتور | بیلد اسکریپت ریشه (build.gradle.kts)
 *  Developed by Milano Technical Team, Milad Yaghoobi
 *  ─────────────────────────────────────────────────────────────────────────
 *  نسخه‌های پلاگین‌ها اینجا متمرکز شده‌اند (منبع یگانهٔ حقیقت نسخه‌ها).
 *  سازگاری تأییدشده:
 *    AGP 8.7.3  →  Gradle 8.9+ (gradle/wrapper) + JDK 17 + compileSdk 35
 *    Kotlin 2.0.21 + پلاگین Compose 2.0.21 (هم‌نسخه با Kotlin)
 *    KSP 2.0.21-1.0.28 (هم‌نسخه با Kotlin — برای Room)
 * ═══════════════════════════════════════════════════════════════════════════
 */
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
    id("com.google.devtools.ksp") version "2.0.21-1.0.28" apply false
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
