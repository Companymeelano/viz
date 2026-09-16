<?php
/* ═══════════════════════════════════════════════════════════════════════════
   Vizitor — آتیران ویزیتور | لایهٔ داده وب‌سرویس (lib/repo.php)
   Developed by Milano Technical Team, Milad Yaghoobi
   ─────────────────────────────────────────────────────────────────────────
   همهٔ کوئری‌های خواندن از سه نمای قراردادی انجام می‌شود:
       vwVizitorProducts ، vwVizitorCustomers ، vwVizitorSalMali
   نوشتن (فاکتور و درخواست مشتری) در جداول Vizitor* انجام می‌شود.

   ⚠️ نکتهٔ کلیدی: درایور sqlsrv اعداد و bit را «رشته» برمی‌گرداند؛ برای اینکه
   اپ اندروید (Gson) آن‌ها را درست بخواند، اینجا نوع‌ها صریح تبدیل می‌شوند:
   عدد صحیح → int ، اعشاری → float ، bit → bool true/false.
   ═══════════════════════════════════════════════════════════════════════════ */

declare(strict_types=1);

/* ─────────────────────────── کمکی‌های تبدیل نوع ────────────────────────── */

function v_int($value): int
{
    return (int) $value;
}

function v_float($value): float
{
    return (float) $value;
}

/** bit در sqlsrv به‌صورت «1»/«0» یا true/false برمی‌گردد */
function v_bool($value): bool
{
    if (is_bool($value)) {
        return $value;
    }
    return in_array((string) $value, ['1', 'true', 'True', 'TRUE'], true);
}

/* ─────────────────────────────── کالاها ────────────────────────────────── */

/**
 * فهرست کالاها (کاتالوگ).
 * @param int $sinceMs فقط رکوردهای جدیدتر از این زمان (میلی‌ثانیه). صفر = همه
 */
function vizitor_products(PDO $pdo, int $sinceMs = 0): array
{
    $sql = 'SELECT Id, Code, Name, group_name, price, stock, is_vip, unit, pack_size,
                   price2, consumer_price, updated_at_ms
              FROM dbo.vwVizitorProducts';
    $params = [];
    if ($sinceMs > 0) {
        $sql .= ' WHERE updated_at_ms > ?';
        $params[] = $sinceMs;
    }
    $sql .= ' ORDER BY Name COLLATE Persian_100_CI_AI ASC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $out = [];
    foreach ($stmt->fetchAll() as $row) {
        $out[] = [
            'id'             => v_int($row['Id']),
            'code'           => (string) $row['Code'],
            'name'           => (string) $row['Name'],
            'group_name'     => (string) $row['group_name'],
            'price'          => v_int($row['price']),
            'stock'          => v_float($row['stock']),
            'is_vip'         => v_bool($row['is_vip']),
            'unit'           => (string) $row['unit'],
            'pack_size'      => v_int($row['pack_size']),
            'price2'         => v_int($row['price2']),
            'consumer_price' => v_int($row['consumer_price']),
        ];
    }
    return $out;
}

/* ─────────────────────────────── مشتریان ───────────────────────────────── */

function vizitor_customers(PDO $pdo, int $sinceMs = 0): array
{
    $sql = 'SELECT Id, Code, Name, group_name, city, address, phone, lat, lng,
                   credit_ok, is_vip, last_purchase_days, drop_percent, debt, updated_at_ms
              FROM dbo.vwVizitorCustomers';
    $params = [];
    if ($sinceMs > 0) {
        $sql .= ' WHERE updated_at_ms > ?';
        $params[] = $sinceMs;
    }
    $sql .= ' ORDER BY Name COLLATE Persian_100_CI_AI ASC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $out = [];
    foreach ($stmt->fetchAll() as $row) {
        $out[] = [
            'id'                 => v_int($row['Id']),
            'code'               => (string) $row['Code'],
            'name'               => (string) $row['Name'],
            'group_name'         => (string) $row['group_name'],
            'city'               => (string) $row['city'],
            'address'            => (string) $row['address'],
            'phone'              => (string) $row['phone'],
            'lat'                => v_float($row['lat']),
            'lng'                => v_float($row['lng']),
            'credit_ok'          => v_bool($row['credit_ok']),
            'is_vip'             => v_bool($row['is_vip']),
            'last_purchase_days' => v_int($row['last_purchase_days']),
            'drop_percent'       => v_int($row['drop_percent']),
            'debt'               => v_int($row['debt']),
        ];
    }
    return $out;
}

