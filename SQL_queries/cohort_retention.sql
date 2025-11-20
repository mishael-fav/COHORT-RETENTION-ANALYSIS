USE Cohort_Retention;

-- =========================================
-- WHY COHORT ANALYSIS?
-- =========================================
-- To understand Customer Behaviour
-- To analyze retention patterns and trends
-- To provide insights into revenue contribution and loyalty by cohort

SELECT *
FROM Online_Retail;

-- =========================================
-- CLEAN & PREPARE DATA
-- =========================================

-- Filter out NULL CustomerIDs and add Revenue
DROP TABLE IF EXISTS #Filtered_Retail;

SELECT 
    InvoiceNo,
    StockCode,
    [Description],
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    (Quantity * UnitPrice) AS Revenue
INTO #Filtered_Retail
FROM Online_Retail
WHERE CustomerID IS NOT NULL;

-- Keep only valid transactions
DROP TABLE IF EXISTS #Valid_Transactions;

SELECT *
INTO #Valid_Transactions
FROM #Filtered_Retail
WHERE Quantity > 0 AND UnitPrice > 0;

-- Handle duplicates
DROP TABLE IF EXISTS #Duplicate_Transactions;

SELECT *,
       ROW_NUMBER() OVER (PARTITION BY InvoiceNo, StockCode, Quantity ORDER BY InvoiceDate) AS row_num
INTO #Duplicate_Transactions
FROM #Valid_Transactions;

-- Create your final cleaned table
DROP TABLE IF EXISTS Online_Retail_Main;

SELECT  
    InvoiceNo,
    StockCode,
    [Description],
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    Revenue
INTO Online_Retail_Main
FROM #Duplicate_Transactions
WHERE row_num = 1;


SELECT *
FROM Online_Retail_Main;

-- =========================================
-- PRELIMINARY EDA
-- =========================================

-- Top Customer by Revenue
SELECT TOP 10 
    CustomerID, 
    SUM(Revenue) AS total_revenue
FROM Online_Retail_Main
GROUP BY CustomerID
ORDER BY total_revenue DESC;


