-- Test Queries for emir_trade_activity
-- Generated: 2025-11-19
-- Database: txt2sql_dev_athena_db

-- ========================================
-- BASIC TESTS
-- ========================================

-- Test 1: Count total trades
SELECT COUNT(*) as total_trades 
FROM emir_trade_activity;
-- Expected: 100,000

-- Test 2: Show sample records (limit columns to avoid 191 column dump)
SELECT 
    "UTI",
    "Reporting timestamp",
    "Asset class",
    "Contract type",
    "Valuation amount",
    "Valuation currency",
    "Cleared"
FROM emir_trade_activity 
LIMIT 10;

-- Test 3: Describe table schema
DESCRIBE emir_trade_activity;

-- ========================================
-- ASSET CLASS ANALYSIS
-- ========================================

-- Test 4: Count trades by asset class
SELECT 
    "Asset class",
    COUNT(*) as trade_count
FROM emir_trade_activity
WHERE "Asset class" IS NOT NULL AND "Asset class" != ''
GROUP BY "Asset class"
ORDER BY trade_count DESC;

-- Test 5: Currency swaps specifically
SELECT 
    COUNT(*) as currency_swap_count,
    COUNT(DISTINCT "UTI") as unique_trades
FROM emir_trade_activity
WHERE "Asset class" = 'CURR' AND "Contract type" = 'SWAP';

-- ========================================
-- DATE RANGE QUERIES
-- ========================================

-- Test 6: Get date range of reporting timestamps
SELECT 
    MIN("Reporting timestamp") as earliest_report,
    MAX("Reporting timestamp") as latest_report,
    COUNT(DISTINCT DATE("Reporting timestamp")) as unique_dates
FROM emir_trade_activity
WHERE "Reporting timestamp" IS NOT NULL;

-- Test 7: Trades reported in September 2025
SELECT 
    COUNT(*) as sept_trades,
    COUNT(DISTINCT "Asset class") as asset_classes
FROM emir_trade_activity
WHERE "Reporting timestamp" >= '2025-09-01'
  AND "Reporting timestamp" < '2025-10-01';

-- ========================================
-- CLEARING ANALYSIS
-- ========================================

-- Test 8: Cleared vs Uncleared breakdown
SELECT 
    "Cleared",
    COUNT(*) as trade_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM emir_trade_activity
GROUP BY "Cleared"
ORDER BY trade_count DESC;

-- Test 9: Top Central Counterparties
SELECT 
    "Central counterparty",
    COUNT(*) as trade_count
FROM emir_trade_activity
WHERE "Cleared" = 'true' 
  AND "Central counterparty" IS NOT NULL
  AND "Central counterparty" != ''
GROUP BY "Central counterparty"
ORDER BY trade_count DESC
LIMIT 10;

-- ========================================
-- FINANCIAL ANALYSIS
-- ========================================

-- Test 10: Valuation amount summary (requires CAST)
SELECT 
    "Valuation currency",
    COUNT(*) as trade_count,
    ROUND(AVG(CAST("Valuation amount" AS DOUBLE)), 2) as avg_valuation,
    ROUND(SUM(CAST("Valuation amount" AS DOUBLE)), 2) as total_valuation
FROM emir_trade_activity
WHERE "Valuation amount" IS NOT NULL 
  AND "Valuation amount" != ''
  AND "Valuation currency" IS NOT NULL
GROUP BY "Valuation currency"
ORDER BY total_valuation DESC
LIMIT 10;

-- Test 11: Notional amount analysis by asset class
SELECT 
    "Asset class",
    "Notional currency 1",
    COUNT(*) as trade_count,
    ROUND(SUM(CAST("Notional amount of leg 1" AS DOUBLE)), 2) as total_notional
FROM emir_trade_activity
WHERE "Notional amount of leg 1" IS NOT NULL 
  AND "Notional amount of leg 1" != ''
  AND "Asset class" IS NOT NULL