/* ───────────────────── تاریخچه فروش سال مالی (sal_mali) ────────────────── */

function vizitor_salmali(PDO $pdo, int $customerId): array
{
    $stmt = $pdo->prepare(
        'SELECT customer_id, product_name, total_qty, year_month
           FROM dbo.vwVizitorSalMali
          WHERE customer_id = ?
          ORDER BY total_qty DESC'
    );
    $stmt->execute([$customerId]);

    $out = [];
    foreach ($stmt->fetchAll() as $row) {
        $out[] = [
            'customer_id'  => v_int($row['customer_id']),
            'product_name' => (string) $row['product_name'],
            'total_qty'    => v_float($row['total_qty']),
            'year_month'   => (string) $row['year_month'],
        ];
    }
    return $out;
}

/* ──────────────────────────── شماره‌دهی اسناد ──────────────────────────── */

/** شمارهٔ بعدی یک دنباله (اتمیک با قفل سطر) */
function vizitor_next_sequence(PDO $pdo, string $name): int
{
    $stmt = $pdo->prepare(
        'UPDATE dbo.VizitorSequences
            SET NextNo = NextNo + 1
          OUTPUT INSERTED.NextNo
          WHERE Name = ?'
    );
    $stmt->execute([$name]);
    $row = $stmt->fetch();
    if ($row && isset($row['NextNo'])) {
        return (int) $row['NextNo'];
    }
    // اگر دنباله وجود نداشت، بساز
    $pdo->prepare('INSERT INTO dbo.VizitorSequences (Name, NextNo) VALUES (?, 2)')->execute([$name]);
    return 1;
}

/* ─────────────────────────────── فاکتورها ──────────────────────────────── */

/** فاکتور ثبت‌شده با همین شناسهٔ کلاینت (برای idempotency) */
function vizitor_find_invoice(PDO $pdo, string $clientInvoiceId): ?array
{
    $stmt = $pdo->prepare(
        'SELECT Id, InvoiceNo, FinalAmount FROM dbo.VizitorSalesHeader WHERE ClientInvoiceId = ?'
    );
    $stmt->execute([$clientInvoiceId]);
    $row = $stmt->fetch();
    return $row ?: null;
}

/**
 * نام مشتری از نمای مشتریان (اپ نام مشتری را نمی‌فرستد؛ شناسه می‌فرستد).
 * در نبود رکورد، رشتهٔ خالی برمی‌گردد تا نام پیش‌فرض استفاده شود.
 */
function vizitor_customer_name(PDO $pdo, int $customerId): string
{
    if ($customerId <= 0) {
        return '';
    }
    try {
        $stmt = $pdo->prepare('SELECT Name FROM dbo.vwVizitorCustomers WHERE Id = ?');
        $stmt->execute([$customerId]);
        $row = $stmt->fetch();
        return $row ? trim((string) $row['Name']) : '';
    } catch (Throwable $e) {
        return '';
    }
}

/**
 * ثبت فاکتور به‌صورت اتمیک.
 * @param array $payload بدنهٔ JSON ارسال‌شده از اپ
 * @param array $user    کاربر احراز‌شده
 * @return array{invoice_no:string,idempotent:bool}
 */
