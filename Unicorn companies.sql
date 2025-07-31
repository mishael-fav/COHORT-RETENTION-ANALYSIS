use Unicorn;


-- ====================
-- EXPLORATORY DATA ANALYSIS  
-- ====================
select * from Unicorn_C;

--General overview of the Unicorn Companies
SELECT 
    COUNT(*) AS total_companies,
    MIN(Valuation2) AS min_valuation,
    MAX(Valuation2) AS max_valuation,
    AVG(Valuation2) AS avg_valuation
FROM Unicorn_C;

--How many Unicorn Companies are valued above average (most highly-valued unicorns)
SELECT COUNT (*) No_of_Unicorn
FROM Unicorn_C
WHERE Valuation2 > (SELECT AVG(Valuation2) FROM Unicorn_C);

--Number of Unicorn Company with each passing Year
SELECT 
	[Year Founded],
    COUNT(*) AS total_companies
FROM Unicorn_C
GROUP BY [Year Founded]
ORDER BY [Year Founded];


-- =============================================
-- 1. In which countries or cities should we consider expanding operations or investments 
-- based on unicorn concentration?
-- =============================================

-- Top 10 Countries by Number of Unicorns
SELECT Country, COUNT(*) AS unicorn_count
FROM Unicorn_C
GROUP BY Country
ORDER BY unicorn_count DESC
;

-- Top 10 Cities by Number of Unicorns
SELECT City, Country, COUNT(*) AS unicorn_count
FROM Unicorn_C
GROUP BY City, Country
ORDER BY unicorn_count DESC
;

-- Percentage of unicorn in TOTAL by City and Country
SELECT TOP 10 
    City, 
    Country, 
    COUNT(*) AS unicorn_count,
    ROUND(CAST(COUNT(*) AS FLOAT) / 
          (SELECT COUNT(*) FROM Unicorn_C) * 100, 2) AS percentage_of_total
FROM Unicorn_C
GROUP BY City, Country
ORDER BY unicorn_count DESC;

-- Percentage of unicorn in each country by City
WITH CountryTotals AS (
    SELECT Country, COUNT(*) AS total_in_country
    FROM Unicorn_C
    GROUP BY Country
)
SELECT TOP 10 
    uc.City, 
    uc.Country, 
    COUNT(*) AS unicorn_count,
    ROUND(CAST(COUNT(*) AS FLOAT) / ct.total_in_country * 100, 2) AS percentage_of_country_total
FROM Unicorn_C uc
JOIN CountryTotals ct ON uc.Country = ct.Country
GROUP BY uc.City, uc.Country, ct.total_in_country
ORDER BY unicorn_count DESC;


-- =============================================
-- 2. Which industries are leading in unicorn creation, and are these trends 
-- consistent across continents?
-- =============================================

-- Top Industries Globally
-- Industries have the most or highest-valued unicorns
SELECT 
    Industry, 
    COUNT(*) AS total_companies,
    SUM(Valuation2) AS total_valuation
FROM Unicorn_C
GROUP BY Industry
ORDER BY total_valuation DESC;

-- Top Industries by Continent
SELECT Continent, Industry, COUNT(*) AS industry_count
FROM Unicorn_C
GROUP BY Continent, Industry
ORDER BY industry_count DESC;

-- By Country
SELECT Country, Industry, COUNT(*) AS industry_count
FROM Unicorn_C
GROUP BY Country, Industry
ORDER BY industry_count DESC;


-- =============================================
-- 3. Which investors consistently fund high-valuation or fast-growing unicorns?
-- Which countries are the top investors from?
-- =============================================

