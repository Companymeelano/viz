<?php
/* ═══════════════════════════════════════════════════════════════════════════
   Vizitor — آتیران ویزیتور | وب‌سرویس اصلی (index.php)
   Developed by Milano Technical Team, Milad Yaghoobi
   ─────────────────────────────────────────────────────────────────────────
   اندپوینت‌ها (همه روی همین فایل، با پارامتر action):

     GET  index.php?action=ping                       → سلامت سرور (بدون توکن)
     POST index.php?action=login                      → ورود کاربر
     GET  index.php?action=catalog&since=<ms>         → کاتالوگ کالا
     GET  index.php?action=customers&since=<ms>       → فهرست مشتریان
     GET  index.php?action=sal_mali&customer_id=<id>  → تاریخچه سال مالی مشتری
     POST index.php?action=submit_invoice             → ثبت فاکتور (idempotent)
     POST index.php?action=submit_customer            → درخواست مشتری جدید

   همهٔ درخواست‌ها هدر X-Api-Key می‌خواهند؛ به‌جز ping، بقیه توکن
   Authorization: Bearer <token> هم لازم دارند.
   زمان‌ها: تمام مقادیر تاریخ/ساعت API بر مبنای UTC است (قالب Y-m-d H:i:s).
   ═══════════════════════════════════════════════════════════════════════════ */

declare(strict_types=1);

require __DIR__ . '/lib/http.php';
require __DIR__ . '/lib/db.php';
require __DIR__ . '/lib/auth.php';
require __DIR__ . '/lib/repo.php';

/* ─────────────────────── بارگذاری تنظیمات ─────────────────────── */
$configFile = __DIR__ . '/config.php';
if (!is_file($configFile)) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'فایل config.php یافت نشد. اسکریپت Setup-VizitorServer.ps1 را اجرا کنید یا '
            . 'config.sample.php را به config.php کپی و مقادیر آن را پر کنید.',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}
$config = require $configFile;
if (!is_array($config)) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['success' => false, 'message' => 'ساختار config.php نامعتبر است.'], JSON_UNESCAPED_UNICODE);
    exit;
}

define('VIZITOR_API_VERSION', (string) ($config['api_version'] ?? '1.0.0'));
date_default_timezone_set((string) ($config['timezone'] ?? 'Asia/Tehran')); // فقط برای لاگ‌ها

