<?php
/* ═══════════════════════════════════════════════════════════════════════════
   Vizitor — آتیران ویزیتور | لایهٔ اتصال دیتابیس (lib/db.php)
   Developed by Milano Technical Team, Milad Yaghoobi
   ─────────────────────────────────────────────────────────────────────────
   اتصال PDO به SQL Server با درایور sqlsrv (Microsoft PHP Driver).
   نکته: درایور sqlsrv تمام اعداد را «رشته» برمی‌گرداند؛ تبدیل نوع در repo.php
   انجام می‌شود تا JSON خروجی برای اپ اندروید (Gson) درست باشد.
   ═══════════════════════════════════════════════════════════════════════════ */

declare(strict_types=1);

/**
 * اتصال یگانه به دیتابیس (singleton).
 * @param array $config آرایهٔ تنظیمات کامل (config.php)
 */
function vizitor_db(array $config): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $db  = $config['db'];
    $dsn = sprintf(
        'sqlsrv:Server=%s,%d;Database=%s;LoginTimeout=5;Encrypt=%s;TrustServerCertificate=%s',
        $db['host'],
        (int) $db['port'],
        $db['name'],
        !empty($db['encrypt']) ? '1' : '0',
        !empty($db['trust_server_certificate']) ? '1' : '0'
    );

    $pdo = new PDO($dsn, $db['user'], $db['pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ]);

    return $pdo;
}

/** آیا درایور sqlsrv روی این PHP نصب است؟ (برای پیام خطای گویا) */
function vizitor_driver_available(): bool
{
    return in_array('sqlsrv', PDO::getAvailableDrivers(), true);
}

/** فهرست درایورهای موجود — برای عیب‌یابی در کارت سلامت */
function vizitor_pdo_drivers(): array
{
    return PDO::getAvailableDrivers();
}