--TOP 10 INVESTORS
SELECT TOP 10 investor, COUNT(*) AS num_investments
FROM (
    SELECT [Investor 1] AS investor FROM Unicorn_C WHERE [Investor 1] IS NOT NULL
    UNION ALL
    SELECT [Investor 2] FROM Unicorn_C WHERE [Investor 2] IS NOT NULL
    UNION ALL
    SELECT [Investor 3] FROM Unicorn_C WHERE [Investor 3] IS NOT NULL
    UNION ALL
    SELECT [Investor 4] FROM Unicorn_C WHERE [Investor 4] IS NOT NULL
) AS all_investors
GROUP BY investor
ORDER BY num_investments DESC
;
 -- there was an oversight with the cleaning done in excel thats why some companies with the same name is appearing twice.
 -- apparently the investor columns have a space character before the start of each investor name. Starting from Investor 2 column
 -- We need to do some TRIMMING and UPDATING

UPDATE Unicorn_C
SET 
    [Investor 1] = TRIM([Investor 1]),
    [Investor 2] = TRIM([Investor 2]),
    [Investor 3] = TRIM([Investor 3]),
    [Investor 4] = TRIM([Investor 4]);

-- Cities and Countries with Top investors
WITH invest AS (
    SELECT [Investor 1] AS investor, City, Country FROM Unicorn_C WHERE [Investor 1] IS NOT NULL
    UNION ALL
    SELECT [Investor 2], City, Country FROM Unicorn_C WHERE [Investor 2] IS NOT NULL
    UNION ALL
    SELECT [Investor 3], City, Country FROM Unicorn_C WHERE [Investor 3] IS NOT NULL
    UNION ALL
    SELECT [Investor 4], City, Country FROM Unicorn_C WHERE [Investor 4] IS NOT NULL
)

SELECT TOP 10
    investor,
	City,
    Country, 
    COUNT(*) AS num_investments
FROM invest
GROUP BY investor, City, Country
ORDER BY num_investments DESC;


-- =============================================
-- 4. Are companies reaching unicorn status faster now compared to the past?
-- Which industries or geographies show faster timelines?
-- =============================================

-- Time to Unicorn per Company
SELECT 
    Company, Industry,
    YEAR([Date Joined]) - [Year Founded] AS years_to_unicorn
FROM Unicorn_C
ORDER BY years_to_unicorn ASC;

-- Average Time to Unicorn by Industry
SELECT 
    Industry,
    ROUND(AVG((YEAR ([Date Joined]) - [Year Founded])), 0) AS Avg_Years_To_Unicorn
FROM Unicorn_C
WHERE [Year Founded] IS NOT NULL AND [Date Joined] IS NOT NULL
GROUP BY Industry
ORDER BY Avg_Years_To_Unicorn;

-- Yearly Average Time to Unicorn
SELECT 
	YEAR ([Date Joined]) AS Year_joined,
    ROUND(AVG((YEAR ([Date Joined]) - [Year Founded])), 0) AS Avg_Years_To_Unicorn
FROM Unicorn_C
WHERE [Year Founded] IS NOT NULL AND [Date Joined] IS NOT NULL
GROUP BY YEAR ([Date Joined])
ORDER BY Year_joined;


--Alternatively, how efficiently a company has turned investor funding into perceived value.
--how many dollars in valuation the company achieved for every $1 of investor funding
SELECT 
    Company, 
    Valuation2, 
    Funding2,
    ROUND((Valuation2 / Funding2),1) AS valuation_to_funding_ratio
FROM Unicorn_C
WHERE Funding2 > 0
ORDER BY valuation_to_funding_ratio DESC;


-- =============================================
-- 5. Which cities have emerged as innovation hubs for unicorn creation?
-- How has this changed over time?
-- =============================================

-- Number of unicorns per year joined:
SELECT 
    YEAR([Date Joined]) AS year_joined, 
    COUNT(*) AS new_unicorns
FROM Unicorn_C
GROUP BY YEAR([Date Joined])
ORDER BY year_joined;

-- Trend of Unicorns FOUNDED per year across all industries
SELECT Industry, [Year Founded], COUNT(*) AS industry_count
FROM Unicorn_C
GROUP BY Industry, [Year Founded]
ORDER BY [Year Founded] ASC, Industry;

