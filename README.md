# آتیران ویزیتور — Vizitor

اپلیکیشن اندروید **ویزیتور پخش آجیل و خشکبار** (کاتالوگ زنده، سبد سفارش، صدور فاکتور با امضای
دیجیتال، مشتریان و اعتبار، گردش حساب، اسکنر بارکد و همگام‌سازی با سرور آتیران).
آفلاین‌اول با Room — بدون شبکه هم کامل کار می‌کند و پس از اتصال، خودکار سینک می‌شود.

## ⬇️ دانلود نسخهٔ آمادهٔ نصب (APK)

| فایل | حجم | برای چه کسی |
|---|---|---|
| **[Vizitor-v2.17.2-release.apk](https://github.com/Companymeelano/viz/releases/download/v2.17.2/Vizitor-v2.17.2-release.apk)** | ۲۵ مگابایت | کاربر نهایی — بهینه‌شده با R8 |
| **[Vizitor-v2.17.2-debug.apk](https://github.com/Companymeelano/viz/releases/download/v2.17.2/Vizitor-v2.17.2-debug.apk)** | ۴۴ مگابایت | تست و عیب‌یابی (شناسهٔ جدا: `ir.atiran.vizitor.debug`) |

همهٔ نسخه‌ها: [صفحهٔ Releases](https://github.com/Companymeelano/viz/releases) ·
برای نصب، در گوشی «نصب از منابع نامشخص» را برای مرورگر/فایل‌منیجر فعال کنید.

> 🆕 در نسخهٔ **2.17.2**: کلید **«اتصال امن (HTTPS)»** به تنظیمات اضافه شد تا اپ روی
> شبکهٔ داخلی شرکت (سرور HTTP) هم بتواند به وب‌سرویس وصل شود؛ پیش از این اپ فقط با
> HTTPS کار می‌کرد. برای نصب سرور، به **[بستهٔ نصب سرور](#️-نصب-و-راهاندازی-سرور-فایل-نصب)**
> در همین صفحه مراجعه کنید.

> 🔑 نسخهٔ release فعلی با **کلید debug** امضا شده است (چون `keystore.properties` تنظیم نشده).
> برای انتشار رسمی، کلید اختصاصی خود را در بخش ۳ پایین تنظیم کنید — در آن صورت باید نسخهٔ
> نصب‌شدهٔ فعلی را یک‌بار حذف کنید تا امضای جدید پذیرفته شود.

| مورد | مقدار |
|---|---|
| نسخه | `2.17.2` (versionCode `21702`) |
| Kotlin / AGP / Gradle | 2.0.21 / 8.7.3 / 8.9 |
| compileSdk / targetSdk / minSdk | 35 / 35 / 24 |
| پشته | Jetpack Compose، Room، WorkManager، Retrofit، CameraX + ML Kit |

---

## 🖥️ نصب و راه‌اندازی سرور (فایل نصب)

بستهٔ کامل نصب خودکار سرور در پوشهٔ **[`server/`](server/)** این مخزن است و به‌صورت
فایل زیپ آمادهٔ دانلود هم منتشر می‌شود:

| فایل | توضیح |
|---|---|
| **[vizitor-server-1.0.0.zip](https://github.com/Companymeelano/viz/releases/download/server-v1.0.0/vizitor-server-1.0.0.zip)** | بستهٔ نصب خودکار سرور (اسکریپت + وب‌سرویس + اسکریپت‌های SQL + راهنما) |

اسکریپت `Setup-VizitorServer.ps1` با یک بار اجرا (با دسترسی Administrator) این‌ها را
خودکار انجام می‌دهد:

1. نصب و راه‌اندازی **IIS** همراه CGI/FastCGI
2. نصب **PHP 8.3** (NTS x64) و ساخت `php.ini` مناسب وب‌سرویس
3. نصب **درایور Microsoft SQLSRV** (`sqlsrv` + `pdo_sqlsrv`)
4. ساخت سایت IIS روی پورت دلخواه + هندر PHP + `httpErrors=PassThrough`
5. فعال‌سازی TCP/IP و پورت ۱۴۳۳ در **SQL Server** + احراز هویت Mixed Mode (با بکاپ رجیستری)
6. ساخت دیتابیس `AtiranVizitor`، کاربر SQL کم‌دسترسی و اجرای اسکریپت‌های ساختار + داده نمونه
7. ساخت کاربر ویزیتور و تولید **کلید API** و نوشتن `config.php`
8. قاعدهٔ فایروال + آزمون سرتاسری `action=ping` و `action=login` و چاپ کارت تنظیمات اپ

```powershell
# روی سرور ویندوز، در پوشهٔ استخراج‌شده:
.\Setup-VizitorServer.ps1 -Port 8731
```

راهنمای کامل (پارامترها، نصب دستی، اتصال به جداول واقعی آتیران، عیب‌یابی):
**[server/README.md](server/README.md)**

---

## ۱) ساخت APK — روش ساده (Android Studio)

1. **Android Studio** نسخهٔ ۲۰۲۴٫۱ (Ladybug) یا جدیدتر را نصب کنید.
2. `File ▸ Open` و انتخاب همین پوشهٔ پروژه (نه فایل ZIP).
3. اگر SDK 35 نصب نیست: `Tools ▸ SDK Manager` و نصب **Android 15 (API 35)** + **Android SDK Build-Tools 35**.
   (JDK 17 همراه خود Android Studio می‌آید و نیازی به نصب جداگانه نیست.)
4. `Build ▸ Build Bundle(s)/APK(s) ▸ Build APK(s)`
5. مسیر خروجی:

```
app/build/outputs/apk/debug/app-debug.apk      → برای نصب و تست سریع
app/build/outputs/apk/release/app-release.apk  → نسخهٔ بهینه‌شدهٔ نهایی
```

> ⚠️ نسخهٔ **debug** با شناسهٔ `ir.atiran.vizitor.debug` نصب می‌شود (کنار اپ اصلی) و متناسب با تست است؛
> برای تحویل به کاربر، همیشه APK **release** را بدهید.

---

## ۲) ساخت APK — روش خط فرمان

پیش‌نیازها: **JDK 17** روی مسیر (`JAVA_HOME`) و **Android SDK** با `platforms/android-35` و
`build-tools/35.0.0`. مسیر SDK باید در فایل `local.properties` باشد:

```properties
sdk.dir=C:\\Users\\<user>\\AppData\\Local\\Android\\Sdk
```

سپس در ریشهٔ پروژه:

```bash
# ویندوز
gradlew.bat clean assembleDebug
gradlew.bat clean assembleRelease

# لینوکس / مک
./gradlew clean assembleDebug
./gradlew clean assembleRelease
```

---

## ۳) امضای نسخهٔ release با کلید اختصاصی

اگر فایل `keystore.properties` در ریشهٔ پروژه نباشد، نسخهٔ release به‌صورت خودکار با **کلید debug**
امضا می‌شود (APK نصب‌شدنی است، ولی برای انتشار در گوگل‌پلی یا فروشگاه‌های ایرانی معتبر نیست).
برای امضای واقعی، ابتدا یک کلید بسازید:

```bash
keytool -genkeypair -v -keystore vizitor-release.jks -alias vizitor \
        -keyalg RSA -keysize 2048 -validity 10000
```

سپس فایل `keystore.properties` را در ریشهٔ پروژه بسازید (این فایل در `.gitignore` است و کامیت نمی‌شود):

```properties
storeFile=vizitor-release.jks
storePassword=********
keyAlias=vizitor
keyPassword=********
```

از این پس `assembleRelease` با کلید شما امضا می‌شود.

---

## ۴) بیلد خودکار GitHub Actions

فایل `.github/workflows/build-apk.yml` هر push روی شاخه‌های `main` و `arena/01a0a879-viz`
(و همچنین اجرای دستی از تب Actions) را بیلد می‌کند و این دو آرتیفکت را می‌سازد:

- `Vizitor-v2.17.1-release.apk`
- `Vizitor-v2.17.1-debug.apk`

> 🚫 **توجه مهم:** اجرای Actions روی مخزن **خصوصی** از سهمیهٔ دقایق حساب مصرف می‌کند و در صورت
> پایان سهمیه/مشکل پرداخت، GitHub کار را حتی شروع نمی‌کند و پیام
> «recent account payments have failed or your spending limit needs to be increased» می‌دهد.
> راه‌های رفع: ۱) عمومی‌کردن موقت مخزن (Actions برای مخزن عمومی رایگان و بی‌سقف است)،
> ۲) اصلاح بخش `Settings ▸ Billing & plans`، ۳) بیلد محلی با روش‌های بالا.
>
> لاگ بیلد به‌صورت Artifact آپلود می‌شود و هرگز داخل مخزن کامیت نمی‌شود.

---

## ۵) نسخه‌گذاری

`versionCode` از الگوی `major*10000 + minor*100 + patch` ساخته می‌شود و باید همیشه **صعودی** بماند:

| versionName | versionCode |
|---|---|
| 2.17.1 | 21701 |
| 2.18.0 | 21800 |

محل تعریف: `app/build.gradle.kts` (تنها منبع حقیقت نسخه).

---

## ۶) ساختار پروژه

```
app/src/main/java/ir/atiran/vizitor/
├── VizitorApp.kt / MainActivity.kt / VizitorViewModel.kt
├── ai/                 دستیار هوشمند فروش (Gemini از طریق Cloudflare Worker)
├── data/
│   ├── local/          Room: Entities، Daos، AppDatabase، AuthStore، ChatPrefs، ChequeStore، SeedData
│   ├── remote/         ApiService (Retrofit)، DTOها، RetrofitClient
│   ├── repository/     VizitorRepository (آفلاین‌اول) + SettingsRepository (DataStore)
│   ├── share/          خروجی PDF / Word / تصویر / متن فاکتور
│   └── sync/           SyncWorker (همگام‌سازی پس‌زمینه با WorkManager)
├── perf/               VizitorPerf — تنظیم خودکار جلوه‌ها بر اساس قدرت دستگاه
└── ui/                 navigation، screens (۸ صفحه)، components، theme (۵ پالت)
```

---

## ۷) مستندات و وضعیت کیفیت

گزارش بازبینی فنی کامل (نقاط قوت، باگ‌های بحرانی، امنیت، CI/CD و نقشهٔ راه) در فایل
[`PROJECT-REVIEW.md`](PROJECT-REVIEW.md) قرار دارد. مهم‌ترین موارد باز مانده پیش از تحویل عملیاتی:

1. محاسبهٔ مبلغ فاکتور برای کالاهای وزنی (`VizitorRepository.issueInvoice`).
2. حذف دادهٔ نمایشی (چک/پیام/واریز نمونه) از نسخهٔ release.
3. صف ارسال «مشتریان در انتظار» در `syncAll()`.

---

<p align="center">Developed by Milano Technical Team — Milad Yaghoobi</p>
