/* ═══════════════════════════════════════════════════════════════════════════
   Vizitor — آتیران ویزیتور | قالب اتصال به جداول واقعی نرم‌افزار آتیران
   Developed by Milano Technical Team, Milad Yaghoobi
   ─────────────────────────────────────────────────────────────────────────
   وب‌سرویس فقط از سه نمای زیر می‌خواند:

       vwVizitorProducts   → کالاها
       vwVizitorCustomers  → مشتریان
       vwVizitorSalMali    → تاریخچه فروش سال مالی

   ⚠️ مهم: نام جداول نرم‌افزار حسابداری آتیران در این بسته مشخص نیست، پس این
   فایل «قالب» است: نام جدول/ستون‌های واقعی خود را جایگزین کنید و سپس این
   اسکریپت را روی دیتابیس اجرا کنید تا نماها به دادهٔ واقعی وصل شوند.

   روش کار:
     ۱) فایل 01_schema.sql را اجرا کنید (جداول Vizitor ساخته می‌شوند).
     ۲) در این فایل، بخش‌های «← جایگزین کنید» را با نام واقعی جدول/ستون‌ها
        پر کنید. برای پیدا کردن نام دقیق ستون‌ها:

            SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME IN (N'کالا', N'مشتری', ...)
            ORDER BY TABLE_NAME, ORDINAL_POSITION;

     ۳) همین فایل را اجرا کنید. از این پس اپ، دادهٔ واقعی می‌گیرد و جداول
        VizitorProducts/VizitorCustomers/VizitorSalMali فقط پشتیبان می‌مانند.
     ۴) برای بازگشت به حالت مستقل، دستور DROP VIEW + اجرای دوبارهٔ انتهای
        01_schema.sql کافی است.

   نکتهٔ امنیتی: با این کار هیچ داده‌ای کپی نمی‌شود و هیچ نوشتنی روی جداول
   حسابداری انجام نمی‌گیرد؛ این نماها فقط «خواندنی» هستند.
   ═══════════════════════════════════════════════════════════════════════════ */

/* ─────────────────────────── ۱) کالاها ───────────────────────────
   خروجی باید این ستون‌ها را داشته باشد (نام‌ها ثابت و اجباری‌اند):
     Id, Code, Name, group_name, price, stock, is_vip, unit, pack_size,
     price2, consumer_price, updated_at_ms
   ───────────────────────────────────────────────────────────────────── */
IF OBJECT_ID(N'dbo.vwVizitorProducts', N'V') IS NOT NULL DROP VIEW dbo.vwVizitorProducts;
GO
CREATE VIEW dbo.vwVizitorProducts AS
SELECT
    K.KalaID                        AS Id,            -- ← جایگزین کنید (شناسهٔ کالا)
    ISNULL(K.Barcode, N'')          AS Code,          -- ← جایگزین کنید (بارکد/کد کالا)
    K.KalaName                      AS Name,          -- ← جایگزین کنید (نام کالا)
    ISNULL(G.GroupName, N'')        AS group_name,    -- ← جایگزین کنید (گروه کالا)
    ISNULL(K.Price1, 0)             AS price,         -- ← قیمت فروش ۱ (ریال)
    ISNULL(K.Mojoodi, 0)            AS stock,         -- ← موجودی زنده
    CAST(ISNULL(K.IsVip, 0) AS BIT) AS is_vip,        -- ← اگر ستون VIP ندارید: CAST(0 AS BIT)
    ISNULL(K.Unit, N'کیلو')         AS unit,          -- ← واحد شمارش
    ISNULL(K.PackSize, 1)           AS pack_size,     -- ← تعداد داخل بسته
    ISNULL(K.Price2, 0)             AS price2,        -- ← قیمت فروش ۲
    ISNULL(K.ConsumerPrice, 0)      AS consumer_price,-- ← قیمت مصرف‌کننده
    DATEDIFF_BIG(MILLISECOND, '1970-01-01',
        ISNULL(K.LastModified, SYSUTCDATETIME()))    AS updated_at_ms