-- Unicorn Count by Country Over Time
SELECT 
    Country,
    YEAR([Date Joined]) AS Year_Joined,
    COUNT(*) AS unicorns_in_year
FROM Unicorn_C
WHERE Country IS NOT NULL AND [Date Joined] IS NOT NULL
GROUP BY Country, YEAR([Date Joined])
ORDER BY Year_Joined;


-- Number of unicorns FOUNDED per year across industries (i.e Fintech Edtech, Travel, Other, Supply chain, & delivery, Auto & transportation etc)
SELECT Industry, [Year Founded], COUNT(*) AS industry_count
FROM Unicorn_C
WHERE Industry = 'Fintech'
GROUP BY Industry, [Year Founded]
ORDER BY [Year Founded];


-- Number of unicorns per year across industries
SELECT Industry, YEAR([Date Joined]) Year_joined, COUNT(*) AS industry_count
FROM Unicorn_C
WHERE Industry = 'Fintech'
GROUP BY Industry, YEAR([Date Joined])
ORDER BY YEAR([Date Joined]);



-- 2021 is a very PIVOTAL YEAR as it records the most Unicorn per Year (520)
-- Let's investigate this!!!
-- =============================================
-- Unicorn Count by industry in 2021
SELECT 
    Industry,
    COUNT(*) AS unicorns_in_year_2021
FROM Unicorn_C
WHERE Industry IS NOT NULL AND [Date Joined] IS NOT NULL AND YEAR([Date Joined])=2021
GROUP BY Industry, YEAR([Date Joined])
ORDER BY unicorns_in_year_2021 DESC;

-- Unicorn Companies in 2021
SELECT 
    Company
FROM Unicorn_C
WHERE Company IS NOT NULL AND [Date Joined] IS NOT NULL AND YEAR([Date Joined])=2021

