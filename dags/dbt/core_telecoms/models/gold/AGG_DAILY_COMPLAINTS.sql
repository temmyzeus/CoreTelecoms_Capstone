{{
    config(
        materialized='incremental',
        schema='gold',
        unique_key=['DATE', 'COMPLAINT_CATEGORY', 'CHANNEL_TYPE'],
        tags=['aggregate', 'gold', 'complaints', 'reporting']
    )
}}

WITH daily_aggregates AS (
    SELECT 
        -- Grouping dimensions
        REQUEST_DATE AS DATE,
        COMPLAINT_CATEGORY,
        CHANNEL_TYPE,
        
        -- Volume metrics
        COUNT(*) AS TOTAL_COMPLAINTS,
        COUNT(CASE WHEN IS_RESOLVED = 1 THEN 1 END) AS RESOLVED_COUNT,
        COUNT(CASE WHEN IS_PENDING = 1 THEN 1 END) AS PENDING_COUNT,
        COUNT(CASE WHEN IS_REJECTED = 1 THEN 1 END) AS REJECTED_COUNT,
        COUNT(CASE WHEN IS_SAME_DAY_RESOLUTION = 1 THEN 1 END) AS SAME_DAY_RESOLUTION_COUNT,
        
        -- Resolution time metrics (only for resolved complaints)
        ROUND(AVG(CASE WHEN IS_RESOLVED = 1 THEN RESOLUTION_TIME_HOURS END), 2) AS AVG_RESOLUTION_TIME_HOURS,
        ROUND(MEDIAN(CASE WHEN IS_RESOLVED = 1 THEN RESOLUTION_TIME_HOURS END), 2) AS MEDIAN_RESOLUTION_TIME_HOURS,
        MIN(CASE WHEN IS_RESOLVED = 1 THEN RESOLUTION_TIME_HOURS END) AS MIN_RESOLUTION_TIME_HOURS,
        MAX(CASE WHEN IS_RESOLVED = 1 THEN RESOLUTION_TIME_HOURS END) AS MAX_RESOLUTION_TIME_HOURS,
        
        -- Percentile metrics for SLA tracking
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CASE WHEN IS_RESOLVED = 1 THEN RESOLUTION_TIME_HOURS END), 2) AS P75_RESOLUTION_TIME_HOURS,
        ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY CASE WHEN IS_RESOLVED = 1 THEN RESOLUTION_TIME_HOURS END), 2) AS P90_RESOLUTION_TIME_HOURS,
        ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY CASE WHEN IS_RESOLVED = 1 THEN RESOLUTION_TIME_HOURS END), 2) AS P95_RESOLUTION_TIME_HOURS,
        
        -- Resolution rate (percentage)
        ROUND(
            (COUNT(CASE WHEN IS_RESOLVED = 1 THEN 1 END) * 100.0) / 
            NULLIF(COUNT(*), 0), 
            2
        ) AS RESOLUTION_RATE_PCT,
        
        -- Same day resolution rate
        ROUND(
            (COUNT(CASE WHEN IS_SAME_DAY_RESOLUTION = 1 THEN 1 END) * 100.0) / 
            NULLIF(COUNT(CASE WHEN IS_RESOLVED = 1 THEN 1 END), 0), 
            2
        ) AS SAME_DAY_RESOLUTION_RATE_PCT,
        
        -- Unique counts
        COUNT(DISTINCT CUSTOMER_KEY) AS UNIQUE_CUSTOMERS,
        COUNT(DISTINCT AGENT_KEY) AS UNIQUE_AGENTS,
        
        -- Complaints per customer (indicates if same customers are complaining multiple times)
        ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT CUSTOMER_KEY), 0), 2) AS AVG_COMPLAINTS_PER_CUSTOMER,
        
        -- Audit columns
        MAX(DW_UPDATED_AT) AS SOURCE_UPDATED_AT,
        CURRENT_TIMESTAMP() AS DW_CREATED_AT
        
    FROM {{ ref('FACT_COMPLAINT') }}
    WHERE REQUEST_DATE IS NOT NULL
    {% if is_incremental() %}
        -- Only process dates that are new or updated
        AND REQUEST_DATE >= (SELECT DATEADD('day', -7, MAX(DATE)) FROM {{ this }})
    {% endif %}
    
    GROUP BY 
        REQUEST_DATE,
        COMPLAINT_CATEGORY,
        CHANNEL_TYPE
),

with_trends AS (
    SELECT
        *,
        
        -- Calculate moving averages (7-day)
        ROUND(AVG(TOTAL_COMPLAINTS) OVER (
            PARTITION BY COMPLAINT_CATEGORY, CHANNEL_TYPE 
            ORDER BY DATE 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2) AS TOTAL_COMPLAINTS_7DAY_MA,
        
        ROUND(AVG(RESOLUTION_RATE_PCT) OVER (
            PARTITION BY COMPLAINT_CATEGORY, CHANNEL_TYPE 
            ORDER BY DATE 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2) AS RESOLUTION_RATE_7DAY_MA,
        
        -- Day over day comparison
        LAG(TOTAL_COMPLAINTS, 1) OVER (
            PARTITION BY COMPLAINT_CATEGORY, CHANNEL_TYPE 
            ORDER BY DATE
        ) AS PREV_DAY_TOTAL_COMPLAINTS,
        
        TOTAL_COMPLAINTS - LAG(TOTAL_COMPLAINTS, 1) OVER (
            PARTITION BY COMPLAINT_CATEGORY, CHANNEL_TYPE 
            ORDER BY DATE
        ) AS DAY_OVER_DAY_CHANGE,
        
        -- Week over week comparison (same day previous week)
        LAG(TOTAL_COMPLAINTS, 7) OVER (
            PARTITION BY COMPLAINT_CATEGORY, CHANNEL_TYPE 
            ORDER BY DATE
        ) AS PREV_WEEK_TOTAL_COMPLAINTS,
        
        ROUND(
            (TOTAL_COMPLAINTS - LAG(TOTAL_COMPLAINTS, 7) OVER (
                PARTITION BY COMPLAINT_CATEGORY, CHANNEL_TYPE 
                ORDER BY DATE
            )) * 100.0 / 
            NULLIF(LAG(TOTAL_COMPLAINTS, 7) OVER (
                PARTITION BY COMPLAINT_CATEGORY, CHANNEL_TYPE 
                ORDER BY DATE
            ), 0),
            2
        ) AS WEEK_OVER_WEEK_CHANGE_PCT
        
    FROM daily_aggregates
)

SELECT * FROM with_trends
ORDER BY DATE DESC, COMPLAINT_CATEGORY, CHANNEL_TYPE