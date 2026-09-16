# فایل نصب و راه‌اندازی سرور آتیران ویزیتور

**Developed by Milano Technical Team — Milad Yaghoobi**

این بسته، وب‌سرویس سرور اپلیکیشن «آتیران ویزیتور» را به‌صورت **تمام‌خودکار** روی
ویندوز نصب می‌کند: IIS + PHP + درایور SQLSRV + اتصال به SQL Server + ساخت
دیتابیس + ساخت کاربر ویزیتور + تولید کلید API + تست سرتاسری.

---

## ۱) در یک نگاه

| مرحله | دستور |
|---|---|
| نصب کامل (ساده‌ترین حالت) | راست‌کلیک روی `Setup-VizitorServer.ps1` → **Run with PowerShell** (یا ترمینال ادمین) |
| نصب با پورت و HTTPS | `.\Setup-VizitorServer.ps1 -Port 8731 -Https` |
| نصب بدون اینترنت | `.\Setup-VizitorServer.ps1 -OfflinePackagePath D:\VizitorOffline` |
| دیتابیس روی سرور دیگر | `.\Setup-VizitorServer.ps1 -DbHost SRV-SQL01 -SkipSqlConfiguration` |

> پیش‌نیاز: ویندوز ۱۰/۱۱ یا Windows Server 2019/2022 با دسترسی Administrator،
> SQL Server 2016 یا جدیدتر، و (برای نصب آنلاین) اتصال اینترنت.

در پایان نصب، اسکریپت یک **کارت تنظیمات** چاپ می‌کند که همان مقادیر را باید در
اپ وارد کنید: آدرس سرور، پورت، کلید API، نام کاربری و رمز عبور. خلاصهٔ همین
اطلاعات در `C:\ProgramData\Vizitor\install-info.txt` هم ذخیره می‌شود.

---

## ۲) اسکریپت خودکار چه کارهایی انجام می‌دهد؟

| # | کار | جزئیات |
|---|---|---|
| ۱ | نصب IIS | همراه CGI/FastCGI، لاگ، RequestFiltering (روی سرور: `Install-WindowsFeature`، روی ویندوز: `Enable-WindowsOptionalFeature`) |
| ۲ | نصب PHP 8.3 | نسخهٔ NTS x64 از `downloads.php.net`، استخراج در `C:\PHP`، ساخت `php.ini` بهینه (بدون نمایش خطا، با لاگ، حجم مناسب آپلود) |
| ۳ | درایور SQLSRV | Microsoft PHP Driver v5.13.3 برای PHP 8.3 (`php_sqlsrv_83_nts_x64.dll` + `php_pdo_sqlsrv_83_nts_x64.dll`) |
| ۴ | سایت IIS | Application Pool جدا (بدون Managed Code، AlwaysRunning)، هندر PHP در سطح سرور، `httpErrors=PassThrough` تا خطاهای JSON به اپ برسند |
| ۵ | آماده‌سازی SQL Server | فعال‌سازی TCP/IP روی پورت ۱۴۳۳، تغییر به احراز هویت Mixed Mode، ری‌استارت کنترل‌شدهٔ سرویس با بازگرداندن سرویس‌های وابسته — **با بکاپ رجیستری پیش از هر تغییر** |
| ۶ | دیتابیس | ساخت `AtiranVizitor`، کاربر SQL `vizitor_app` با کمترین دسترسی (`db_datareader` + `db_datawriter`)، اجرای `01_schema.sql` و `02_seed.sql` |
| ۷ | کاربر اپ | ساخت کاربر ویزیتور با رمز هش‌شده (`password_hash`) + تولید کلید API تصادفی ۴۰ نویسه‌ای و نوشتن `config.php` |
| ۸ | فایروال و تست | باز کردن پورت فقط برای شبکهٔ محلی + اجرای `php -l` روی همهٔ فایل‌ها + تست `action=ping` و `action=login` |

---

## ۳) پارامترهای کامل اسکریپت

```powershell
.\Setup-VizitorServer.ps1 `
    -SiteName Vizitor `
    -Port 8731 `
    -Https `
    -DbHost "." `
    -DbName "AtiranVizitor" `
    -DbUser "vizitor_app" `
    -DbPassword "<رمز دلخواه>" `
    -AppUser "vizitor" -AppPassword "<رمز اپ>" `
    -ApiKey "<کلید ۴۰ نویسه‌ای>" `
    -PhpPath "C:\PHP" -SitePath "C:\inetpub\Vizitor" `
    -OfflinePackagePath "D:\VizitorOffline" `
    -NoSqlRestart -SkipSqlConfiguration -SkipFirewall -Force
```

