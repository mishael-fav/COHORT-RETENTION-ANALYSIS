USE Cohort_Retention;

-- ============================================================
-- Set analysis date dynamically to the latest invoice
-- ============================================================
DECLARE @analysis_date DATE;

SELECT @analysis_date = MAX(InvoiceDate) 
FROM Cohort_Retention;

-- Drop existing table if re-running
IF OBJECT_ID('dbo.RFM_Segments_Final','U') IS NOT NULL
    DROP TABLE dbo.RFM_Segments_Final;

-- ============================================================
-- Calculate base RFM metrics
-- ============================================================
WITH CustomerRFM AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(InvoiceDate), @analysis_date) AS Recency,
        COUNT(DISTINCT InvoiceNo) AS Frequency,
        SUM(Revenue) AS Monetary,
        MIN(InvoiceDate) AS FirstPurchaseDate,
        MAX(InvoiceDate) AS LastPurchaseDate,
        DATEDIFF(DAY, MIN(InvoiceDate), MAX(InvoiceDate)) + 1 AS CustomerLifespanDays,
        COUNT(DISTINCT StockCode) AS UniqueProducts,
        SUM(Quantity) AS TotalQuantity,
        MIN(CohortDate) AS CohortDate,
        MIN(Cohort_Year) AS Cohort_Year,
        MIN(Cohort_Month) AS Cohort_Month       
    FROM Cohort_Retention
    WHERE CustomerID IS NOT NULL
      AND Quantity > 0
      AND Revenue > 0
    GROUP BY CustomerID
),

-- ============================================================
-- Calculate RFM quintile scores
-- ============================================================
RFM_Scores AS (
    SELECT 
        *,
        -- R: lower recency = better → invert score
        6 - NTILE(5) OVER (ORDER BY Recency ASC) AS R_Score,
        -- F: higher frequency = better
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        -- M: higher spending = better
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM CustomerRFM
),

-- ============================================================
-- Add derived metrics
-- ============================================================
RFM_Enhanced AS (
    SELECT 
        *,
        (R_Score + F_Score + M_Score) AS RFM_Score,
        CAST(R_Score AS VARCHAR(1)) + 
        CAST(F_Score AS VARCHAR(1)) + 
        CAST(M_Score AS VARCHAR(1)) AS RFM_Cell,
        CAST(Monetary / NULLIF(Frequency, 0) AS DECIMAL(12,2)) AS AvgOrderValue,
        CAST(Frequency * 1.0 / NULLIF(CustomerLifespanDays, 0) AS DECIMAL(12,6)) AS PurchaseFrequency,
        CASE WHEN Frequency > 1 
             THEN CAST(CustomerLifespanDays * 1.0 / NULLIF(Frequency - 1, 0) AS DECIMAL(12,2)) 
             ELSE NULL END AS AvgDaysBetweenOrders
    FROM RFM_Scores
),

-- ============================================================
-- Assign segments & actions
-- ============================================================
Customer_Segments AS (
    SELECT 
        *,
        CASE 
            WHEN M_Score >= 4 AND F_Score >= 4 AND R_Score >= 3 THEN 'VIP Customers'
            WHEN F_Score >= 3 AND M_Score >= 3 AND R_Score >= 3 THEN 'Loyal Customers'
            WHEN (R_Score >= 4 AND (F_Score >= 2 OR M_Score >= 3)) 
                 OR (M_Score >= 4 AND R_Score >= 3) THEN 'Potential Customers'
            WHEN (M_Score >= 3 OR F_Score >= 3) AND R_Score <= 2 THEN 'At Risk'
            ELSE 'Lost Customers'
        END AS Customer_Segment,
        
        CASE 
            WHEN M_Score >= 4 AND F_Score >= 4 AND R_Score >= 3 THEN 1
            WHEN (M_Score >= 3 OR F_Score >= 3) AND R_Score <= 2 THEN 2
            WHEN F_Score >= 3 AND M_Score >= 3 AND R_Score >= 3 THEN 3
            WHEN (R_Score >= 4 AND (F_Score >= 2 OR M_Score >= 3)) 
                 OR (M_Score >= 4 AND R_Score >= 3) THEN 4
            ELSE 5
        END AS Action_Priority,
        
        CASE 
            WHEN M_Score >= 4 AND F_Score >= 4 AND R_Score >= 3 
                THEN 'VIP Treatment: Exclusive offers, early access, personal manager'
            WHEN F_Score >= 3 AND M_Score >= 3 AND R_Score >= 3 
                THEN 'Maintain Loyalty: Engagement, loyalty rewards, upsell'
            WHEN (R_Score >= 4 AND (F_Score >= 2 OR M_Score >= 3)) 
                 OR (M_Score >= 4 AND R_Score >= 3) 
                THEN 'Nurture: Increase frequency, new products, build relationship'
            WHEN (M_Score >= 3 OR F_Score >= 3) AND R_Score <= 2 
                THEN 'Win Back: Urgent retention campaign, special offers'
            ELSE 'Final Attempt: Last-chance offer, reduce spend'
        END AS Recommended_Action
    FROM RFM_Enhanced
)