-- Customer frequency (# of orders)
SELECT 
    CustomerID, 
    COUNT(DISTINCT InvoiceNo) AS order_count
FROM Online_Retail_Main
GROUP BY CustomerID
ORDER BY order_count DESC;


-- Top products by quantity sold
SELECT TOP 10 
    Description, 
    SUM(Quantity) AS total_quantity
FROM Online_Retail_Main
GROUP BY Description
ORDER BY total_quantity DESC;


-- Top products by revenue
SELECT TOP 10 
    Description, 
    ROUND(SUM(Revenue), 2) AS total_revenue
FROM Online_Retail_Main
GROUP BY Description
ORDER BY total_revenue DESC;


-- Monthly revenue trend
SELECT 
    YEAR(InvoiceDate) AS year,
    MONTH(InvoiceDate) AS month,
    ROUND(SUM(Revenue), 2) AS monthly_revenue
FROM Online_Retail_Main
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY year, month;


-- Average order value (AOV)
SELECT 
    ROUND(AVG(order_revenue), 2) AS avg_order_value
FROM (
    SELECT InvoiceNo, SUM(Revenue) AS order_revenue
    FROM Online_Retail_Main
    GROUP BY InvoiceNo
) aov;


-- Revenue by country
SELECT 
    Country, 
    ROUND(SUM(Revenue), 2) AS total_revenue,
    COUNT(DISTINCT CustomerID) AS total_customers
FROM Online_Retail_Main
GROUP BY Country
ORDER BY total_revenue DESC;

-- =========================================
-- COHORT ANALYSIS
-- =========================================

-- =========================================
-- 1: IDENTIFY CUSTOMER COHORTS
-- =========================================
DROP TABLE IF EXISTS #CustomerCohort;

SELECT 
    CustomerID,
    MIN(InvoiceDate) AS FirstPurchaseDate,
    DATEFROMPARTS(YEAR(MIN(InvoiceDate)), MONTH(MIN(InvoiceDate)), 1) AS CohortDate
INTO #CustomerCohort
FROM Online_Retail_Main 
GROUP BY CustomerID;

SELECT *
FROM #CustomerCohort;

-- =========================================
-- 2: BUILD COHORT INDEX (MONTH DIFFERENCE)
-- =========================================
DROP TABLE IF EXISTS Cohort_Retention;

SELECT 
    m.*,
    c.CohortDate,
    YEAR(m.InvoiceDate) AS Invoice_Year,
    MONTH(m.InvoiceDate) AS Invoice_Month,
    YEAR(c.CohortDate) AS Cohort_Year,
    MONTH(c.CohortDate) AS Cohort_Month,
    (YEAR(m.InvoiceDate) - YEAR(c.CohortDate)) * 12 +
    (MONTH(m.InvoiceDate) - MONTH(c.CohortDate)) + 1 AS Cohort_Index
INTO Cohort_Retention
FROM Online_Retail_Main m
LEFT JOIN #CustomerCohort c 
    ON m.CustomerID = c.CustomerID
WHERE NOT (YEAR(m.InvoiceDate) = 2011 AND MONTH(m.InvoiceDate) = 12);


SELECT MAX(InvoiceDate)
FROM Cohort_Retention;

SELECT *
FROM Cohort_Retention;

-- =========================================
-- 3: PIVOT COHORT DATA (RETENTION COUNT)
-- =========================================


SELECT *
INTO #CohortCounts
FROM (
    SELECT CohortDate, Cohort_Index, CustomerID
    FROM Cohort_Retention
    GROUP BY CohortDate, Cohort_Index, CustomerID
) base
PIVOT (
    COUNT(CustomerID)
    FOR Cohort_Index IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
) AS PivotedCohort;

SELECT *
FROM #CohortCounts
ORDER BY CohortDate;

-- =========================================
-- 4: CALCULATE PERCENTAGE RETENTION
-- =========================================
SELECT 
    CohortDate,
    1.0 * [1]/[1] * 100 AS [Month1],
    1.0 * [2]/[1] * 100 AS [Month2], 
    1.0 * [3]/[1] * 100 AS [Month3], 
    1.0 * [4]/[1] * 100 AS [Month4], 
    1.0 * [5]/[1] * 100 AS [Month5], 
    1.0 * [6]/[1] * 100 AS [Month6], 
    1.0 * [7]/[1] * 100 AS [Month7],
    1.0 * [8]/[1] * 100 AS [Month8],
    1.0 * [9]/[1] * 100 AS [Month9],
    1.0 * [10]/[1] * 100 AS [Month10],
    1.0 * [11]/[1] * 100 AS [Month11],
    1.0 * [12]/[1] * 100 AS [Month12]
FROM #CohortCounts
ORDER BY CohortDate;

-- =========================================
-- 5: REVENUE ANALYSIS BY COHORT
-- =========================================
SELECT 
    CohortDate,
    Cohort_Index,
    SUM(Revenue) AS TotalRevenue,
    COUNT(DISTINCT CustomerID) AS Active_Customers
FROM Cohort_Retention
GROUP BY CohortDate, Cohort_Index
ORDER BY CohortDate, Cohort_Index;


-- =======================================================
-- 6. COHORT SIZES (Initial Customers per Cohort)
-- =======================================================
DROP TABLE IF EXISTS #CohortSizes;

SELECT
    CohortDate,
    COUNT(DISTINCT CustomerID) AS CohortSize,
    SUM(Revenue) AS InitialRevenue
INTO #CohortSizes
FROM Cohort_Retention
WHERE Cohort_Index = 1
GROUP BY CohortDate;

SELECT * FROM #CohortSizes

-- =======================================================
-- 7. CUSTOMER LIFETIME VALUE (CLV) BY COHORT
-- =======================================================
SELECT
    CohortDate,
    Cohort_Index,
    SUM(Revenue) / COUNT(DISTINCT CustomerID) AS AvgRevenuePerCustomer
FROM Cohort_Retention
GROUP BY CohortDate, Cohort_Index
ORDER BY CohortDate, Cohort_Index;

-- =======================================================
-- 8. CHURN ANALYSIS (Drop-Off %)
-- =======================================================
SELECT
    r.CohortDate,
    r.Cohort_Index,
    CAST(100.0 - (1.0 * COUNT(DISTINCT r.CustomerID) / cs.CohortSize * 100) AS DECIMAL(6,2)) AS ChurnRate
FROM Cohort_Retention r
JOIN #CohortSizes cs 
    ON r.CohortDate = cs.CohortDate
GROUP BY r.CohortDate, r.Cohort_Index, cs.CohortSize
ORDER BY r.CohortDate, r.Cohort_Index;


-- =======================================================
-- 9. GEOGRAPHIC COHORTS (Retention by Country)
-- =======================================================
SELECT
    r.CohortDate,
    r.Cohort_Index,
    r.Country,
    COUNT(DISTINCT r.CustomerID) AS Customers
FROM Cohort_Retention r
GROUP BY r.CohortDate, r.Cohort_Index, r.Country
ORDER BY r.CohortDate, r.Country, r.Cohort_Index;

-- =======================================================
-- 10. PRODUCT-BASED COHORTS (Retention by First Product Bought)
-- =======================================================
;WITH FirstProduct AS (
    SELECT 
        CustomerID,
        MIN(InvoiceDate) AS FirstPurchaseDate
    FROM Online_Retail_Main
    GROUP BY CustomerID
)
SELECT
    r.CohortDate,
    r.Cohort_Index,
    MIN(r.StockCode) AS FirstProductCode, 
    COUNT(DISTINCT r.CustomerID) AS Customers
FROM Cohort_Retention r
JOIN FirstProduct fp
    ON r.CustomerID = fp.CustomerID
GROUP BY r.CohortDate, r.Cohort_Index
ORDER BY r.CohortDate, r.Cohort_Index;


-- Column names
SELECT name AS ColumnName
FROM tempdb.sys.columns
WHERE object_id = OBJECT_ID('tempdb..#Cohort_Retention') 

