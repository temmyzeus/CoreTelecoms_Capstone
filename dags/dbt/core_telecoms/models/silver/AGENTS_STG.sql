
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
    iD::INTEGER AS ID,
    NamE::VARCHAR AS NAME,
    experience::VARCHAR AS EXPERIENCE,
    state::VARCHAR AS STATE
FROM {{ ref('RAW_AGENTS') }}
WHERE DAG_RUN_DATE = '{{ var("run_date") }}'

/*
    Uncomment the line below to remove records with null `id` values
*/

-- where id is not null