FROM dbo.Kala K                                  -- ← نام جدول کالا
LEFT JOIN dbo.KalaGroup G ON G.GroupID = K.GroupID;  -- ← نام جدول گروه کالا
GO

/* ─────────────────────────── ۲) مشتریان ───────────────────────────
   خروجی: Id, Code, Name, group_name, city, address, phone, lat, lng,
          credit_ok, is_vip, last_purchase_days, drop_percent, debt, updated_at_ms
   ───────────────────────────────────────────────────────────────────── */
IF OBJECT_ID(N'dbo.vwVizitorCustomers', N'V') IS NOT NULL DROP VIEW dbo.vwVizitorCustomers;
GO
CREATE VIEW dbo.vwVizitorCustomers AS
SELECT
    M.CustomerID                     AS Id,
    ISNULL(M.Code, N'')              AS Code,
    M.Name                           AS Name,
    ISNULL(G.Name, N'')              AS group_name,     -- ← گروه مشتری (CustGroup)
    ISNULL(M.City, N'')              AS city,
    ISNULL(M.Address, N'')           AS address,
    ISNULL(M.Phone, N'')             AS phone,
    ISNULL(M.Lat, 0)                 AS lat,
    ISNULL(M.Lng, 0)                 AS lng,
    CAST(CASE WHEN ISNULL(M.Mandeh, 0) <= ISNULL(M.CreditLimit, 0) THEN 1 ELSE 0 END AS BIT) AS credit_ok,
    CAST(ISNULL(M.IsVip, 0) AS BIT)  AS is_vip,
    ISNULL(DATEDIFF(DAY, M.LastBuyDate, SYSUTCDATETIME()), 0) AS last_purchase_days,
    /* درصد افت خرید: مقایسهٔ خرید ۹۰ روز اخیر با ۹۰ روز ماقبل — در نبود داده ۰ */
    ISNULL(M.DropPercent, 0)         AS drop_percent,
    ISNULL(M.Mandeh, 0)              AS debt,
    DATEDIFF_BIG(MILLISECOND, '1970-01-01',
        ISNULL(M.LastModified, SYSUTCDATETIME())) AS updated_at_ms
FROM dbo.Moshtari M                              -- ← نام جدول مشتری
LEFT JOIN dbo.CustGroup G ON G.GroupID = M.GroupID;  -- ← نام جدول گروه مشتری
GO

/* ─────────────────────── ۳) تاریخچه سال مالی ───────────────────────
   خروجی: customer_id, product_name, total_qty, year_month (مثل 1404-05)
   این داده خوراک دستیار هوشمند فروش است (پیشنهاد کالای مکمل).
   ───────────────────────────────────────────────────────────────────── */
IF OBJECT_ID(N'dbo.vwVizitorSalMali', N'V') IS NOT NULL DROP VIEW dbo.vwVizitorSalMali;
GO
CREATE VIEW dbo.vwVizitorSalMali AS
SELECT
    F.CustomerID      AS customer_id,
    K.KalaName        AS product_name,
    SUM(F.Meghdar)    AS total_qty,
    /* سال/ماه شمسی از تاریخ فاکتور — در صورت وجود ستون سال/ماه مالی از آن استفاده کنید */
    CONVERT(NVARCHAR(16),
        RIGHT(N'000' + CAST(F.SalMali AS NVARCHAR(4)), 4) + N'-' +
        RIGHT(N'00'  + CAST(F.Mah    AS NVARCHAR(2)), 2)) AS year_month
FROM dbo.SalesLines F                            -- ← نام جدول اقلام فروش
INNER JOIN dbo.Kala K ON K.KalaID = F.KalaID
WHERE ISNULL(F.Cancelled, 0) = 0
GROUP BY F.CustomerID, K.KalaName, F.SalMali, F.Mah;
GO

PRINT N'✔ نماهای Vizitor به جداول واقعی آتیران وصل شدند.';
PRINT N'  آزمون سریع:  SELECT TOP 5 * FROM dbo.vwVizitorProducts;';
GO
