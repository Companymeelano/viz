#!/bin/sh
# ═══════════════════════════════════════════════════════════════════════════
#  Vizitor — آتیران ویزیتور | راه‌انداز Gradle Wrapper (Linux/macOS)
#  Developed by Milano Technical Team, Milad Yaghoobi
#  ─────────────────────────────────────────────────────────────────────────
#  استفاده:  ./gradlew assembleRelease
#  این اسکریپت مستقیماً JAR رسمی Gradle Wrapper را اجرا می‌کند
#  (نسخهٔ Gradle از gradle/wrapper/gradle-wrapper.properties خوانده می‌شود).
# ═══════════════════════════════════════════════════════════════════════════
set -e

APP_HOME=$(cd "$(dirname "$0")" && pwd)
WRAPPER_JAR="$APP_HOME/gradle/wrapper/gradle-wrapper.jar"

if [ ! -f "$WRAPPER_JAR" ]; then
    echo "خطا: فایل gradle/wrapper/gradle-wrapper.jar یافت نشد." >&2
    exit 1
fi

if [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    JAVACMD="$JAVA_HOME/bin/java"
else
    JAVACMD="java"
fi

if ! command -v "$JAVACMD" >/dev/null 2>&1; then
    echo "خطا: Java پیدا نشد. نیاز به JDK 17 است (JAVA_HOME را تنظیم کنید)." >&2
    exit 1
fi

exec "$JAVACMD" -Xmx64m -Xms64m -Dorg.gradle.appname=gradlew \
    -classpath "$WRAPPER_JAR" org.gradle.wrapper.GradleWrapperMain "$@"
