{{
    config(
        materialized='incremental',
        schema='gold',
        unique_key='COMPLAINT_KEY',
        tags=['fact', 'gold', 'complaints'],
        on_schema_change='append_new_columns'
    )
}}

WITH call_complaints AS (
    SELECT
        'CALL_' || CALL_ID AS COMPLAINT_KEY,
        CALL_ID AS SOURCE_ID,
        'CALL' AS CHANNEL_TYPE,
        CUSTOMER_ID,
        AGENT_ID,
        COMPLAINT_CATEGORY,
        RESOLUTION_STATUS,
        TRY_TO_TIMESTAMP(CALL_START_TIME) AS REQUEST_TIMESTAMP,
        TRY_TO_TIMESTAMP(CALL_END_TIME) AS RESOLUTION_TIMESTAMP,
        LOAD_TIMESTAMP AS SOURCE_LOAD_TIMESTAMP
    FROM {{ ref('CALL_LOGS_STG') }}
    WHERE CALL_ID IS NOT NULL
    {% if is_incremental() %}
        AND LOAD_TIMESTAMP > (SELECT MAX(SOURCE_LOAD_TIMESTAMP) FROM {{ this }})
    {% endif %}
),

media_complaints AS (
    SELECT
        'MEDIA_' || COMPLAINT_ID AS COMPLAINT_KEY,
        COMPLAINT_ID AS SOURCE_ID,
        COALESCE(MEDIA_CHANNEL, 'MEDIA') AS CHANNEL_TYPE,
        CUSTOMER_ID,
        AGENT_ID,
        COMPLAINT_CATEGORY,
        RESOLUTION_STATUS,
        TRY_TO_TIMESTAMP(REQUEST_DATE) AS REQUEST_TIMESTAMP,
        TRY_TO_TIMESTAMP(RESOLUTION_DATE) AS RESOLUTION_TIMESTAMP,
        LOAD_TIMESTAMP AS SOURCE_LOAD_TIMESTAMP
    FROM {{ ref('SOCIAL_MEDIA_STG') }}
    WHERE COMPLAINT_ID IS NOT NULL
    {% if is_incremental() %}
        AND LOAD_TIMESTAMP > (SELECT MAX(SOURCE_LOAD_TIMESTAMP) FROM {{ this }})
    {% endif %}
),

web_complaints AS (
    SELECT
        'WEB_' || REQUEST_ID AS COMPLAINT_KEY,
        REQUEST_ID AS SOURCE_ID,
        'WEB' AS CHANNEL_TYPE,
        CUSTOMER_ID,
        AGENT_ID,
        COMPLAINT_CATEGORY,
        RESOLUTION_STATUS,
        TRY_TO_TIMESTAMP(REQUEST_DATE) AS REQUEST_TIMESTAMP,
        TRY_TO_TIMESTAMP(RESOLUTION_DATE) AS RESOLUTION_TIMESTAMP,
        LOAD_TIMESTAMP AS SOURCE_LOAD_TIMESTAMP
    FROM {{ ref('WEBFORMS_STG') }}
    WHERE REQUEST_ID IS NOT NULL
    {% if is_incremental() %}
        AND LOAD_TIMESTAMP > (SELECT MAX(SOURCE_LOAD_TIMESTAMP) FROM {{ this }})
    {% endif %}
),

all_complaints AS (
    SELECT * FROM call_complaints
    UNION ALL
    SELECT * FROM media_complaints
    UNION ALL
    SELECT * FROM web_complaints
),

fact_complaints AS (
    SELECT
        -- Primary Key
        c.COMPLAINT_KEY,
        
        -- Foreign Keys
        {{ dbt_utils.generate_surrogate_key(['c.CUSTOMER_ID']) }} AS CUSTOMER_KEY,
        {{ dbt_utils.generate_surrogate_key(['c.AGENT_ID']) }} AS AGENT_KEY,
        TO_NUMBER(TO_CHAR(c.REQUEST_TIMESTAMP, 'YYYYMMDD')) AS DATE_KEY,
        
        -- Degenerate dimensions (attributes that don't warrant separate dimension tables)
        c.SOURCE_ID,
        c.CHANNEL_TYPE,
        c.COMPLAINT_CATEGORY,
        c.RESOLUTION_STATUS,
        
        -- Timestamps
        c.REQUEST_TIMESTAMP,
        c.RESOLUTION_TIMESTAMP,
        DATE(c.REQUEST_TIMESTAMP) AS REQUEST_DATE,
        DATE(c.RESOLUTION_TIMESTAMP) AS RESOLUTION_DATE,
        
        -- Derived measures
        CASE 
            WHEN c.RESOLUTION_TIMESTAMP IS NOT NULL 
            THEN DATEDIFF('HOUR', c.REQUEST_TIMESTAMP, c.RESOLUTION_TIMESTAMP)
            ELSE NULL
        END AS RESOLUTION_TIME_HOURS,
        
        CASE 
            WHEN c.RESOLUTION_TIMESTAMP IS NOT NULL 
            THEN DATEDIFF('DAY', c.REQUEST_TIMESTAMP, c.RESOLUTION_TIMESTAMP)
            ELSE NULL
        END AS RESOLUTION_TIME_DAYS,
        
        CASE 
            WHEN c.RESOLUTION_STATUS = 'Resolved' 
            AND DATE(c.REQUEST_TIMESTAMP) = DATE(c.RESOLUTION_TIMESTAMP)
            THEN 1 
            ELSE 0 
        END AS IS_SAME_DAY_RESOLUTION,
        
        CASE 
            WHEN c.RESOLUTION_STATUS = 'Resolved' THEN 1 
            ELSE 0 
        END AS IS_RESOLVED,
        
        CASE 
            WHEN c.RESOLUTION_STATUS = 'Pending' THEN 1 
            ELSE 0 
        END AS IS_PENDING,
        
        CASE 
            WHEN c.RESOLUTION_STATUS = 'Rejected' THEN 1 
            ELSE 0 
        END AS IS_REJECTED,
        
        -- Time buckets for resolution time analysis
        CASE 
            WHEN DATEDIFF('HOUR', c.REQUEST_TIMESTAMP, c.RESOLUTION_TIMESTAMP) <= 24 THEN '0-24 hours'
            WHEN DATEDIFF('HOUR', c.REQUEST_TIMESTAMP, c.RESOLUTION_TIMESTAMP) <= 72 THEN '24-72 hours'
            WHEN DATEDIFF('HOUR', c.REQUEST_TIMESTAMP, c.RESOLUTION_TIMESTAMP) <= 168 THEN '3-7 days'
            WHEN DATEDIFF('HOUR', c.REQUEST_TIMESTAMP, c.RESOLUTION_TIMESTAMP) > 168 THEN '7+ days'
            ELSE 'Unresolved'
        END AS RESOLUTION_TIME_BUCKET,
        
        -- Audit columns
        c.SOURCE_LOAD_TIMESTAMP,
        CURRENT_TIMESTAMP() AS DW_CREATED_AT,
        CURRENT_TIMESTAMP() AS DW_UPDATED_AT
        
    FROM all_complaints c
)

SELECT * FROM fact_complaints