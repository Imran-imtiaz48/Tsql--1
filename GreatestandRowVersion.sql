/* =========================================================
   Incremental ETL using GREATEST and RowVersion
   SQL Server 2022+
   Sample version using Northwind-like tables
   Author: Alireza Maranaki
   Create Date: 2025-08-16
   ========================================================= */

/* --- Step 1: Create Config Table for Checkpoint Tracking --- */
IF OBJECT_ID('Config.FactETLTracking', 'U') IS NULL
BEGIN
    CREATE TABLE Config.FactETLTracking (
        FactName       sysname PRIMARY KEY,
        LastRowVersion bigint NOT NULL,
        LastLoadDate   datetime2 NOT NULL DEFAULT sysutcdatetime()
    );
END
GO

/* --- Step 2: Retrieve Last Checkpoint for Fact --- */
DECLARE @LastRV bigint;

SELECT @LastRV = LastRowVersion
FROM Config.FactETLTracking
WHERE FactName = N'FactSales_Northwind';

-- Default to 0 if no previous load exists
SET @LastRV = ISNULL(@LastRV, 0);

/* --- Step 3: Incremental ETL using RV_Combined --- */
WITH IncrementalData AS
(
    SELECT
        o.OrderID,
        od.ProductID,
        p.ProductName,
        c.CustomerName,
        -- Compute the greatest RowVersion across all source tables
        GREATEST(
            CAST(o.RV_Orders       AS bigint),
            CAST(od.RV_OrderDetails AS bigint),
            CAST(p.RV_Products     AS bigint),
            CAST(c.RV_Customers    AS bigint)
        ) AS RV_Combined
    FROM Orders o
    INNER JOIN OrderDetails od ON o.OrderID = od.OrderID
    INNER JOIN Products p      ON od.ProductID = p.ProductID
    INNER JOIN Customers c     ON o.CustomerID = c.CustomerID
)
SELECT *
FROM IncrementalData
WHERE RV_Combined > @LastRV
ORDER BY RV_Combined;