-- ============================================================
-- Save to final table
-- ============================================================
SELECT * 
INTO dbo.RFM_Segments_Final
FROM Customer_Segments;

SELECT *
FROM RFM_Segments_Final;


-- ============================================================
-- SUMMARY STATISTICS BY SEGMENT
-- ============================================================
WITH SegmentStats AS (
    SELECT 
        Customer_Segment,
        Action_Priority,

        -- Base counts and revenue
        COUNT(*) AS CustomerCount,
        SUM(Monetary) AS TotalRevenue,
        AVG(Monetary) AS AvgRevenue,

        -- Behavior metrics
        AVG(Recency) AS AvgDaysSinceLastPurchase,
        AVG(Frequency) AS AvgOrders,
        AVG(AvgOrderValue) AS AvgOrderValue,

        -- RFM scores
        AVG(CAST(R_Score AS FLOAT)) AS AvgRecencyScore,
        AVG(CAST(F_Score AS FLOAT)) AS AvgFrequencyScore,
        AVG(CAST(M_Score AS FLOAT)) AS AvgMonetaryScore
    FROM RFM_Segments_Final
    GROUP BY Customer_Segment, Action_Priority
)
SELECT 
    Customer_Segment,
    Action_Priority,
    CustomerCount,
    CAST(CustomerCount * 100.0 / SUM(CustomerCount) OVER() AS DECIMAL(5,2)) AS CustomerPercent,
    TotalRevenue,
    CAST(TotalRevenue * 100.0 / SUM(TotalRevenue) OVER() AS DECIMAL(5,2)) AS RevenuePercent,
    AvgRevenue,
    AvgDaysSinceLastPurchase,
    AvgOrders,
    AvgOrderValue,
    AvgRecencyScore,
    AvgFrequencyScore,
    AvgMonetaryScore
FROM SegmentStats
ORDER BY Action_Priority, TotalRevenue DESC;


-- ============================================================
-- CUSTOMER SEGMENT DISTRIBUTION BY COHORT
-- ============================================================
SELECT 
    Cohort_Year,
    Cohort_Month,
    Customer_Segment,
    COUNT(*) AS Customers,
    AVG(Monetary) AS AvgRevenue,
    SUM(Monetary) AS TotalRevenue
FROM RFM_Segments_Final
GROUP BY Cohort_Year, Cohort_Month, Customer_Segment
ORDER BY Cohort_Year, Cohort_Month, 
    CASE Customer_Segment
        WHEN 'VIP Customers' THEN 1
        WHEN 'Loyal Customers' THEN 2
        WHEN 'Potential Customers' THEN 3
        WHEN 'At Risk' THEN 4
        WHEN 'Lost Customers' THEN 5
    END;


-- ============================================================
-- Key Insight
-- ============================================================

-- ========================================
-- Revenue at Risk Analysis
-- ========================================
DECLARE @AtRiskRevenue DECIMAL(18,2);
DECLARE @TotalRevenue DECIMAL(18,2);

