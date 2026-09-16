<?php
/* ═══════════════════════════════════════════════════════════════════════════
   Vizitor — آتیران ویزیتور | احراز هویت (lib/auth.php)
   Developed by Milano Technical Team, Milad Yaghoobi
   ─────────────────────────────────────────────────────────────────────────
   دو لایهٔ امنیتی، مطابق آنچه اپ می‌فرستد:
     ۱) هدر X-Api-Key  → کلید مشترک اپ و سرور (روی همهٔ اندپوینت‌ها)
     ۲) هدر Authorization: Bearer <token> → توکن نشست پس از ورود کاربر
   توکن‌ها هرگز خام ذخیره نمی‌شوند؛ فقط SHA-256 آن‌ها در دیتابیس می‌ماند.
   ═══════════════════════════════════════════════════════════════════════════ */

declare(strict_types=1);

/** بررسی کلید API — در صورت نادرست بودن، پاسخ ۴۰۱ و پایان اسکریپت */
function vizitor_require_api_key(array $config): void
{
    $expected = (string) ($config['api_key'] ?? '');
    $provided = vizitor_header('X-Api-Key');

    if ($expected === '' || $expected === 'CHANGE_ME') {
        vizitor_fail('کلید API روی سرور تنظیم نشده است — فایل config.php را بررسی کنید.', 500);
    }
    if ($provided === '' || !hash_equals($expected, $provided)) {
        vizitor_fail('کلید API نامعتبر است (تنظیمات اپ → کلید API).', 401);
    }
}

/**
 * بررسی توکن Bearer و برگرداندن کاربر.
 * @return array{id:int,username:string,display_name:string,visitor_code:string,role:string}
 */
function vizitor_require_user(PDO $pdo, array $config): array
{
    $header = vizitor_header('Authorization');
    if ($header === '' || stripos($header, 'Bearer ') !== 0) {
        vizitor_fail('برای این عملیات باید وارد حساب شوید (توکن ورود ارسال نشده).', 401);
    }
    $token = trim(substr($header, 7));
    if ($token === '') {
        vizitor_fail('توکن ورود خالی است.', 401);
    }

    $hash = hash('sha256', $token);
    $stmt = $pdo->prepare(
        'SELECT t.Id AS TokenId, t.ExpiresAt, u.Id, u.Username, u.DisplayName, u.VisitorCode, u.Role, u.IsActive
           FROM dbo.VizitorTokens t
           INNER JOIN dbo.VizitorUsers u ON u.Id = t.UserId
          WHERE t.TokenHash = ? AND t.Revoked = 0'
    );
    $stmt->execute([$hash]);
    $row = $stmt->fetch();

    if (!$row) {
        vizitor_fail('توکن ورود نامعتبر است — دوباره وارد شوید.', 401);
    }
    if ((int) $row['IsActive'] !== 1) {
        vizitor_fail('حساب کاربری غیرفعال است.', 403);
    }

    // ExpiresAt در دیتابیس UTC است (DATETIME2 با SYSUTCDATETIME).
    // درایور sqlsrv ممکن است بخش اعشاری ثانیه را هم برگرداند؛ قبل از پارس حذف می‌شود.
    $expiresRaw = (string) $row['ExpiresAt'];
    if (preg_match('/^(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})/', $expiresRaw, $m)) {
        $expiresRaw = $m[1];
    }
    $expiresTs = strtotime($expiresRaw . ' UTC');
    if ($expiresTs !== false && $expiresTs < time()) {
        vizitor_fail('نشست شما منقضی شده است — دوباره وارد شوید.', 401);
    }

    // به‌روزرسانی زمان آخرین استفاده (بی‌صدا)
    try {
        $upd = $pdo->prepare('UPDATE dbo.VizitorTokens SET LastUsedAt = SYSUTCDATETIME() WHERE Id = ?');
        $upd->execute([(int) $row['TokenId']]);
    } catch (Throwable $e) {
        // بی‌اهمیت
    }

    return [
        'id'           => (int) $row['Id'],
        'username'     => (string) $row['Username'],
        'display_name' => (string) $row['DisplayName'],
        'visitor_code' => (string) $row['VisitorCode'],
        'role'         => (string) $row['Role'],
    ];
}

/**
 * ساخت توکن نشست جدید.
 * @return array{token:string,expires_at:string} expires_at همیشه UTC با قالب «Y-m-d H:i:s»
 */
function vizitor_issue_token(PDO $pdo, array $config, int $userId, string $deviceId): array
{
    $token     = bin2hex(random_bytes(32));            // ۶۴ نویسه
    $ttl       = max(15, (int) ($config['token_ttl_minutes'] ?? 720));
    $expiresTs = time() + ($ttl * 60);
    $expiresAt = gmdate('Y-m-d H:i:s', $expiresTs);     // ⚠️ UTC — اپ همین قالب را انتظار دارد

    $stmt = $pdo->prepare(
        'INSERT INTO dbo.VizitorTokens (UserId, TokenHash, DeviceId, ExpiresAt)
         VALUES (?, ?, ?, ?)'
    );
    $stmt->execute([$userId, hash('sha256', $token), substr($deviceId, 0, 128), $expiresAt]);

    // پاک‌سازی توکن‌های منقضی همان کاربر (نگهداری جدول سبک)
    try {
        $clean = $pdo->prepare('DELETE FROM dbo.VizitorTokens WHERE UserId = ? AND ExpiresAt < SYSUTCDATETIME()');
        $clean->execute([$userId]);
    } catch (Throwable $e) {
        // بی‌اهمیت
    }

    return ['token' => $token, 'expires_at' => $expiresAt];
}

/** تعداد خطاهای ورود اخیر (برای قفل موقت) */
function vizitor_login_failures(PDO $pdo, array $config, string $username): int
{
    $windowMin = max(1, (int) ($config['login_lockout_minutes'] ?? 15));
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) AS c FROM dbo.VizitorLoginAttempts
          WHERE Username = ? AND Success = 0
            AND AttemptedAt > DATEADD(MINUTE, ?, SYSUTCDATETIME())'
    );
    $stmt->execute([substr($username, 0, 64), -$windowMin]);
    return (int) $stmt->fetch()['c'];
}

/** ثبت تلاش ورود (موفق یا ناموفق) */
function vizitor_record_login(PDO $pdo, string $username, bool $success): void
{
    try {
        $stmt = $pdo->prepare(
            'INSERT INTO dbo.VizitorLoginAttempts (Username, IpAddress, Success) VALUES (?, ?, ?)'
        );
        $stmt->execute([substr($username, 0, 64), vizitor_client_ip(), $success ? 1 : 0]);
    } catch (Throwable $e) {
        // بی‌اهمیت
    }
}
