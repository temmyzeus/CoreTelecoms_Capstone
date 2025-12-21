{{
    config(
        materialized='table',
        schema='GOLD',
        tags=['dimension', 'gold', 'customers']
    )
}}

WITH source_customers AS (
    SELECT 
        CUSTOMER_ID,
        NAME,
        GENDER,
        DATE_OF_BIRTH,
        SIGNUP_DATE,
        EMAIL,
        ADDRESS,
        LOAD_TIMESTAMP
    FROM {{ ref('CUSTOMERS_STG') }}
),

enriched_customers AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['CUSTOMER_ID']) }} AS CUSTOMER_KEY,
        
        -- Natural key
        CUSTOMER_ID,
        
        -- Customer attributes
        NAME,
        UPPER(GENDER) AS GENDER,
        
        -- Date attributes
        TRY_TO_DATE(DATE_OF_BIRTH, 'YYYY-MM-DD') AS DATE_OF_BIRTH,
        TRY_TO_DATE(SIGNUP_DATE, 'YYYY-MM-DD') AS SIGNUP_DATE,
        
        -- Derived attributes
        DATEDIFF('YEAR', TRY_TO_DATE(DATE_OF_BIRTH, 'YYYY-MM-DD'), CURRENT_DATE()) AS AGE,
        DATEDIFF('DAY', TRY_TO_DATE(SIGNUP_DATE, 'YYYY-MM-DD'), CURRENT_DATE()) AS CUSTOMER_TENURE_DAYS,
        
        -- Contact information
        LOWER(TRIM(EMAIL)) AS EMAIL,
        TRIM(ADDRESS) AS ADDRESS,
        
        -- Customer segmentation
        CASE 
            WHEN DATEDIFF('DAY', TRY_TO_DATE(SIGNUP_DATE, 'YYYY-MM-DD'), CURRENT_DATE()) < 90 THEN 'New'
            WHEN DATEDIFF('DAY', TRY_TO_DATE(SIGNUP_DATE, 'YYYY-MM-DD'), CURRENT_DATE()) BETWEEN 90 AND 365 THEN 'Regular'
            WHEN DATEDIFF('DAY', TRY_TO_DATE(SIGNUP_DATE, 'YYYY-MM-DD'), CURRENT_DATE()) > 365 THEN 'Loyal'
            ELSE 'Unknown'
        END AS CUSTOMER_SEGMENT,
        
        CASE 
            WHEN DATEDIFF('YEAR', TRY_TO_DATE(DATE_OF_BIRTH, 'YYYY-MM-DD'), CURRENT_DATE()) < 25 THEN '18-24'
            WHEN DATEDIFF('YEAR', TRY_TO_DATE(DATE_OF_BIRTH, 'YYYY-MM-DD'), CURRENT_DATE()) BETWEEN 25 AND 34 THEN '25-34'
            WHEN DATEDIFF('YEAR', TRY_TO_DATE(DATE_OF_BIRTH, 'YYYY-MM-DD'), CURRENT_DATE()) BETWEEN 35 AND 44 THEN '35-44'
            WHEN DATEDIFF('YEAR', TRY_TO_DATE(DATE_OF_BIRTH, 'YYYY-MM-DD'), CURRENT_DATE()) BETWEEN 45 AND 54 THEN '45-54'
            WHEN DATEDIFF('YEAR', TRY_TO_DATE(DATE_OF_BIRTH, 'YYYY-MM-DD'), CURRENT_DATE()) >= 55 THEN '55+'
            ELSE 'Unknown'
        END AS AGE_GROUP,
        
        -- Audit columns
        CURRENT_TIMESTAMP() AS DW_CREATED_AT,
        CURRENT_TIMESTAMP() AS DW_UPDATED_AT,
        LOAD_TIMESTAMP AS SOURCE_LOAD_TIMESTAMP
        
    FROM source_customers
    WHERE CUSTOMER_ID IS NOT NULL
)

SELECT * FROM enriched_customers