| پارامتر | پیش‌فرض | توضیح |
|---|---|---|
| `-Port` | `8731` | پورت وب‌سرویس (همین را در اپ وارد می‌کنید) |
| `-Https` | خاموش | ساخت گواهی خودامضا + بایندینگ HTTPS روی همان پورت |
| `-DbHost` | `.` | نمونهٔ SQL Server؛ برای سرور مجزا مثل `SRV-SQL01` یا `10.0.0.5,1433` |
| `-DbName` / `-DbUser` / `-DbPassword` | `AtiranVizitor` / `vizitor_app` / تصادفی | دیتابیس و کاربر SQL |
| `-AppUser` / `-AppPassword` | `vizitor` / تصادفی | کاربر ورود اپ (رمز هش‌شده ذخیره می‌شود) |
| `-ApiKey` | تصادفی | کلید مشترک اپ و سرور |
| `-OfflinePackagePath` | — | پوشهٔ شامل `php-8.3.33-nts-Win32-vs16-x64.zip` و `Windows_5.13.3RTW.zip` برای نصب بدون اینترنت |
| `-SkipSqlConfiguration` | خاموش | هیچ تغییری در SQL Server این سرور نده (دیتابیس جای دیگر است) |
| `-NoSqlRestart` | خاموش | تنظیمات SQL اعمال شود ولی سرویس ری‌استارت نشود (برای ساعت کاری) |
| `-SkipFirewall` | خاموش | قاعدهٔ فایروال ساخته نشود |
| `-Force` | خاموش | بدون پرسش‌های تأییدی اجرا شود (نصب بی‌نظارت) |

> ⚠️ اسکریپت روی سرویس SQL Server تغییر تنظیمات می‌دهد (TCP/IP و Mixed Mode).
> پیش از هر تغییر بکاپ `.reg` در `C:\ProgramData\Vizitor\backup` گرفته می‌شود،
> اما اگر نرم‌افزار حسابداری روی همین سرور در حال استفاده است، اجرای نصب را به
> بعد از ساعت کاری موکول کنید یا از `-NoSqlRestart` استفاده کنید.

---

## ۴) تنظیمات اپ اندروید (مطابق کارت پایان نصب)

در اپ: **تنظیمات → پیکربندی سرور آتیران**

| فیلد اپ | مقدار |
|---|---|
| آدرس IP سرور | IP سرور ویندوز (کارت نصب آن را چاپ می‌کند) |
| پورت وب‌سرویس | همان `-Port` (پیش‌فرض `8731`) |
| پورت SQL Server | `1433` (فقط نمایشی/لاگ) |
| مسیر API | **خالی** بگذارید (سایت روی ریشه است؛ اگر زیرپوشه گذاشتید همان نام پوشه) |
| کلید API | کلید ۴۰ نویسه‌ای پایان نصب |
| اتصال امن (HTTPS) | اگر با `-Https` نصب کرده‌اید **روشن**، در غیر این صورت **خاموش** |
| نام کاربری / رمز | `-AppUser` / `-AppPassword` پایان نصب |

سپس دکمهٔ **«تست سلامت اتصال»** را بزنید؛ باید نام دیتابیس، نسخهٔ PHP، نسخهٔ
API و شمارش رکورد جداول را نشان بدهد.

> **نسخهٔ اپ:** کلید «اتصال امن (HTTPS)» از نسخهٔ **v2.17.2** به اپ اضافه شده است.
> نسخه‌های قدیمی‌تر فقط با HTTPS کار می‌کنند؛ برای نصب روی شبکهٔ داخلی با HTTP،
> حتماً از APK نسخهٔ v2.17.2 یا جدیدتر استفاده کنید.

---

## ۵) نصب دستی (اگر اسکریپت خودکار در دسترس نبود)

۱. **IIS**: `Install-WindowsFeature Web-Server, Web-CGI, Web-Filtering -IncludeManagementTools`
۲. **PHP 8.3 NTS x64**: دانلود از <https://windows.php.net/downloads/releases/> →
   استخراج در `C:\PHP` → کپی `php.ini-development` به `php.ini` →
   فعال‌کردن `extension_dir = "ext"`، `cgi.fix_pathinfo=1`، `extension=mbstring`، `extension=openssl`
