
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
    COMPLAINT_ID::VARCHAR(300) AS COMPLAINT_ID,
    CUSTOMER_ID::VARCHAR(300) AS CUSTOMER_ID,
    COMPLAINT_CATEGO_RY::VARCHAR(200) AS COMPLAINT_CATEGORY,
    AGENT_ID::VARCHAR(50) AS AGENT_ID,
    RESOLUTIONSTATUS::VARCHAR(50) AS RESOLUTION_STATUS,
    REQUEST_DATE::TIMESTAMP_NTZ AS REQUEST_TIMESTAMP,
    CASE
        WHEN TRIM(RESOLUTION_DATE) = '' THEN NULL
        ELSE TO_TIMESTAMP(RESOLUTION_DATE, 'yyyy-mm-dd hh24:mi:ss')
    END
    AS RESOLUTION_TIMESTAMP,
    MEDIA_CHANNEL::VARCHAR(100) AS MEDIA_CHANNEL,
    MEDIACOMPLAINTGENERATIONDATE::DATE AS MEDIA_COMPLAINT_GENERATION_DATE,
    DAG_RUN_DATE::DATE AS DAG_RUN_DATE,
    LOAD_TIMESTAMP::TIMESTAMP_NTZ AS LOAD_TIMESTAMP
FROM {{ ref('RAW_SOCIAL_MEDIA') }}
WHERE DAG_RUN_DATE = '{{ var("run_date") }}'

/*
    Uncomment the line below to remove records with null `id` values
*/

-- where id is not null
