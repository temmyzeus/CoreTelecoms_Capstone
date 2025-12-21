
/*
    Welcome to your first dbt model!
    Did you know that you can also configure models directly within SQL files?
    This will override configurations stated in dbt_project.yml

    Try changing "table" to "view" below
*/

{{ config(
    materialized='table'
) }}

SELECT
    CUSTOMER_ID::VARCHAR(100) AS CUSTOMER_ID,
    NAME::VARCHAR(500) AS NAME,
    GENDER::CHAR(1) AS GENDER,
    DATE_OF_BIRTH::DATE AS DATE_OF_BIRTH,
    SIGNUP_DATE::DATE AS SIGNUP_DATE,
    EMAIL::VARCHAR(200) AS EMAIL,
    ADDRESS::TEXT AS ADDRESS,
    DAG_RUN_DATE::DATE AS DAG_RUN_DATE,
    LOAD_TIMESTAMP::TIMESTAMP_NTZ AS LOAD_TIMESTAMP
FROM CUSTOMER_COMPLAINTS.BRONZE.CUSTOMERS

/*
    Uncomment the line below to remove records with null `id` values
*/

-- where id is not null