function vizitor_insert_invoice(PDO $pdo, array $config, array $payload, array $user, string $deviceId): array
{
    $clientInvoiceId = vizitor_str($payload, 'client_invoice_id');
    if ($clientInvoiceId === '' || strlen($clientInvoiceId) > 64) {
        vizitor_fail('شناسهٔ کلاینت فاکتور نامعتبر است (client_invoice_id).', 400);
    }

    // idempotency: اگر همین فاکتور قبلاً ثبت شده، همان شماره برگردانده می‌شود
    $existing = vizitor_find_invoice($pdo, $clientInvoiceId);
    if ($existing !== null) {
        return ['invoice_no' => (string) $existing['InvoiceNo'], 'idempotent' => true];
    }

    $items = $payload['items'] ?? null;
    if (!is_array($items) || count($items) === 0) {
        vizitor_fail('فاکتور هیچ قلمی ندارد.', 400);
    }

    $gross    = vizitor_int($payload, 'gross_amount');
    $discount = vizitor_int($payload, 'discount');
    $final    = vizitor_int($payload, 'final_amount');
    $sumLines = 0;
    $lines    = [];

    foreach ($items as $item) {
        if (!is_array($item)) {
            vizitor_fail('ساختار اقلام فاکتور نامعتبر است.', 400);
        }
        $qty   = (float) ($item['quantity'] ?? 0);
        $price = (int) ($item['unit_price'] ?? 0);
        $total = (int) ($item['line_total'] ?? 0);
        if ($qty <= 0) {
            vizitor_fail('تعداد یکی از اقلام فاکتور نامعتبر است.', 400);
        }
        $sumLines += $total;
        $lines[] = [
            'product_id'   => (int) ($item['product_id'] ?? 0),
            'product_name' => (string) ($item['product_name'] ?? ''),
            'quantity'     => $qty,
            'unit_price'   => $price,
            'line_total'   => $total,
        ];
    }

    // راستی‌آزمایی جمع‌ها — تور امنیتی در برابر نسخه‌های قدیمی/دست‌کاری‌شدهٔ اپ
    if (!empty($config['strict_totals'])) {
        if (abs($sumLines - $gross) > 1) {
            vizitor_fail(
                sprintf('جمع اقلام (%d ریال) با مبلغ ناخالص فاکتور (%d ریال) نمی‌خواند.', $sumLines, $gross),
                400
            );
        }
        if ($gross - $discount !== $final) {
            vizitor_fail('مبلغ نهایی با «ناخالص منهای تخفیف» نمی‌خواند.', 400);
        }
    }

    $invoiceNo = 'VZ-' . vizitor_jalali_year() . '-'
        . str_pad((string) vizitor_next_sequence($pdo, 'INVOICE'), 6, '0', STR_PAD_LEFT);

    // نام مشتری: اگر اپ نفرستاده باشد، از نمای مشتریان خوانده می‌شود
    $customerId   = vizitor_int($payload, 'customer_id');
    $customerName = vizitor_str($payload, 'customer_name');
    if ($customerName === '') {
        $customerName = vizitor_customer_name($pdo, $customerId);
    }
    if ($customerName === '') {
        $customerName = 'مشتری متفرقه';
    }

    $started = !$pdo->inTransaction();
    if ($started) {
        $pdo->beginTransaction();
    }

    try {
        $stmt = $pdo->prepare(
            'INSERT INTO dbo.VizitorSalesHeader
                (ClientInvoiceId, InvoiceNo, CustomerId, CustomerName, GrossAmount, Discount,
                 FinalAmount, SignatureBase64, Note, VisitorUserId, DeviceId, CreatedAtMs)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $stmt->execute([
            $clientInvoiceId,
            $invoiceNo,
            $customerId,
            $customerName,
            $gross,
            $discount,
            $final,
            isset($payload['signature']) && $payload['signature'] !== null
                ? (string) $payload['signature'] : null,
            vizitor_str($payload, 'note'),
            (int) $user['id'],
            substr($deviceId, 0, 128),
            (int) ($payload['created_at_ms'] ?? 0),
        ]);

        $headerId = (int) ($pdo->query('SELECT SCOPE_IDENTITY() AS id')->fetch()['id'] ?? 0);
        if ($headerId <= 0) {
            throw new RuntimeException('شناسهٔ فاکتور ثبت‌شده به دست نیامد.');
        }

        $ins = $pdo->prepare(
            'INSERT INTO dbo.VizitorSalesLines (HeaderId, ProductId, ProductName, Quantity, UnitPrice, LineTotal)
             VALUES (?, ?, ?, ?, ?, ?)'
        );
        foreach ($lines as $line) {
            $ins->execute([
                $headerId,
                $line['product_id'],
                $line['product_name'],
                $line['quantity'],
                $line['unit_price'],
                $line['line_total'],
            ]);
        }

        // کسر موجودی (اختیاری — پیش‌فرض خاموش است)
        if (!empty($config['decrement_stock'])) {
            $upd = $pdo->prepare('UPDATE dbo.VizitorProducts SET Stock = Stock - ? WHERE Id = ?');
            foreach ($lines as $line) {
                $upd->execute([$line['quantity'], $line['product_id']]);
            }
        }

        if ($started) {
            $pdo->commit();
        }
    } catch (Throwable $e) {
        if ($started && $pdo->inTransaction()) {
            $pdo->rollBack();
        }
        // اگر هم‌زمان درخواست تکراری رسیده باشد، بازگشت همان شماره درست است
        $again = vizitor_find_invoice($pdo, $clientInvoiceId);
        if ($again !== null) {
            return ['invoice_no' => (string) $again['InvoiceNo'], 'idempotent' => true];
        }
        throw $e;
    }

    // قلاب اختیاری: درج در جداول حسابداری واقعی (پیش‌فرض غیرفعال)
    if (!empty($config['write_to_erp'])) {
        vizitor_push_invoice_to_erp($pdo, $invoiceNo, $lines);
    }

    return ['invoice_no' => $invoiceNo, 'idempotent' => false];
}

/**
 * قلاب درج فاکتور در جداول واقعی نرم‌افزار آتیران.
 * ⚠️ نام جداول/ستون‌های حسابداری باید توسط شما اینجا تکمیل شود
 *    (نمونهٔ ساختار در 03_erp_views_template.sql آمده است).
 *    تا زمانی که این تابع کامل نشود، فاکتورها در VizitorSalesHeader
 *    می‌مانند تا حسابداری آن‌ها را ببیند و ثبت نهایی را انجام دهد.
 */
function vizitor_push_invoice_to_erp(PDO $pdo, string $invoiceNo, array $lines): void
{
    // نمونهٔ پیاده‌سازی (پس از تطبیق نام جداول فعال کنید):
    //
    // $stmt = $pdo->prepare('INSERT INTO dbo.SalesHeader (InvoiceNo, CustomerID, SumPrice, VisitorID, Tarikh)
    //                        VALUES (?, ?, ?, ?, ?)');
    // $stmt->execute([$invoiceNo, $header['CustomerId'], $header['FinalAmount'], $header['VisitorUserId'], date('Ymd')]);
    //
    // برای هر سطر هم مشابه همین کار را در SalesLines انجام دهید.
    throw new RuntimeException('write_to_erp فعال است ولی تابع vizitor_push_invoice_to_erp هنوز پیاده‌سازی نشده است.');
}

/* ───────────────────── درخواست مشتری جدید (در انتظار تأیید) ─────────────── */

/**
 * ثبت درخواست مشتری جدید.
 * idempotency: مشابه «نام + تلفن + شهر» که کمتر از ۳۰ روز پیش ثبت شده باشد،
 * همان درخواست قبلی برگردانده می‌شود (اپ ممکن است دوباره تلاش کند).
 * @return array{request_id:string,idempotent:bool}
 */
function vizitor_insert_customer_request(PDO $pdo, array $payload, array $user, string $deviceId): array
{
    $name  = vizitor_str($payload, 'name');
    $phone = vizitor_str($payload, 'phone');
    $city  = vizitor_str($payload, 'city');

    if (mb_strlen($name) < 3) {
        vizitor_fail('نام مشتری باید حداقل ۳ نویسه باشد.', 400);
    }

    $dedupeKey = hash('sha256', mb_strtolower($name . '|' . $phone . '|' . $city, 'UTF-8'));

    $stmt = $pdo->prepare(
        'SELECT RequestNo FROM dbo.VizitorCustomerRequests
          WHERE DedupeKey = ? AND Status = N\'PENDING\'
            AND CreatedAt > DATEADD(DAY, -30, SYSUTCDATETIME())
          ORDER BY Id DESC'
    );
    $stmt->execute([$dedupeKey]);
    $row = $stmt->fetch();
    if ($row) {
        return ['request_id' => (string) $row['RequestNo'], 'idempotent' => true];
    }

    $requestNo = 'CR-' . vizitor_jalali_year() . '-'
        . str_pad((string) vizitor_next_sequence($pdo, 'CUSTOMER_REQ'), 6, '0', STR_PAD_LEFT);

    $stmt = $pdo->prepare(
        'INSERT INTO dbo.VizitorCustomerRequests
            (RequestNo, Name, GroupName, City, Address, Phone, VisitorNote, VisitorUserId, DeviceId, DedupeKey)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $requestNo,
        $name,
        vizitor_str($payload, 'group_name', 'مشتری متفرقه'),
        $city,
        vizitor_str($payload, 'address'),
        $phone,
        vizitor_str($payload, 'visitor_note'),
        (int) $user['id'],
        substr($deviceId, 0, 128),
        $dedupeKey,
    ]);

    return ['request_id' => $requestNo, 'idempotent' => false];
}