-- Total revenue at risk
SELECT @AtRiskRevenue = SUM(Monetary)
FROM RFM_Segments_Final
WHERE Customer_Segment = 'At Risk';

-- Total revenue overall
SELECT @TotalRevenue = SUM(Monetary)
FROM RFM_Segments_Final;

-- Return results clearly
SELECT 
    @AtRiskRevenue AS RevenueAtRisk,
    @TotalRevenue AS TotalRevenue,
    CAST(@AtRiskRevenue * 100.0 / NULLIF(@TotalRevenue, 0) AS DECIMAL(5,2)) AS PercentAtRisk;

-- ========================================
-- Largest Segment by Customer Count
-- ========================================
SELECT TOP 1 
    Customer_Segment AS LargestSegment,
    COUNT(*) AS CustomerCount
FROM RFM_Segments_Final
GROUP BY Customer_Segment
ORDER BY COUNT(*) DESC;

-- ========================================
-- Highest Revenue Segment
-- ========================================
SELECT TOP 1 
    Customer_Segment AS HighestRevenueSegment,
    SUM(Monetary) AS SegmentRevenue
FROM RFM_Segments_Final
GROUP BY Customer_Segment
ORDER BY SUM(Monetary) DESC;

-- ============================================================
-- EXPORT DATA FOR PYTHON ML ANALYSIS
-- ============================================================

SELECT 
    CustomerID,
    Customer_Segment,  -- Identifiers
    Action_Priority,
    Recency,   -- RFM Metrics (for ML)
    Frequency,      
    Monetary,
    R_Score,   -- RFM Scores (for ML)
    F_Score,       
    M_Score,
    RFM_Score,
    AvgOrderValue,       -- Derived features (for ML)
    PurchaseFrequency,
    CustomerLifespanDays,
    AvgDaysBetweenOrders,
    UniqueProducts,
    TotalQuantity,
    Cohort_Year,       -- Cohort info
    Cohort_Month,
    FirstPurchaseDate,       -- Dates (for analysis)
    LastPurchaseDate
FROM RFM_Segments_Final
ORDER BY Action_Priority, Monetary DESC;


-- ============================================================
-- ACTIONABLE BUSINESS STRATEGY BY SEGMENT
-- ============================================================

SELECT 
    Customer_Segment,
    Action_Priority,
    COUNT(*) AS Customers,
    SUM(Monetary) AS Revenue,
    
    -- Strategy
    CASE Customer_Segment
        WHEN 'VIP Customers' THEN 
            'Strategy: PROTECT & DELIGHT | Budget: High | Frequency: Weekly | Channel: Personal + Email'
        WHEN 'Loyal Customers' THEN 
            'Strategy: MAINTAIN & UPSELL | Budget: Medium | Frequency: Bi-weekly | Channel: Email + SMS'
        WHEN 'Potential Customers' THEN 
            'Strategy: NURTURE & GROW | Budget: Medium | Frequency: Weekly | Channel: Email + Social'
        WHEN 'At Risk' THEN 
            'Strategy: WIN BACK URGENTLY | Budget: High | Frequency: Immediate | Channel: Personal Call + Email'
        WHEN 'Lost Customers' THEN 
            'Strategy: LAST CHANCE | Budget: Low | Frequency: Monthly | Channel: Email only'
    END AS Marketing_Strategy,
    
    -- Sample tactics
    CASE Customer_Segment
        WHEN 'VIP Customers' THEN 
            'Tactics: VIP events, Early access, Dedicated support, Surprise gifts'
        WHEN 'Loyal Customers' THEN 
            'Tactics: Loyalty points, Referral rewards, Cross-sell, Reviews'
        WHEN 'Potential Customers' THEN 
            'Tactics: Product education, Bundle offers, Frequency incentives'
        WHEN 'At Risk' THEN 
            'Tactics: 20% win-back discount, Survey, Personal call, Free shipping'
        WHEN 'Lost Customers' THEN 
            'Tactics: 30% final offer, Then suppress from campaigns'
    END AS Recommended_Tactics

FROM RFM_Segments_Final
GROUP BY Customer_Segment, Action_Priority
ORDER BY Action_Priority;