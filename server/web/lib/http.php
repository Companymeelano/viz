<?php
/* ═══════════════════════════════════════════════════════════════════════════
   Vizitor — آتیران ویزیتور | کمکی‌های HTTP و پاسخ استاندارد (lib/http.php)
   Developed by Milano Technical Team, Milad Yaghoobi
   ─────────────────────────────────────────────────────────────────────────
   قالب پاسخ دقیقاً همان چیزی است که اپ انتظار دارد:
       { "success": true, "message": "…", "data": { … } }
   ═══════════════════════════════════════════════════════════════════════════ */

declare(strict_types=1);

/** شروع اندازه‌گیری زمان پاسخ (برای لاگ) */
function vizitor_start_timer(): float
{
    return microtime(true);
}

/** بدنهٔ JSON درخواست را می‌خواند (بدون شکست در بدنهٔ خالی) */
function vizitor_input(): array
{
    static $cached = null;
    if (is_array($cached)) {
        return $cached;
    }
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        $cached = [];
        return $cached;
    }
    $decoded = json_decode($raw, true);
    $cached = is_array($decoded) ? $decoded : [];
    return $cached;
}

/** یک مقدار صحیح از ورودی (JSON یا QueryString) با مقدار پیش‌فرض */
function vizitor_int(array $source, string $key, int $default = 0): int
{
    if (!isset($source[$key]) || $source[$key] === '' || $source[$key] === null) {
        return $default;
    }
    return (int) $source[$key];
}

/** یک مقدار رشته‌ای از ورودی با پاک‌سازی فاصله‌ها */
function vizitor_str(array $source, string $key, string $default = ''): string
{
    if (!isset($source[$key]) || !is_scalar($source[$key])) {
        return $default;
    }
    return trim((string) $source[$key]);
}

/**
 * پاسخ استاندارد JSON و پایان اسکریپت.
 * @param bool        $success وضعیت
 * @param string      $message پیام فارسی برای نمایش در اپ
 * @param mixed       $data    داده (آرایه/آبجکت/تهی)
 * @param int         $code    کد HTTP
 */
function vizitor_respond(bool $success, string $message = '', $data = null, int $code = 200): void
{
    if (!headers_sent()) {
        http_response_code($code);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        header('X-Api-Version: ' . VIZITOR_API_VERSION);
    }

    $payload = [
        'success' => $success,
        'message' => $message,
    ];
    if ($data !== null) {
        $payload['data'] = $data;
    }

    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/** پاسخ موفق */
function vizitor_ok($data = null, string $message = ''): void
{
    vizitor_respond(true, $message, $data, 200);
}

/** پاسخ خطا (message در اپ به کاربر نشان داده می‌شود) */
function vizitor_fail(string $message, int $code = 400): void
{
    vizitor_respond(false, $message, null, $code);
}

/** IP درخواست‌کننده (با در نظر گرفتن پروکسی) */
function vizitor_client_ip(): string
{
    foreach (['HTTP_X_FORWARDED_FOR', 'HTTP_X_REAL_IP', 'REMOTE_ADDR'] as $key) {
        if (!empty($_SERVER[$key])) {
            $parts = explode(',', (string) $_SERVER[$key]);
            return substr(trim($parts[0]), 0, 64);
        }
    }
    return '';
}

/** هدر درخواست (سازگار با FastCGI IIS) */
function vizitor_header(string $name): string
{
    $key = 'HTTP_' . strtoupper(str_replace('-', '_', $name));
    if (!empty($_SERVER[$key])) {
        return trim((string) $_SERVER[$key]);
    }
    // برخی تنظیمات IIS هدر Authorization را فقط از این مسیر می‌دهند
    if (strcasecmp($name, 'Authorization') === 0 && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        foreach ($headers as $k => $v) {
            if (strcasecmp($k, $name) === 0) {
                return trim((string) $v);
            }
        }
    }
    return '';
}

/** ثبت درخواست در جدول لاگ (به‌صورت بی‌صدا — خطا آن را متوقف نمی‌کند) */
function vizitor_log_request(PDO $pdo, array $config, string $action, bool $success, int $tookMs, string $message, ?int $userId): void
{
    if (empty($config['log_requests'])) {
        return;
    }
    try {
        $stmt = $pdo->prepare(
            'INSERT INTO dbo.VizitorApiLog (Action, UserId, IpAddress, Success, TookMs, Message)
             VALUES (?, ?, ?, ?, ?, ?)'
        );
        $stmt->execute([
            substr($action, 0, 32),
            $userId,
            vizitor_client_ip(),
            $success ? 1 : 0,
            $tookMs,
            substr($message, 0, 500),
        ]);
    } catch (Throwable $e) {
        // لاگ نباید هرگز پاسخ API را خراب کند
    }
}

/**
 * تبدیل تاریخ میلادی به شمسی (الگوریتم جلالی) — برای شماره‌دهی اسناد.
 * @return array{0:int,1:int,2:int} [سال, ماه, روز]
 */
function vizitor_jalali(int $timestamp): array
{
    $gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    $gy  = (int) gmdate('Y', $timestamp);
    $gm  = (int) gmdate('n', $timestamp);
    $gd  = (int) gmdate('j', $timestamp);

    $gy2  = $gm > 2 ? $gy + 1 : $gy;
    $days = 355666 + (365 * $gy) + intdiv($gy2 + 3, 4) - intdiv($gy2 + 99, 100)
        + intdiv($gy2 + 399, 400) + $gd + $gdm[$gm - 1];

    $jy   = -1595 + (33 * intdiv($days, 12053));
    $days %= 12053;
    $jy   += 4 * intdiv($days, 1461);
    $days %= 1461;
    if ($days > 365) {
        $jy   += intdiv($days - 1, 365);
        $days = ($days - 1) % 365;
    }
    if ($days < 186) {
        $jm = 1 + intdiv($days, 31);
        $jd = 1 + ($days % 31);
    } else {
        $jm = 7 + intdiv($days - 186, 30);
        $jd = 1 + (($days - 186) % 30);
    }
    return [$jy, $jm, $jd];
}

/** سال مالی شمسی جاری (برای شماره‌دهی فاکتور) */
function vizitor_jalali_year(): int
{
    return vizitor_jalali(time())[0];
}