GROUP BY "Asset class", "Notional currency 1"
ORDER BY total_notional DESC
LIMIT 15;

-- ========================================
-- COUNTERPARTY ANALYSIS
-- ========================================

-- Test 12: Country distribution
SELECT 
    "Country of the counterparty 2",
    COUNT(*) as trade_count
FROM emir_trade_activity
WHERE "Country of the counterparty 2" IS NOT NULL
  AND "Country of the counterparty 2" != ''
GROUP BY "Country of the counterparty 2"
ORDER BY trade_count DESC
LIMIT 15;

-- Test 13: Direction breakdown
SELECT 
    "Direction",
    COUNT(*) as trade_count
FROM emir_trade_activity
WHERE "Direction" IS NOT NULL
GROUP BY "Direction"
ORDER BY trade_count DESC;

-- ========================================
-- VENUE ANALYSIS
-- ========================================

-- Test 14: Top execution venues
SELECT 
    "Venue of execution",
    COUNT(*) as trade_count
FROM emir_trade_activity
WHERE "Venue of execution" IS NOT NULL
  AND "Venue of execution" != ''
GROUP BY "Venue of execution"
ORDER BY trade_count DESC
LIMIT 10;

-- ========================================
-- CONTRACT TYPE ANALYSIS
-- ========================================

-- Test 15: Contract types by asset class
SELECT 
    "Asset class",
    "Contract type",
    COUNT(*) as trade_count
FROM emir_trade_activity
WHERE "Asset class" IS NOT NULL
  AND "Contract type" IS NOT NULL
GROUP BY "Asset class", "Contract type"
ORDER BY "Asset class", trade_count DESC;

-- ========================================
-- ADVANCED: Multi-dimension Analysis
-- ========================================

-- Test 16: Cleared trades by asset class and currency
SELECT 
    "Asset class",
    "Valuation currency",
    "Cleared",
    COUNT(*) as trade_count,
    ROUND(AVG(CAST("Valuation amount" AS DOUBLE)), 2) as avg_valuation
FROM emir_trade_activity
WHERE "Asset class" IS NOT NULL
  AND "Valuation currency" IS NOT NULL
  AND "Valuation amount" IS NOT NULL
  AND "Valuation amount" != ''
GROUP BY "Asset class", "Valuation currency", "Cleared"
HAVING COUNT(*) > 100
ORDER BY "Asset class", trade_count DESC
LIMIT 20;

-- ========================================
-- OPTIONS ANALYSIS
-- ========================================

-- Test 17: Option trades breakdown
SELECT 
    "Option type",
    "Option style",
    COUNT(*) as trade_count,
    ROUND(AVG(CAST("Strike price" AS DOUBLE)), 2) as avg_strike
FROM emir_trade_activity
WHERE "Contract type" = 'OPTN'
  AND "Option type" IS NOT NULL
  AND "Strike price" IS NOT NULL
  AND "Strike price" != ''
GROUP BY "Option type", "Option style"
ORDER BY trade_count DESC;

-- ========================================
-- ACTION TYPE ANALYSIS (Lifecycle)
-- ========================================

-- Test 18: Trade lifecycle events
SELECT 
    "Action type",
    "Event type",
    COUNT(*) as event_count
FROM emir_trade_activity
WHERE "Action type" IS NOT NULL
  AND "Event type" IS NOT NULL
GROUP BY "Action type", "Event type"
ORDER BY event_count DESC;

-- ========================================
-- NOTES FOR AGENT
-- ========================================

/*
IMPORTANT REMINDERS:
1. NEVER use SELECT * (191 columns!)
2. All columns stored as STRING - use CAST for numbers
3. Column names have spaces - use backticks or quotes
4. Primary date field: "Reporting timestamp"
5. For financials: CAST("Valuation amount" AS DOUBLE)
6. Filter NULLs and empty strings for accurate aggregations
*/