۳. **درایور SQLSRV**: دانلود `Windows_5.13.3RTW.zip` از
   <https://github.com/microsoft/msphpsql/releases> → کپی فایل‌های
   `php_sqlsrv_83_nts_x64.dll` و `php_pdo_sqlsrv_83_nts_x64.dll` به `C:\PHP\ext` →
   افزودن دو خط `extension=` به `php.ini`
۴. **IIS Manager** → Application Pool جدید (No Managed Code) → Site جدید روی پورت دلخواه →
   Handler Mapping برای `*.php` با `FastCgiModule` و `C:\PHP\php-cgi.exe` →
   در `Configuration Editor` مقدار `system.webServer/httpErrors → existingResponse` را
   روی `PassThrough` بگذارید
۵. **دیتابیس**:
   ```powershell
   sqlcmd -S . -E -d master -Q "CREATE DATABASE AtiranVizitor"
   sqlcmd -S . -E -d AtiranVizitor -f 65001 -i .\sql\01_schema.sql
   sqlcmd -S . -E -d AtiranVizitor -f 65001 -i .\sql\02_seed.sql
   ```
۶. **کاربر SQL و کاربر اپ**: طبق بخش ۶ همین راهنما
۷. **config.php**: کپی `web\config.sample.php` روی `config.php` و پر کردن مقادیر
۸. فایل‌های پوشهٔ `web` را در ریشهٔ سایت کپی کنید (همراه `web.config`)

---

## ۶) ساخت کاربر ورود اپ (رمز هش‌شده)

```powershell
php -r "$h = password_hash('رمز-دلخواه', PASSWORD_DEFAULT); echo $h;"
```

سپس در SQL Server:

```sql
INSERT INTO dbo.VizitorUsers (Username, PasswordHash, VisitorCode, DisplayName, Role)
VALUES (N'vahid', N'<هش-تولیدشده>', N'VIS-02', N'وحید رضایی', N'visitor');
```

نقش‌های مجاز: `admin` | `accountant` | `visitor`.

---

## ۷) اندپوینت‌های وب‌سرویس (قرارداد اپ)

| متد | آدرس | توضیح |
|---|---|---|
| GET | `index.php?action=ping` | سلامت سرور + شمارش رکوردها (فقط کلید API) |
| GET | `index.php?action=version` | نسخهٔ API و PHP |
| POST | `index.php?action=login` | ورود؛ خروجی: `access_token`, `expires_at` (UTC), `user` |
| GET | `index.php?action=catalog&since=<ms>` | کاتالوگ کالا |
| GET | `index.php?action=customers&since=<ms>` | فهرست مشتریان |
| GET | `index.php?action=sal_mali&customer_id=<id>` | تاریخچه خرید سال مالی مشتری |
| POST | `index.php?action=submit_invoice` | ثبت فاکتور (تکرارناپذیر با `client_invoice_id`) |
| POST | `index.php?action=submit_customer` | درخواست ثبت مشتری جدید (جهت تأیید حسابداری) |

همهٔ درخواست‌ها هدر `X-Api-Key` می‌خواهند؛ به‌جز `ping` و `version`، بقیه
`Authorization: Bearer <token>` هم لازم دارند. قالب پاسخ:

```json
{ "success": true, "message": "…", "data": { } }
```

نمونهٔ آزمون دستی:

```powershell
$key = 'کلید-API'
Invoke-RestMethod "http://localhost:8731/index.php?action=ping" -Headers @{ 'X-Api-Key' = $key } | ConvertTo-Json -Depth 5
```

---

## ۸) اتصال به جداول واقعی نرم‌افزار آتیران

وب‌سرویس فقط از **سه نما** می‌خواند: `vwVizitorProducts`، `vwVizitorCustomers`،
`vwVizitorSalMali`. تا زمانی که نماها به جداول واقعی وصل نشده‌اند، دادهٔ نمونهٔ
`02_seed.sql` نمایش داده می‌شود؛ برای اتصال:

۱. نام واقعی جدول/ستون‌های آتیران را با این کوئری پیدا کنید:
   ```sql
   SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
   FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_NAME IN (N'کالا', N'مشتری', N'فاکتور')
   ORDER BY TABLE_NAME, ORDINAL_POSITION;
   ```
۲. فایل `sql\03_erp_views_template.sql` را بر همان اساس ویرایش کنید.
۳. اجرا کنید:
   ```powershell
   sqlcmd -S . -E -d AtiranVizitor -f 65001 -i .\sql\03_erp_views_template.sql
   ```

نکته: با این کار **هیچ داده‌ای کپی نمی‌شود و هیچ نوشتنی روی جداول حسابداری انجام
نمی‌شود**؛ نماها فقط خواندنی هستند.

