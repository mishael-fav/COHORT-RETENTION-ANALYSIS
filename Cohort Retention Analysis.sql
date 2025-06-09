USE Project;

-- =========================================
-- WHY COHORT ANALYSIS?
-- =========================================
----To understand Customer Behaviour
----To analyze pattern and trends

-- =========================================
-- CLEAN & PREPARE DATA
-- =========================================

-- Drop any previous clean table if exists
DROP TABLE IF EXISTS Online_retail_main ;

-- Load data with required fields and filter invalid records
WITH Online_Retail AS (
    SELECT 
        InvoiceNo,
        StockCode,
        [Description],
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country
    FROM [Project].[dbo].[Online Retail]
    WHERE CustomerID IS NOT NULL
),
Valid_Transactions AS (
    SELECT *
    FROM Online_Retail
    WHERE Quantity > 0 AND UnitPrice > 0
),
Duplicate_Transactions AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY InvoiceNo, StockCode, Quantity ORDER BY InvoiceDate) AS row_num
    FROM Valid_Transactions
)
-- Remove duplicates
SELECT *
INTO Online_retail_main 
FROM Duplicate_Transactions
WHERE row_num = 1;

SELECT * FROM Online_retail_main ;

-- ========================================
-- FOR COHORT ANALYSIS, Data required are:
-- ========================================
----unique Identifier (CustomerID)
----Initial Start Date (First Invoice Date)
----Revenue Data

-- =========================================
-- 1: IDENTIFY CUSTOMER COHORTS
-- =========================================

-- Determine each customer’s first purchase month (cohort month)
SELECT 
    CustomerID,
    MIN(InvoiceDate) AS FirstPurchaseDate,
    DATEFROMPARTS(YEAR(MIN(InvoiceDate)), MONTH(MIN(InvoiceDate)), 1) AS CohortDate
INTO #CustomerCohort
FROM Online_retail_main 
GROUP BY CustomerID;

SELECT * FROM #CustomerCohort

--DROP TABLE IF EXISTS #CustomerCohort;

-- =========================================
-- 2: BUILD COHORT INDEX (MONTH DIFFERENCE)
-- =========================================

-- --Create COHORT Index (an integer representation of the number of months that has passed since the Customers first Purchase)

select 
		cohort_mm.*,
		Cohort_index = year_diff * 12 + month_diff + 1
into #Cohort_Retention
from
(
	select cohort_m.*,
			year_diff = Invoice_year - Cohort_year,
			month_diff = Invoice_month - Cohort_month 
	from
	(
		select	m.*,
				c.CohortDate,
				year(m.invoiceDate) Invoice_year,
				month(m.invoiceDate) Invoice_month,
				year(c.CohortDate) Cohort_year,
				month(c.CohortDate) Cohort_month
		from Online_retail_main m
		left join #CustomerCohort c 
			on m.CustomerID= c.CustomerID
			) cohort_m
) cohort_mm

select *
from #Cohort_Retention


-- =========================================
-- 4: PIVOT COHORT DATA (RETENTION COUNT)
-- =========================================

-- Count users in each cohort and cohort index
DROP TABLE IF EXISTS #CohortBase;

SELECT DISTINCT
    CustomerID,
    Cohort_month,
    Cohort_index
INTO #CohortBase
FROM #Cohort_Retention;


SELECT * 
FROM #CohortBase
ORDER BY CustomerID;

-- Pivot the counts

DROP TABLE IF EXISTS #CohortCounts;

SELECT *
INTO #CohortCounts
FROM (
    SELECT CohortDate, Cohort_index,  CustomerID
    FROM #Cohort_Retention
    GROUP BY CohortDate, Cohort_index,  CustomerID
) base
PIVOT (
    COUNT(CustomerID)
    FOR Cohort_index IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13])
) AS PivotedCohort;

-- PIVOT COHORT
SELECT * 
FROM #CohortCounts
ORDER BY CohortDate;

-- =========================================
-- 5: CALCULATE PERCENTAGE RETENTION
-- =========================================

SELECT 
    CohortDate,
	1.0 * [1]/[1] * 100 as [1],
	1.0 * [2]/[1] * 100 as [2], 
	1.0 * [3]/[1] * 100 as [3], 
	1.0 * [4]/[1] * 100 as [4], 
	1.0 * [5]/[1] * 100 as [5], 
	1.0 * [6]/[1] * 100 as [6], 
	1.0 * [7]/[1] * 100 as [7],
	1.0 * [8]/[1] * 100 as [8],
	1.0 * [9]/[1] * 100 as [9],
	1.0 * [10]/[1] * 100 as [10],
	1.0 * [11]/[1] * 100 as [11],
	1.0 * [12]/[1] * 100 as [12],
	1.0 * [13]/[1] * 100 as [13]
FROM #CohortCounts
ORDER BY CohortDate;

SELECT name AS ColumnName
FROM tempdb.sys.columns
WHERE object_id = OBJECT_ID('tempdb..#Cohort_Retention') 
