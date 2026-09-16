/* ═══════════════════════════════════════════════════════════════════════════
   Vizitor — آتیران ویزیتور | ساختار دیتابیس سرور (01_schema.sql)
   Developed by Milano Technical Team, Milad Yaghoobi
   ─────────────────────────────────────────────────────────────────────────
   اجرا:   sqlcmd -S . -E -d AtiranVizitor -f 65001 -i 01_schema.sql
   نکته:   اسکریپت idempotent است (چند بار اجرا شود مشکلی ندارد).
   جداول با پیشوند Vizitor ساخته می‌شوند تا با جداول نرم‌افزار حسابداری
   آتیران (atiran2) تعارض نداشته باشند.

   سه نمای (view) زیر قرارداد خواندن داده وب‌سرویس هستند و در حالت اتصال به
   نرم‌افزار حسابداری واقعی، فقط همین سه نما بازتعریف می‌شوند:
       vwVizitorProducts   → کالاها
       vwVizitorCustomers  → مشتریان
       vwVizitorSalMali    → تاریخچه فروش سال مالی
   ═══════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ─────────────────────────── کاربران و نشست‌ها ─────────────────────────── */

IF OBJECT_ID(N'dbo.VizitorUsers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorUsers (
        Id            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VizitorUsers PRIMARY KEY,
        Username      NVARCHAR(64)  NOT NULL,
        PasswordHash  NVARCHAR(255) NOT NULL,          -- password_hash() تولیدشده با PHP
        VisitorCode   NVARCHAR(32)  NOT NULL DEFAULT N'',
        DisplayName   NVARCHAR(128) NOT NULL DEFAULT N'',
        Role          NVARCHAR(32)  NOT NULL DEFAULT N'visitor',  -- visitor | manager | accountant
        Phone         NVARCHAR(32)  NOT NULL DEFAULT N'',
        IsActive      BIT           NOT NULL DEFAULT 1,
        CreatedAt     DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
        LastLoginAt   DATETIME2(0)  NULL,
        CONSTRAINT UQ_VizitorUsers_Username UNIQUE (Username)
    );
END
GO