/* ─────────────────── CORS اختیاری (فقط برای تست دستی) ─────────────────── */
if (!empty($config['allow_cors_debug'])) {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Api-Key');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

/* ─────────────────────── زیرساخت لاگ درخواست ─────────────────────── */
$startedAt   = vizitor_start_timer();
$action      = strtolower(vizitor_str($_GET, 'action', 'ping'));
$pdo         = null;
$GLOBALS['vizitor_user_id'] = null;

register_shutdown_function(function () use (&$pdo, $config, $startedAt, $action) {
    if (!($pdo instanceof PDO)) {
        return;
    }
    $code = (int) http_response_code();
    $took = (int) round((microtime(true) - $startedAt) * 1000);
    vizitor_log_request(
        $pdo,
        $config,
        $action,
        $code >= 200 && $code < 300,
        $took,
        (string) ($GLOBALS['vizitor_last_message'] ?? ''),
        $GLOBALS['vizitor_user_id']
    );
});

/* ─────────────────────── اجرای درخواست ─────────────────────── */
try {
    if (!vizitor_driver_available()) {
        vizitor_respond(
            false,
            'درایور SQLSRV روی PHP نصب نیست. در فایل php.ini مقدار extension=php_sqlsrv_*_nts_x64.dll '
            . 'و php_pdo_sqlsrv_*_nts_x64.dll را فعال کنید. (درایورهای موجود: '
            . (empty(vizitor_pdo_drivers()) ? 'هیچ' : implode(', ', vizitor_pdo_drivers())) . ')',
            null,
            500
        );
    }

    $pdo = vizitor_db($config);

    // ۱) کلید مشترک اپ و سرور (روی همهٔ اندپوینت‌ها)
    vizitor_require_api_key($config);

    switch ($action) {

        /* ── سلامت سرور ───────────────────────────────────────────────── */
        case 'ping':
        case 'health':
            $data = [
                'db'           => vizitor_db_name($pdo),
                'db_host'      => $config['db']['host'] . ':' . (int) $config['db']['port'],
                'version'      => vizitor_sql_version($pdo),
                'php'          => PHP_VERSION,
                'api_version'  => VIZITOR_API_VERSION,
                'server_time'  => time(),
                'server_name'  => gethostname() ?: '',
                'tables'       => vizitor_table_counts($pdo),
            ];
            $GLOBALS['vizitor_last_message'] = 'پاسخ سلامت سرور';
            vizitor_ok($data);
            break;

        /* ── نسخه سرویس ──────────────────────────────────────────────── */
        case 'version':
            vizitor_ok([
                'api_version' => VIZITOR_API_VERSION,
                'php'         => PHP_VERSION,
                'server_time' => time(),
            ]);
            break;

        /* ── ورود کاربر ──────────────────────────────────────────────── */
        case 'login':
            $body     = vizitor_input();
            $username = vizitor_str($body, 'username');
            $password = isset($body['password']) ? (string) $body['password'] : '';
            $deviceId = vizitor_str($body, 'device_id');

            if ($username === '' || $password === '') {
                vizitor_fail('نام کاربری و رمز عبور را وارد کنید.', 400);
            }

            $maxAttempts = max(1, (int) ($config['max_login_attempts'] ?? 5));
            if (vizitor_login_failures($pdo, $config, $username) >= $maxAttempts) {
                vizitor_fail(
                    'به دلیل تلاش‌های ناموفق، ورود این حساب موقتاً بسته شده است. '
                    . (int) ($config['login_lockout_minutes'] ?? 15) . ' دقیقه بعد دوباره تلاش کنید.',
                    429
                );
            }

            $stmt = $pdo->prepare(
                'SELECT Id, Username, PasswordHash, VisitorCode, DisplayName, Role, IsActive
                   FROM dbo.VizitorUsers WHERE Username = ?'
            );
            $stmt->execute([$username]);
            $user = $stmt->fetch();

            $passwordOk = $user && password_verify($password, (string) $user['PasswordHash']);
            if (!$passwordOk || (int) $user['IsActive'] !== 1) {
                vizitor_record_login($pdo, $username, false);
                vizitor_fail('نام کاربری یا رمز عبور نادرست است، یا حساب غیرفعال است.', 401);
            }

            vizitor_record_login($pdo, $username, true);
            $pdo->prepare('UPDATE dbo.VizitorUsers SET LastLoginAt = SYSUTCDATETIME() WHERE Id = ?')
                ->execute([(int) $user['Id']]);

            $issued = vizitor_issue_token($pdo, $config, (int) $user['Id'], $deviceId);
            $GLOBALS['vizitor_user_id'] = (int) $user['Id'];

            $GLOBALS['vizitor_last_message'] = 'ورود موفق';
            vizitor_ok([
                'access_token' => $issued['token'],
                'expires_at'   => $issued['expires_at'],   // UTC — قالب Y-m-d H:i:s
                'user'         => [
                    'id'           => (int) $user['Id'],
                    'username'     => (string) $user['Username'],
                    'visitor_code' => (string) $user['VisitorCode'],
                    'display_name' => (string) $user['DisplayName'],
                    'role'         => (string) $user['Role'],
                ],
            ], 'ورود موفق');
            break;

        /* ── کاتالوگ کالا ────────────────────────────────────────────── */
        case 'catalog':
            $user = vizitor_require_user($pdo, $config);
            $GLOBALS['vizitor_user_id'] = (int) $user['id'];
            $since  = vizitor_int($_GET, 'since', 0);
            $items  = vizitor_products($pdo, $since);
            $GLOBALS['vizitor_last_message'] = count($items) . ' کالا ارسال شد';
            vizitor_ok($items);
            break;

        /* ── فهرست مشتریان ───────────────────────────────────────────── */
        case 'customers':
            $user = vizitor_require_user($pdo, $config);
            $GLOBALS['vizitor_user_id'] = (int) $user['id'];
            $since = vizitor_int($_GET, 'since', 0);
            $items = vizitor_customers($pdo, $since);
            $GLOBALS['vizitor_last_message'] = count($items) . ' مشتری ارسال شد';
            vizitor_ok($items);
            break;

        /* ── تاریخچه سال مالی یک مشتری (خوراک دستیار هوشمند) ─────────── */
        case 'sal_mali':
            $user = vizitor_require_user($pdo, $config);
            $GLOBALS['vizitor_user_id'] = (int) $user['id'];
            $customerId = vizitor_int($_GET, 'customer_id', 0);
            if ($customerId <= 0) {
                vizitor_fail('شناسهٔ مشتری ارسال نشده است.', 400);
            }
            vizitor_ok(vizitor_salmali($pdo, $customerId));
            break;

        /* ── ثبت فاکتور ──────────────────────────────────────────────── */
        case 'submit_invoice':
            $user = vizitor_require_user($pdo, $config);
            $GLOBALS['vizitor_user_id'] = (int) $user['id'];
            $body   = vizitor_input();
            $result = vizitor_insert_invoice($pdo, $config, $body, $user, vizitor_str($body, 'device_id'));
            $GLOBALS['vizitor_last_message'] = 'فاکتور ' . $result['invoice_no']
                . ($result['idempotent'] ? ' (تکراری — همان شماره قبلی)' : '');
            vizitor_ok([
                'invoice_no'  => $result['invoice_no'],
                'server_time' => time(),
                'idempotent'  => $result['idempotent'],
            ], $result['idempotent'] ? 'این فاکتور قبلاً ثبت شده بود.' : 'فاکتور با موفقیت ثبت شد.');
            break;

        /* ── درخواست مشتری جدید ──────────────────────────────────────── */
        case 'submit_customer':
            $user = vizitor_require_user($pdo, $config);
            $GLOBALS['vizitor_user_id'] = (int) $user['id'];
            $body   = vizitor_input();
            $result = vizitor_insert_customer_request($pdo, $body, $user, vizitor_str($body, 'device_id'));
            $GLOBALS['vizitor_last_message'] = 'درخواست مشتری ' . $result['request_id'];
            vizitor_ok([
                'request_id'  => $result['request_id'],
                'server_time' => time(),
                'idempotent'  => $result['idempotent'],
            ], 'درخواست ثبت مشتری برای تأیید حسابداری ارسال شد.');
            break;

        /* ── اندپوینت ناشناس ─────────────────────────────────────────── */
        default:
            vizitor_fail(
                'اکشن «' . $action . '» شناخته نشد. اکشن‌های مجاز: ping, version, login, catalog, '
                . 'customers, sal_mali, submit_invoice, submit_customer',
                400
            );
    }
} catch (PDOException $e) {
    vizitor_fail('خطای اتصال/کوئری دیتابیس: ' . $e->getMessage(), 500);
} catch (Throwable $e) {
    vizitor_fail('خطای سرور: ' . $e->getMessage(), 500);
}