---

## ۹) فهرست فایل‌های بسته

```
server/
├── Setup-VizitorServer.ps1        ← نصب‌کنندهٔ خودکار (راه اصلی)
├── README.md                      ← همین راهنما
├── sql/
│   ├── 01_schema.sql              ← ۱۱ جدول + ۳ نمای قراردادی + ایندکس‌ها
│   ├── 02_seed.sql                ← داده نمونهٔ فارسی (کالا/مشتری/فروش)
│   └── 03_erp_views_template.sql  ← قالب اتصال نماها به جداول واقعی آتیران
└── web/
    ├── index.php                  ← روتر وب‌سرویس (۸ اندپوینت)
    ├── config.sample.php          ← نمونهٔ فایل تنظیمات
    ├── web.config                 ← تنظیمات سایت IIS (JSON خطاها، پیش‌فرض index.php)
    └── lib/
        ├── db.php                 ← اتصال PDO/sqlsrv
        ├── http.php               ← قالب پاسخ JSON + تبدیل تاریخ شمسی
        ├── auth.php               ← کلید API، توکن Bearer، محدودیت تلاش ورود
        └── repo.php               ← کوئری‌های سه نما و ثبت فاکتور/مشتری
```

---

## ۱۰) سازوکارهای امنیتی و پایداری

- **دو لایهٔ احراز هویت**: کلید API مشترک + توکن نشست کاربر (رمزها با
  `password_hash`/`bcrypt`، توکن‌ها فقط به‌صورت SHA-256 در دیتابیس).
- **محدودیت تلاش ورود**: پیش‌فرض ۵ خطا در ۱۵ دقیقه → قفل موقت حساب.
- **تکرارناپذیری فاکتور**: `client_invoice_id` یکتاست؛ ارسال دوباره همان شمارهٔ
  فاکتور را برمی‌گرداند (بدون ثبت تکراری).
- **راستی‌آزمایی جمع‌ها**: اگر جمع اقلام با مبلغ ناخالص نخواند، فاکتور رد می‌شود
  (`strict_totals = true`) — این تور امنیتی، خطای نسخه‌های قدیمی اپ را می‌گیرد.
- **حسابرسی**: همهٔ درخواست‌ها در `VizitorApiLog` (کاربر، IP، مدت پاسخ، نتیجه)
  ثبت می‌شوند.
- **شماره‌دهی اسناد**: شمارهٔ فاکتور `VZ-<سال شمسی>-000123` و درخواست مشتری
  `CR-<سال شمسی>-000001` از جدول `VizitorSequences` و به‌صورت اتمیک.
- **کمترین دسترسی**: کاربر SQL اپ فقط `db_datareader` + `db_datawriter` روی همان
  دیتابیس است و دسترسی `sysadmin` ندارد.

---

## ۱۱) عیب‌یابی سریع

| نشانه | راه‌حل |
|---|---|
| اپ می‌گوید «کلید API نامعتبر است» | کلید پایان نصب را دوباره در اپ وارد کنید (`C:\ProgramData\Vizitor\install-info.txt`) |
| اپ می‌گوید «اتصال برقرار نشد» | در اپ فقط **IP و پورت** را وارد کنید (بدون `http://`)؛ کلید HTTPS را مطابق نصب تنظیم کنید؛ پورت در فایروال باز باشد |
| خطای ۵۰۰ با پیام «درایور SQLSRV نصب نیست» | خروجی `php -m` را در `C:\PHP` بگیرید و نام DLL را با نسخهٔ PHP تطبیق دهید (۸.۳.۳۳ → `php_sqlsrv_83b_nts_x64.dll`) |
| خطای اتصال دیتابیس | `sqlcmd -S . -E -Q "SELECT 1"` را تست کنید؛ نام دیتابیس/کاربر/رمز در `site\config.php` |
| صفحهٔ HTML خطای IIS به‌جای JSON | در IIS Manager → Configuration Editor → `system.webServer/httpErrors` → `existingResponse = PassThrough` (اسکریپت این را خودکار انجام می‌دهد) |
| دانلود PHP/SQLSRV ناموفق | فایل‌ها را دستی دانلود کنید و با `-OfflinePackagePath` بدهید |
| تغییرات SQL اعمال نشد | سرویس SQL Server را ری‌استارت کنید (یا اسکریپت را بدون `-NoSqlRestart` اجرا کنید) |

لاگ‌ها: `C:\ProgramData\Vizitor\setup-*.log` (نصب) و `C:\PHP\logs\php-error.log` (اجرا).