/* ─────────────────────────── اطلاعات سلامت سرور ───────────────────────── */

/** نسخهٔ SQL Server به‌صورت کوتاه */
function vizitor_sql_version(PDO $pdo): string
{
    try {
        $row = $pdo->query(
            "SELECT CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(64)) AS v,
                    CAST(SERVERPROPERTY('ProductLevel')   AS NVARCHAR(64)) AS lvl,
                    CAST(SERVERPROPERTY('Edition')        AS NVARCHAR(128)) AS ed"
        )->fetch();
        return trim(($row['v'] ?? '?') . ' ' . ($row['lvl'] ?? '') . ' — ' . ($row['ed'] ?? ''));
    } catch (Throwable $e) {
        return 'نامشخص';
    }
}

/** نام دیتابیس جاری */
function vizitor_db_name(PDO $pdo): string
{
    try {
        return (string) ($pdo->query('SELECT DB_NAME() AS n')->fetch()['n'] ?? '');
    } catch (Throwable $e) {
        return '';
    }
}

/**
 * شمارش رکورد جداول کلیدی برای کارت سلامت اپ.
 * مقدار null یعنی آن جدول/نما وجود ندارد.
 * @return array<string,int|null>
 */
function vizitor_table_counts(PDO $pdo): array
{
    $targets = [
        'products'          => 'dbo.VizitorProducts',
        'customers'         => 'dbo.VizitorCustomers',
        'invoices'          => 'dbo.VizitorSalesHeader',
        'invoice_lines'     => 'dbo.VizitorSalesLines',
        'sal_mali'          => 'dbo.VizitorSalMali',
        'users'             => 'dbo.VizitorUsers',
        'pending_customers' => 'dbo.VizitorCustomerRequests',
    ];

    $out = [];
    foreach ($targets as $label => $object) {
        try {
            $exists = $pdo->prepare('SELECT CASE WHEN OBJECT_ID(?, N\'U\') IS NULL THEN 0 ELSE 1 END AS e');
            $exists->execute([$object]);
            if ((int) ($exists->fetch()['e'] ?? 0) !== 1) {
                $out[$label] = null;
                continue;
            }
            $count = $pdo->query('SELECT COUNT(*) AS c FROM ' . $object)->fetch();
            $out[$label] = (int) ($count['c'] ?? 0);
        } catch (Throwable $e) {
            $out[$label] = null;
        }
    }
    return $out;
}
