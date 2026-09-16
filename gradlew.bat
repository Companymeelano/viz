@rem ═══════════════════════════════════════════════════════════════════════════
@rem  Vizitor — آتیران ویزیتور | راه‌انداز Gradle Wrapper (Windows)
@rem  Developed by Milano Technical Team, Milad Yaghoobi
@rem  ─────────────────────────────────────────────────────────────────────────
@rem  استفاده:  gradlew.bat assembleRelease
@rem ═══════════════════════════════════════════════════════════════════════════
@echo off
setlocal

set APP_HOME=%~dp0
if "%APP_HOME%"=="" set APP_HOME=.\

if defined JAVA_HOME (
  set JAVA_EXE=%JAVA_HOME%\bin\java.exe
) else (
  set JAVA_EXE=java.exe
)

"%JAVA_EXE%" -Xmx64m -Xms64m "-Dorg.gradle.appname=gradlew" -classpath "%APP_HOME%gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
set EXIT_CODE=%ERRORLEVEL%

endlocal & exit /b %EXIT_CODE%
