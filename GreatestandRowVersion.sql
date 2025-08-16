/* =========================================================
   Incremental ETL با استفاده از GREATEST و RowVersion
   SQL Server 2022+
   نسخه نمونه‌سازی شده با جداول فرضی Northwind-like
   Author : Alireza Maranaki 
   Create Date : 2025-08-16
   ========================================================= */

/* --- مرحله 1: ساخت جدول Config برای نگه‌داری Checkpoint آخر --- */
IF OBJECT_ID('Config.FactETLTracking', 'U') IS NULL
BEGIN
    CREATE TABLE Config.FactETLTracking (
        FactName       sysname PRIMARY KEY,
        LastRowVersion bigint NOT NULL,
        LastLoadDate   datetime2 NOT NULL DEFAULT sysutcdatetime()
    );
END
GO

/* --- مرحله 2: خواندن آخرین Checkpoint موجود برای این Fact --- */
DECLARE @LastRV bigint;

SELECT @LastRV = LastRowVersion
FROM Config.FactETLTracking
WHERE FactName = N'FactSales_Northwind';

-- اگر رکوردی نبود (بارگذاری اول) مقدار پیش‌فرض 0 بده
IF @LastRV IS NULL
    SET @LastRV = 0;

/* --- مرحله 3: اجرای ETL Incremental با استفاده از RV_Combined --- */

    SELECT
        o.OrderID,
        od.ProductID,
        p.ProductName,
        c.CustomerName,
        -- محاسبه بزرگ‌ترین RowVersion بین منابع
        GREATEST(
            CAST(o.RV_Orders       AS bigint),
            CAST(od.RV_OrderDetails AS bigint),
            CAST(p.RV_Products     AS bigint),
            CAST(c.RV_Customers    AS bigint)
        ) AS RV_Combined
    FROM Orders o
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN Products p      ON od.ProductID = p.ProductID
    JOIN Customers c     ON o.CustomerID = c.CustomerID
    -- شرط Incremental فقط روی RV_Combined
    WHERE GREATEST(
            CAST(o.RV_Orders       AS bigint),
            CAST(od.RV_OrderDetails AS bigint),
            CAST(p.RV_Products     AS bigint),
            CAST(c.RV_Customers    AS bigint)
        ) > @LastRV


