
/*
    Welcome to your first dbt model!
    Did you know that you can also configure models directly within SQL files?
    This will override configurations stated in dbt_project.yml

    Try changing "table" to "view" below
*/

{{ config(
    materialized='incremental'
) }}

SELECT
    CALL_ID::VARCHAR(100) AS CALL_ID,
    CUSTOMER_ID::VARCHAR(100) AS CUSTOMER_ID,
    COMPLAINT_CATEGO_RY::VARCHAR(50) AS COMPLAINT_CATEGORY,
    AGENT_ID::INTEGER AS AGENT_ID,
    CALL_START_TIME::TIMESTAMP_NTZ AS CALL_START_TIMESTAMP,
    CALL_END_TIME::TIMESTAMP_NTZ AS CALL_END_TIMESTAMP,
    RESOLUTIONSTATUS::VARCHAR(50) AS RESOLUTION_STATUS,
    CALLLOGSGENERATIONDATE::DATE AS CALL_LOGS_GENERATION_DATE,
    DAG_RUN_DATE::DATE AS DAG_RUN_DATE,
    LOAD_TIMESTAMP::TIMESTAMP_NTZ AS LOAD_TIMESTAMP
FROM {{ ref('RAW_CALL_LOGS') }}
WHERE DAG_RUN_DATE = '{{ var("run_date") }}'

/*
    Uncomment the line below to remove records with null `id` values
*/

-- where id is not null