IF OBJECT_ID(N'dbo.VizitorTokens', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorTokens (
        Id          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VizitorTokens PRIMARY KEY,
        UserId      INT           NOT NULL,
        TokenHash   CHAR(64)      NOT NULL,            -- SHA-256 توکن؛ خودِ توکن ذخیره نمی‌شود
        DeviceId    NVARCHAR(128) NOT NULL DEFAULT N'',
        IssuedAt    DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
        ExpiresAt   DATETIME2(0)  NOT NULL,            -- همیشه UTC
        LastUsedAt  DATETIME2(0)  NULL,
        Revoked     BIT           NOT NULL DEFAULT 0,
        CONSTRAINT UQ_VizitorTokens_Hash UNIQUE (TokenHash),
        CONSTRAINT FK_VizitorTokens_User FOREIGN KEY (UserId) REFERENCES dbo.VizitorUsers(Id)
    );
    CREATE INDEX IX_VizitorTokens_User ON dbo.VizitorTokens(UserId);
END
GO

/* تلاش‌های ورود — برای محدودسازی حملهٔ حدس رمز */
IF OBJECT_ID(N'dbo.VizitorLoginAttempts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorLoginAttempts (
        Id          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VizitorLoginAttempts PRIMARY KEY,
        Username    NVARCHAR(64) NOT NULL,
        IpAddress   NVARCHAR(64) NOT NULL DEFAULT N'',
        Success     BIT          NOT NULL,
        AttemptedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_VizitorLoginAttempts_Lookup
        ON dbo.VizitorLoginAttempts(Username, IpAddress, AttemptedAt DESC);
END
GO

/* ─────────────────────────── داده پایه (آینه اپ) ──────────────────────── */

IF OBJECT_ID(N'dbo.VizitorProducts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorProducts (
        Id            INT           NOT NULL CONSTRAINT PK_VizitorProducts PRIMARY KEY,
        Code          NVARCHAR(64)  NOT NULL,          -- کد کالا / بارکد
        Name          NVARCHAR(200) NOT NULL,
        GroupName     NVARCHAR(100) NOT NULL DEFAULT N'',
        Price         BIGINT        NOT NULL DEFAULT 0,   -- قیمت فروش ۱ (ریال)
        Stock         FLOAT         NOT NULL DEFAULT 0,   -- موجودی زنده
        IsVip         BIT           NOT NULL DEFAULT 0,
        Unit          NVARCHAR(32)  NOT NULL DEFAULT N'کیلو',
        PackSize      INT           NOT NULL DEFAULT 1,
        Price2        BIGINT        NOT NULL DEFAULT 0,   -- قیمت فروش ۲ (۰ = مثل فروش ۱)
        ConsumerPrice BIGINT        NOT NULL DEFAULT 0,   -- قیمت مصرف‌کننده
        UpdatedAtMs   BIGINT        NOT NULL
            CONSTRAINT DF_VizitorProducts_UpdatedAtMs DEFAULT (DATEDIFF_BIG(MILLISECOND, '1970-01-01', SYSUTCDATETIME()))
    );
    CREATE INDEX IX_VizitorProducts_UpdatedAt ON dbo.VizitorProducts(UpdatedAtMs);
    CREATE INDEX IX_VizitorProducts_Code ON dbo.VizitorProducts(Code);
END
GO

IF OBJECT_ID(N'dbo.VizitorCustomers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorCustomers (
        Id               INT           NOT NULL CONSTRAINT PK_VizitorCustomers PRIMARY KEY,
        Code             NVARCHAR(32)  NOT NULL DEFAULT N'',
        Name             NVARCHAR(200) NOT NULL,
        GroupName        NVARCHAR(100) NOT NULL DEFAULT N'',
        City             NVARCHAR(64)  NOT NULL DEFAULT N'',
        Address          NVARCHAR(300) NOT NULL DEFAULT N'',
        Phone            NVARCHAR(32)  NOT NULL DEFAULT N'',
        Lat              FLOAT         NOT NULL DEFAULT 0,
        Lng              FLOAT         NOT NULL DEFAULT 0,
        CreditOk         BIT           NOT NULL DEFAULT 1,
        IsVip            BIT           NOT NULL DEFAULT 0,
        LastPurchaseDays INT           NOT NULL DEFAULT 0,
        DropPercent      INT           NOT NULL DEFAULT 0,
        Debt             BIGINT        NOT NULL DEFAULT 0,
        UpdatedAtMs      BIGINT        NOT NULL
            CONSTRAINT DF_VizitorCustomers_UpdatedAtMs DEFAULT (DATEDIFF_BIG(MILLISECOND, '1970-01-01', SYSUTCDATETIME()))
    );
    CREATE INDEX IX_VizitorCustomers_UpdatedAt ON dbo.VizitorCustomers(UpdatedAtMs);
END
GO

IF OBJECT_ID(N'dbo.VizitorSalMali', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorSalMali (
        Id          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VizitorSalMali PRIMARY KEY,
        CustomerId  INT           NOT NULL,
        ProductName NVARCHAR(200) NOT NULL,
        TotalQty    FLOAT         NOT NULL DEFAULT 0,
        YearMonth   NVARCHAR(16)  NOT NULL DEFAULT N'',   -- مثال: 1404-05
        UpdatedAtMs BIGINT        NOT NULL
            CONSTRAINT DF_VizitorSalMali_UpdatedAtMs DEFAULT (DATEDIFF_BIG(MILLISECOND, '1970-01-01', SYSUTCDATETIME()))
    );
    CREATE INDEX IX_VizitorSalMali_Customer ON dbo.VizitorSalMali(CustomerId, TotalQty DESC);
END
GO

/* ─────────────────────────── فاکتورهای فروش ───────────────────────────── */

IF OBJECT_ID(N'dbo.VizitorSalesHeader', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorSalesHeader (
        Id              BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VizitorSalesHeader PRIMARY KEY,
        ClientInvoiceId VARCHAR(64)   NOT NULL,        -- UUID تولیدشده در اپ → کلید idempotency
        InvoiceNo       NVARCHAR(32)  NOT NULL,
        CustomerId      INT           NOT NULL DEFAULT 0,
        CustomerName    NVARCHAR(200) NOT NULL DEFAULT N'مشتری متفرقه',
        GrossAmount     BIGINT        NOT NULL DEFAULT 0,
        Discount        BIGINT        NOT NULL DEFAULT 0,
        FinalAmount     BIGINT        NOT NULL DEFAULT 0,
        SignatureBase64 NVARCHAR(MAX) NULL,            -- امضای دیجیتال مشتری (PNG/Base64)
        Note            NVARCHAR(500) NOT NULL DEFAULT N'',
        VisitorUserId   INT           NULL,
        DeviceId        NVARCHAR(128) NOT NULL DEFAULT N'',
        Status          NVARCHAR(20)  NOT NULL DEFAULT N'POSTED',   -- POSTED | CANCELED
        CreatedAtMs     BIGINT        NOT NULL DEFAULT 0,            -- زمان ساخت در اپ
        ServerReceivedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_VizitorSalesHeader_ClientId UNIQUE (ClientInvoiceId)
    );
    CREATE INDEX IX_VizitorSalesHeader_Customer ON dbo.VizitorSalesHeader(CustomerId);
    CREATE INDEX IX_VizitorSalesHeader_Received ON dbo.VizitorSalesHeader(ServerReceivedAt DESC);
END
GO

IF OBJECT_ID(N'dbo.VizitorSalesLines', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorSalesLines (
        Id          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VizitorSalesLines PRIMARY KEY,
        HeaderId    BIGINT        NOT NULL,
        ProductId   INT           NOT NULL DEFAULT 0,
        ProductName NVARCHAR(200) NOT NULL DEFAULT N'',
        Quantity    FLOAT         NOT NULL DEFAULT 0,
        UnitPrice   BIGINT        NOT NULL DEFAULT 0,
        LineTotal   BIGINT        NOT NULL DEFAULT 0,
        CONSTRAINT FK_VizitorSalesLines_Header FOREIGN KEY (HeaderId)
            REFERENCES dbo.VizitorSalesHeader(Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_VizitorSalesLines_Header ON dbo.VizitorSalesLines(HeaderId);
END
GO

/* ─────────────── درخواست مشتری جدید (در انتظار تأیید حسابداری) ─────────── */

IF OBJECT_ID(N'dbo.VizitorCustomerRequests', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorCustomerRequests (
        Id             BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VizitorCustomerRequests PRIMARY KEY,
        RequestNo      NVARCHAR(32)  NOT NULL,
        Name           NVARCHAR(200) NOT NULL,
        GroupName      NVARCHAR(100) NOT NULL DEFAULT N'',
        City           NVARCHAR(64)  NOT NULL DEFAULT N'',
        Address        NVARCHAR(300) NOT NULL DEFAULT N'',
        Phone          NVARCHAR(32)  NOT NULL DEFAULT N'',
        VisitorNote    NVARCHAR(500) NOT NULL DEFAULT N'',
        VisitorUserId  INT           NULL,
        DeviceId       NVARCHAR(128) NOT NULL DEFAULT N'',
        Status         NVARCHAR(20)  NOT NULL DEFAULT N'PENDING',  -- PENDING | APPROVED | REJECTED
        DedupeKey      CHAR(64)      NOT NULL DEFAULT '',          -- جلوگیری از ارسال تکراری
        ApprovedCustomerId INT       NULL,                          -- شناسهٔ مشتری پس از تأیید در حسابداری
        CreatedAt      DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
        ReviewedAt     DATETIME2(0)  NULL,
        ReviewedBy     NVARCHAR(64)  NOT NULL DEFAULT N''
    );
    CREATE INDEX IX_VizitorCustomerRequests_Status ON dbo.VizitorCustomerRequests(Status, CreatedAt DESC);
    CREATE INDEX IX_VizitorCustomerRequests_Dedupe ON dbo.VizitorCustomerRequests(DedupeKey);
END
GO

/* ─────────────────────────── شماره‌دهی و لاگ ──────────────────────────── */

IF OBJECT_ID(N'dbo.VizitorSequences', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorSequences (
        Name   NVARCHAR(32) NOT NULL CONSTRAINT PK_VizitorSequences PRIMARY KEY,
        NextNo INT          NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID(N'dbo.VizitorApiLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VizitorApiLog (
        Id         BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VizitorApiLog PRIMARY KEY,
        Action     NVARCHAR(32)  NOT NULL DEFAULT N'',
        UserId     INT           NULL,
        IpAddress  NVARCHAR(64)  NOT NULL DEFAULT N'',
        Success    BIT           NOT NULL DEFAULT 1,
        TookMs     INT           NOT NULL DEFAULT 0,
        Message    NVARCHAR(500) NOT NULL DEFAULT N'',
        CreatedAt  DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_VizitorApiLog_Created ON dbo.VizitorApiLog(CreatedAt DESC);
END
GO

/* ═══════════════════════════ نماها (قرارداد API) ═══════════════════════
   وب‌سرویس فقط از این سه نما می‌خواند. برای اتصال به جداول واقعی
   نرم‌افزار آتیران، 03_erp_views_template.sql را ببینید.
   ═══════════════════════════════════════════════════════════════════════ */

IF OBJECT_ID(N'dbo.vwVizitorProducts', N'V') IS NOT NULL DROP VIEW dbo.vwVizitorProducts;
GO
CREATE VIEW dbo.vwVizitorProducts AS
SELECT  Id,
        Code,
        Name,
        GroupName     AS group_name,
        Price         AS price,
        Stock         AS stock,
        IsVip         AS is_vip,
        Unit          AS unit,
        PackSize      AS pack_size,
        Price2        AS price2,
        ConsumerPrice AS consumer_price,
        UpdatedAtMs   AS updated_at_ms
FROM    dbo.VizitorProducts;
GO

IF OBJECT_ID(N'dbo.vwVizitorCustomers', N'V') IS NOT NULL DROP VIEW dbo.vwVizitorCustomers;
GO
CREATE VIEW dbo.vwVizitorCustomers AS
SELECT  Id,
        Code,
        Name,
        GroupName        AS group_name,
        City             AS city,
        Address          AS address,
        Phone            AS phone,
        Lat              AS lat,
        Lng              AS lng,
        CreditOk         AS credit_ok,
        IsVip            AS is_vip,
        LastPurchaseDays AS last_purchase_days,
        DropPercent      AS drop_percent,
        Debt             AS debt,
        UpdatedAtMs      AS updated_at_ms
FROM    dbo.VizitorCustomers;
GO

IF OBJECT_ID(N'dbo.vwVizitorSalMali', N'V') IS NOT NULL DROP VIEW dbo.vwVizitorSalMali;
GO
CREATE VIEW dbo.vwVizitorSalMali AS
SELECT  CustomerId  AS customer_id,
        ProductName AS product_name,
        TotalQty    AS total_qty,
        YearMonth   AS year_month
FROM    dbo.VizitorSalMali;
GO

PRINT N'✔ ساختار دیتابیس Vizitor ساخته/به‌روز شد.';
GO