-- list of all companies under the Fintech Industry
SELECT 
    STUFF((
        SELECT DISTINCT ', ' + Company
		FROM Unicorn_C
		WHERE Company IS NOT NULL AND [Date Joined] IS NOT NULL AND YEAR([Date Joined])=2021 AND Industry = 'Fintech'
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''
    ) AS Company_List;

-- LIST OF UNICORN COMPANIES IN 2021 UNDER THE FINTECH INDUSTRY (138)
-- =============================================
-- Acko General Insurance, Addepar, AgentSync, Ajaib, Alan, Alchemy, Alloy, Amber Group, Amount, Anchorage Digital, Ascend Money, 
-- At-Bay, Betterment, BharatPe, BitPanda, Bitso, Blockchain.com, BlockDaemon, BlockFi, Blockstream, Bolt, bolttech, Bought By Many,
-- Bunq, candy.com, Carson Group, Cedar, Celsius Network, CFGI, ChargeBee Technologies, Chipper Cash, Clara, Clearco, Clearcover, Clip, 
-- CloudWalk, CoinDCX, CoinList, CoinSwitch Kuber, ConsenSys, CRED, Current, DailyPay, Dapper Labs, Deel, Digit Insurance, 
-- Digital Currency Group, Divvy Homes, DriveWealth, Dunamu, Earnix, Ethos, Extend, FalconX, Fireblocks, FloQast, Flutterwave,
-- Forte Labs, Freshbooks, FTX, Fundbox, Gemini, Groww, Guideline, HomeLight, Huisuanzhang, Human Interest, Hyperchain, iCapital Network,
-- Injective Protocol, Interos, Konfio, Lendable, Lunar, Lydia, M1 Finance, Mambu, Marshmallow, Masterworks, Matrixport, Melio, Mercury,
-- MobiKwik, MobileCoin, Modern Treasury, MoMo, MoonPay, MX Technologies, Mynt, NIUM, Opay, Orchard, Pacaso, Paxos, Pilot.com, Pipe, Pleo,
-- PPRO, Public, Ramp, ReCharge, Remote, SaltPay, Scalable Capital, Sidecar Health, Signifyd, Slice, SmartAsset, SmartHR, Snapdocs, 
-- solarisBank, SpotOn, Starling Bank, Stash, Sunbit, Swile, TaxBit, The Bank of London, Thought Machine, Trade Republic, TradingView, 
-- TrueLayer, Uala, Upstox, Varo Bank, Vise, Wave, WeBull, Worldcoin, Wrapbook, Xendit, Xiaobing, Zego, ZenBusiness, ZEPZ, Zeta, Zilch, Zopa


-- Which investors contribute to the spike in unicorn companies in 2021
-- Top Investors Behind 2021 Unicorns Spike
WITH investor_cte AS (
    SELECT [Investor 1] AS Investor FROM Unicorn_C WHERE YEAR([Date Joined]) = 2021 AND [Investor 1] IS NOT NULL
    UNION ALL
    SELECT [Investor 2] FROM Unicorn_C WHERE YEAR([Date Joined]) = 2021 AND [Investor 2] IS NOT NULL
    UNION ALL
    SELECT [Investor 3] FROM Unicorn_C WHERE YEAR([Date Joined]) = 2021 AND [Investor 3] IS NOT NULL
    UNION ALL
    SELECT [Investor 4] FROM Unicorn_C WHERE YEAR([Date Joined]) = 2021 AND [Investor 4] IS NOT NULL
)

SELECT TOP 10 
    Investor, 
    COUNT(*) AS Unicorn_Count_2021
FROM investor_cte
GROUP BY Investor
ORDER BY Unicorn_Count_2021 DESC;


-- List of Investors and Their Funded Unicorn Companies
WITH investor_company_cte AS (
    SELECT [Investor 1] AS Investor, Company FROM Unicorn_C WHERE [Investor 1] IS NOT NULL
    UNION ALL
    SELECT [Investor 2], Company FROM Unicorn_C WHERE [Investor 2] IS NOT NULL
    UNION ALL
    SELECT [Investor 3], Company FROM Unicorn_C WHERE [Investor 3] IS NOT NULL
    UNION ALL
    SELECT [Investor 4], Company FROM Unicorn_C WHERE [Investor 4] IS NOT NULL
)

SELECT 
    Investor,
    STUFF(( SELECT ', ' + ic2.Company
			FROM investor_company_cte ic2
			WHERE ic2.Investor = ic1.Investor
			FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS Funded_Companies
FROM investor_company_cte ic1
GROUP BY Investor
ORDER BY Investor;


-- List of Unique Investors in FINTECH Companies
WITH fintech_investors AS (
    SELECT [Investor 1] AS Investor FROM Unicorn_C WHERE Industry = 'Fintech' AND [Investor 1] IS NOT NULL
    UNION
    SELECT [Investor 2] FROM Unicorn_C WHERE Industry = 'Fintech' AND [Investor 2] IS NOT NULL
    UNION
    SELECT [Investor 3] FROM Unicorn_C WHERE Industry = 'Fintech' AND [Investor 3] IS NOT NULL
    UNION
    SELECT [Investor 4] FROM Unicorn_C WHERE Industry = 'Fintech' AND [Investor 4] IS NOT NULL
)

SELECT 
    STUFF((
        SELECT DISTINCT ', ' + Investor
        FROM fintech_investors
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS Investors_List

-- =============================================
-- One major factor that contributed to the significant number of Unicorn in 2021 is the Global Pandemic (COVID-19) which restricted movement and instigated a lockdown
-- COVID-19 accelerated digital adoption in 2021, boosting Fintech and Internet Software & Services.
-- Lockdowns increased demand for digital payments, online banking, and remote tools,
-- leading to a surge in unicorns in these sectors due to rapid growth and investor interest.


-- =============================================
-- 6. Are Newer Companies More Likely to Become Unicorns?
-- =============================================

--There is a an unusual skyrocketing (significant peak) in 2021, after which there is significant drop in 2022. 
-- We can attribute this to digital transformation in the wake of the COVID-19 pandemic.
-- It's most likely to continue in the same steady trend from before the 2021
SELECT YEAR([Date Joined]) AS Year_Joined, COUNT(*) AS unicorn_count
FROM Unicorn_C
WHERE [Date Joined] IS NOT NULL
GROUP BY YEAR([Date Joined])
ORDER BY Year_Joined;


-- =============================================
-- 7. Yearly Growth pattern before the year 2021
-- =============================================
-- The significant emergence of Unicorn Companies in 2021 can be traced down to the COVID-19 pandemic. 
-- Events like the COVID-19 pandemic are not regular occurences, hence 2021 was excluded from this analysis helps avoid skewed data, 
-- which could introduce bias and misrepresent trends in industry investment. 
-- Focusing on 2012–2020 ensures consistency and reliability of insights.


-- Yearly Valuation Growth by Industry (Before 2021)
WITH YearlyIndustryValuation AS (
    SELECT 
        Industry,
        YEAR([Date Joined]) AS Year_Joined,
        SUM(Valuation2) AS Total_Valuation
    FROM Unicorn_C
    WHERE 
        [Date Joined] IS NOT NULL
        AND Valuation2 IS NOT NULL
        AND YEAR([Date Joined]) < 2021
        AND Industry IS NOT NULL
    GROUP BY Industry, YEAR([Date Joined])
),

GrowthCalculation AS (
    SELECT 
        Industry,
        Year_Joined,
        Total_Valuation,
        LAG(Total_Valuation) OVER (PARTITION BY Industry ORDER BY Year_Joined) AS Prev_Valuation
    FROM YearlyIndustryValuation
)

SELECT 
    Industry,
    Year_Joined,
    Total_Valuation,
    Prev_Valuation,
    ROUND(
        CASE 
            WHEN Prev_Valuation IS NULL THEN NULL
            ELSE ((Total_Valuation - Prev_Valuation) / Prev_Valuation) * 100
        END, 2
    ) AS YoY_Growth_Percentage
FROM GrowthCalculation
ORDER BY Industry, Year_Joined;


-- Industry Valuation Share Over Time (Pre-2021)
WITH IndustryYTD AS (
    SELECT 
        Industry,
        YEAR([Date Joined]) AS Year_Joined,
        SUM(Valuation2) AS Industry_Valuation
    FROM Unicorn_C
    WHERE 
        [Date Joined] IS NOT NULL
        AND Valuation2 IS NOT NULL
        AND YEAR([Date Joined]) <= 2020
    GROUP BY Industry, YEAR([Date Joined])
),
TotalYTD AS (
    SELECT 
        Year_Joined,
        SUM(Industry_Valuation) AS Total_Valuation
    FROM IndustryYTD
    GROUP BY Year_Joined
)

SELECT 
    i.Industry,
    i.Year_Joined,
    i.Industry_Valuation,
    t.Total_Valuation,
    ROUND(100.0 * i.Industry_Valuation / t.Total_Valuation, 2) AS Percentage_Share
FROM IndustryYTD i
JOIN TotalYTD t
    ON i.Year_Joined = t.Year_Joined
ORDER BY i.Year_Joined, Percentage_Share DESC;


-- Yearly Valuation Growth by Investor (Before 2021)
WITH AllInvestors AS (
    SELECT [Investor 1] AS Investor, Valuation2, [Date Joined]
    FROM Unicorn_C
    WHERE [Investor 1] IS NOT NULL AND Valuation2 IS NOT NULL AND [Date Joined] IS NOT NULL AND YEAR([Date Joined]) < 2021
    UNION ALL
    SELECT [Investor 2], Valuation2, [Date Joined]
    FROM Unicorn_C
    WHERE [Investor 2] IS NOT NULL AND Valuation2 IS NOT NULL AND [Date Joined] IS NOT NULL AND YEAR([Date Joined]) < 2021
    UNION ALL
    SELECT [Investor 3], Valuation2, [Date Joined]
    FROM Unicorn_C
    WHERE [Investor 3] IS NOT NULL AND Valuation2 IS NOT NULL AND [Date Joined] IS NOT NULL AND YEAR([Date Joined]) < 2021
    UNION ALL
    SELECT [Investor 4], Valuation2, [Date Joined]
    FROM Unicorn_C
    WHERE [Investor 4] IS NOT NULL AND Valuation2 IS NOT NULL AND [Date Joined] IS NOT NULL AND YEAR([Date Joined]) < 2021
),

InvestorValuationByYear AS (
    SELECT 
        Investor,
        YEAR([Date Joined]) AS Year_Joined,
        SUM(Valuation2) AS Total_Valuation
    FROM AllInvestors
    GROUP BY Investor, YEAR([Date Joined])
),

InvestorGrowth AS (
    SELECT 
        Investor,
        Year_Joined,
        Total_Valuation,
        LAG(Total_Valuation) OVER (PARTITION BY Investor ORDER BY Year_Joined) AS Prev_Valuation
    FROM InvestorValuationByYear
)

SELECT 
    Investor,
    Year_Joined,
    Total_Valuation,
    Prev_Valuation,
    ROUND(
        CASE 
            WHEN Prev_Valuation IS NULL THEN NULL
            ELSE ((Total_Valuation - Prev_Valuation) / Prev_Valuation) * 100
        END, 2
    ) AS YoY_Growth_Percentage
FROM InvestorGrowth
ORDER BY Investor, Year_Joined;

-- Yearly Unicorn Count by Industry (Excluding 2021)
SELECT 
    Industry,
    YEAR([Date Joined]) AS Year_Joined,
    COUNT(*) AS Industry_Unicorns
FROM Unicorn_C
WHERE 
    [Date Joined] IS NOT NULL 
    AND YEAR([Date Joined]) < 2021
GROUP BY Industry, YEAR([Date Joined])
ORDER BY Industry, Year_Joined;


-- =============================================
-- Key Insights & Findings:
-- =============================================
--The total of Unicorn Companies as registered by this dataset is 1074, of which 240 companies have valuations above the average.
-- there have been a gradual increase in emergence Unicorn Companies over the years, with the peak at 2021 (520). 
--this significant increase from a gradual trend can be attributed to the Global Pandemic (COVID-19), w hich acceerated the digital transformation
-- The United State remains the Country with the highest number of Unicorn Companies (562), leading the preceeding country more that 5 margins.
-- San Francisco tops the list at 148, habouring 26% of the United State Unicorn Companies and 14% world wide, and clocking a wooping 303 Unicorn Companies in 2021
-- This is followed closely by the New York at 103.

-- High-Growth & Emerging Sectors:
-- =============================================
-- Fintech: Grew from 11.0% (2016) to 26.7% (2022) — the fastest-growing vertical with strong investor confidence.
-- AI/Big Data/Analytics: Rose steadily from 9.8% (2020) to 12.3% (2022), reflecting widespread enterprise adoption.
-- SaaS: Increased to 8.6% (2021) before slightly dipping, signaling consistent relevance in B2B software.

-- Pandemic-Driven Spikes (Short-Term Highs):
-- =============================================
-- HealthTech & Biotech peaked in 2020 due to COVID-19 but declined in 2022.
-- HealthTech: 7.6% (2020) → 5.1% (2022)
-- Biotech: 6.3% (2020) → 3.7% (2022)
-- E-Commerce: Hit a high in 2020 (15.5%) but fell back to 10.4% in 2022.

-- Declining Sectors:
-- =============================================
-- Real Estate Tech: Decreased from 9.0% (2016) to 3.4% (2022)
-- Manufacturing: Dropped from 6.0% (2016) to 2.8% (2022), showing limited VC appeal.

-- Hype-Driven Growth:
-- =============================================
-- Web3/Blockchain: Jumped from 1.9% (2020) to 6.7% (2021), then stabilized at 5.4% (2022) — strong momentum, but high volatility.
