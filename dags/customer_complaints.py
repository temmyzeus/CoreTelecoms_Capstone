from airflow.sdk import dag, task, Variable
from airflow.providers.common.io.operators.file_transfer import FileTransferOperator
from airflow.providers.amazon.aws.transfers.google_api_to_s3 import GoogleApiToS3Operator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.providers.snowflake.transfers.copy_into_snowflake import CopyFromExternalStageToSnowflakeOperator
import pendulum

from Includes.file_utils import (
    download_file_from_s3_to_local,
    postgres_to_s3_as_parquet,
    upload_to_s3_as_parquet,
    upload_google_sheet_to_s3_as_parquet
)

SOURCE_S3_BUCKET: str = "core-telecoms-data-lake"
TARGET_S3_BUCKET: str = "coretelecoms-data-lake-capstone"
SNOWFLAKE_CONN_ID: str = "CORE_TELECOM_SNOWFLAKE_CONN"

default_args: dict = {
    "owner": "Temiloluwa Awoyele"
}

@dag(
    start_date=pendulum.datetime(2025, 11, 20, tz="UTC"),
    end_date=pendulum.datetime(2025, 11, 23, tz="UTC"),
    schedule="@daily",
    catchup=True,
    default_args=default_args,
    tags=[
        "core-telecoms", 
        "complaints-pipeline"
    ]
)
def customer_complaints_pipeline():
    """
    ### CoreTelecoms Unified Data Platform Pipeline
    """

    @task
    def fetch_customers_data_from_s3_to_local():
        """
        To Do: Add Task Document here
        """
        filename = download_file_from_s3_to_local(
            aws_conn_id="CDE_AWS_CONN",
            key="customers/customers_dataset.csv",
            bucket_name=SOURCE_S3_BUCKET
        )
        return filename

    @task
    def fetch_call_logs_from_s3_to_local(*, ds): # ds is required for templating in the key
        """
        To Do: Add Task Document here
        """
        filename = download_file_from_s3_to_local(
            aws_conn_id="CDE_AWS_CONN",
            key=f"call logs/call_logs_day_{ds}.csv",
            bucket_name=SOURCE_S3_BUCKET
        )
        return filename

    @task
    def fetch_social_media_from_s3_to_local(*, ds):
        """
        To Do: Add Task Document here
        """
        filename = download_file_from_s3_to_local(
            aws_conn_id="CDE_AWS_CONN",
            key=f"social_medias/media_complaint_day_{ds}.json",
            bucket_name=SOURCE_S3_BUCKET
        )
        return filename

    @task
    def upload_customers_parquet_to_s3(local_file_path: str):
        """
        To Do: Add Task Document here
        """
        data_return_value = upload_to_s3_as_parquet(
            aws_conn_id="CORE_TELECOM_AWS_CONN",
            local_file_path=local_file_path,
            bucket_name=TARGET_S3_BUCKET,
            s3_key="raw/customers/customers_dataset.parquet",
            mode="overwrite"
        )
        return data_return_value

    @task
    def upload_call_logs_parquet_to_s3(local_file_path: str, *, ds):
        """
        To Do: Add Task Document here
        """
        data_return_value = upload_to_s3_as_parquet(
            aws_conn_id="CORE_TELECOM_AWS_CONN",
            local_file_path=local_file_path,
            bucket_name=TARGET_S3_BUCKET,
            s3_key=f"raw/call_logs/call_logs_day_{ds}.parquet",
            mode="overwrite"
        )
        return data_return_value

    @task
    def upload_social_media_parquet_to_s3(local_file_path: str, *, ds):
        """
        To Do: Add Task Document here
        """
        data_return_value = upload_to_s3_as_parquet(
            aws_conn_id="CORE_TELECOM_AWS_CONN",
            local_file_path=local_file_path,
            bucket_name=TARGET_S3_BUCKET,
            s3_key=f"raw/social_medias/media_complaint_day_{ds}.parquet",
            is_json=True,
            mode="overwrite"
        )
        return data_return_value

    # AGENTS_GOOGLE_SHEET_ID = Variable.get("GOOGLE_SHEET_ID")

    # agents_data_to_s3 = GoogleApiToS3Operator(
    #     task_id="agents_data_google_sheets_to_s3",
    #     google_api_service_name="sheets",
    #     google_api_service_version="v4",
    #     google_api_endpoint_path="sheets.spreadsheets.values.get",
    #     google_api_endpoint_params={"spreadsheetId": AGENTS_GOOGLE_SHEET_ID, "range": "all"},
    #     s3_destination_key=f"s3://{S3_BUCKET}/agents.xlsx",
    #     aws_conn_id="CORE_TELECOM_AWS_CONN",
    #     gcp_conn_id="GOOGLE_SHEETS_API_CONN"
    # )

    @task
    def upload_agents_data_to_s3_as_parquet():
        """
        To Do: Add Task Document here
        """
        upload_google_sheet_to_s3_as_parquet(
            aws_conn_id="CORE_TELECOM_AWS_CONN",
            creds_file="core-telecoms-service.json",
            sheet_id="17IXo7TjDSSHaFobGG9hcqgbsNKTaqgyctWGnwDeNkIQ",
            sheet_title="agents",
            bucket_name=TARGET_S3_BUCKET,
            s3_key="raw/agents/agents.parquet",
            mode="overwrite"
        )

    @task
    def website_forms_postgres_to_s3_parquet():
        """
        To Do: Add Task Document here
        """
        postgres_to_s3_as_parquet(
            aws_conn_id="CORE_TELECOM_AWS_CONN",
            postgres_conn_id="CDE_CORE_TELECOM_POSTGRES_CONN",
            sql_query="SELECT * FROM postgres.customer_complaints.web_form_request_2025_11_20",
            bucket_name=S3_BUCKET,
            s3_key="website_forms/web_form_request_2025_11_20.parquet",
            mode="overwrite"
        )

    create_customers_landing_table = SQLExecuteQueryOperator(
        task_id="create_customers_landing_table",
        conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            CREATE OR REPLACE TABLE CUSTOMER_COMPLAINTS.BRONZE.CUSTOMERS
            COPY GRANTS
            USING TEMPLATE (
                SELECT
                    ARRAY_AGG(OBJECT_CONSTRUCT(*))
                    WITHIN GROUP (ORDER BY order_id)
                FROM TABLE(
                    INFER_SCHEMA(
                    LOCATION => '@CUSTOMER_COMPLAINTS.BRONZE.CORE_TELECOMS_CUSTOMERS'
                    , FILE_FORMAT => 'CUSTOMER_COMPLAINTS.BRONZE.BRONZE_PARQUET_FORMAT'
                    , IGNORE_CASE => TRUE
                    , MAX_FILE_COUNT => 1
                    , KIND => 'STANDARD'
                    )
                )
            );

        
            ALTER TABLE CUSTOMER_COMPLAINTS.BRONZE.CUSTOMERS
            ADD COLUMN IF NOT EXISTS dag_run_date DATE,
            IF NOT EXISTS load_timestamp TIMESTAMP_NTZ;
        """
    )

    create_call_logs_landing_table = SQLExecuteQueryOperator(
        task_id="create_call_logs_landing_table",
        conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            CREATE OR REPLACE TABLE CUSTOMER_COMPLAINTS.BRONZE.CALL_LOGS
            COPY GRANTS
            USING TEMPLATE (
                SELECT
                    ARRAY_AGG(OBJECT_CONSTRUCT(*))
                    WITHIN GROUP (ORDER BY order_id)
                FROM TABLE(
                    INFER_SCHEMA(
                    LOCATION => '@CUSTOMER_COMPLAINTS.BRONZE.CORE_TELECOMS_CALL_LOGS/call_logs_day_{{ ds }}.parquet'
                    , FILE_FORMAT => 'CUSTOMER_COMPLAINTS.BRONZE.BRONZE_PARQUET_FORMAT'
                    , IGNORE_CASE => TRUE
                    , MAX_FILE_COUNT => 1
                    , KIND => 'STANDARD'
                    )
                )
            );

            ALTER TABLE CUSTOMER_COMPLAINTS.BRONZE.CALL_LOGS
            ADD COLUMN IF NOT EXISTS dag_run_date DATE,
            IF NOT EXISTS load_timestamp TIMESTAMP_NTZ;
        """
    )

    create_social_media_landing_table = SQLExecuteQueryOperator(
        task_id="create_social_media_landing_table",
        conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            CREATE OR REPLACE TABLE CUSTOMER_COMPLAINTS.BRONZE.SOCIAL_MEDIA
            COPY GRANTS
            USING TEMPLATE (
                SELECT
                    ARRAY_AGG(OBJECT_CONSTRUCT(*))
                    WITHIN GROUP (ORDER BY order_id)
                FROM TABLE(
                    INFER_SCHEMA(
                    LOCATION => '@CUSTOMER_COMPLAINTS.BRONZE.CORE_TELECOMS_SOCIAL_MEDIA/media_complaint_day_{{ ds }}.parquet'
                    , FILE_FORMAT => 'CUSTOMER_COMPLAINTS.BRONZE.BRONZE_PARQUET_FORMAT'
                    , IGNORE_CASE => TRUE
                    , MAX_FILE_COUNT => 1
                    , KIND => 'STANDARD'
                    )
                )
            );

            ALTER TABLE CUSTOMER_COMPLAINTS.BRONZE.SOCIAL_MEDIA
            ADD COLUMN IF NOT EXISTS dag_run_date DATE,
            IF NOT EXISTS load_timestamp TIMESTAMP_NTZ;
        """
    )

    load_customers_data_to_snowflake = SQLExecuteQueryOperator(
        task_id="load_customers_data_to_snowflake",
        conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            INSERT INTO CUSTOMER_COMPLAINTS.BRONZE.CUSTOMERS
            SELECT
                $1:customer_id,
                $1:name,
                $1:Gender,
                $1:DATE_of_biRTH,
                $1:signup_date,
                $1:email,
                $1:address,
                '{{ ds }}' :: DATE,
                CURRENT_TIMESTAMP
            FROM @CUSTOMER_COMPLAINTS.BRONZE.CORE_TELECOMS_CUSTOMERS;
        """
    )

    load_call_logs_data_to_snowflake = SQLExecuteQueryOperator(
        task_id="load_call_logs_data_to_snowflake",
        conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            INSERT INTO CUSTOMER_COMPLAINTS.BRONZE.CALL_LOGS
            SELECT
                $1:"Unnamed:_0",
                $1:call_ID,
                $1:customeR_iD,
                $1:COMPLAINT_catego_ry,
                $1:agent_ID,
                $1:call_start_time,
                $1:call_end_time,
                $1:resolutionstatus,
                $1:callLogsGenerationDate,
                '{{ ds }}' :: DATE,
                CURRENT_TIMESTAMP
            FROM @CUSTOMER_COMPLAINTS.BRONZE.CORE_TELECOMS_CALL_LOGS/call_logs_day_{{ ds }}.parquet;
        """
    )

    load_social_media_data_to_snowflake = SQLExecuteQueryOperator(
        task_id="load_social_media_data_to_snowflake",
        conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            INSERT INTO CUSTOMER_COMPLAINTS.BRONZE.SOCIAL_MEDIA
            SELECT
                $1:complaint_id,
                $1:customeR_iD,
                $1:COMPLAINT_catego_ry,
                $1:agent_ID,
                $1:resolutionstatus,
                $1:request_date,
                $1:resolution_date,
                $1:media_channel,
                $1:MediaComplaintGenerationDate,
                '{{ ds }}' :: DATE,
                CURRENT_TIMESTAMP
            FROM @CUSTOMER_COMPLAINTS.BRONZE.CORE_TELECOMS_SOCIAL_MEDIA/media_complaint_day_{{ ds }}.parquet;
        """
    )

    customer_local_tmp_file = fetch_customers_data_from_s3_to_local()
    call_logs_local_tmp_file = fetch_call_logs_from_s3_to_local()
    social_media_local_tmp_file = fetch_social_media_from_s3_to_local()
    upload_agents_data_to_s3_as_parquet()
    # website_forms_postgres_to_s3_parquet()

    uploaded_customers_parquet = upload_customers_parquet_to_s3(customer_local_tmp_file)
    uploaded_call_logs_parquet = upload_call_logs_parquet_to_s3(call_logs_local_tmp_file)
    uploaded_social_media_parquet = upload_social_media_parquet_to_s3(social_media_local_tmp_file)

    uploaded_customers_parquet >> create_customers_landing_table >> load_customers_data_to_snowflake
    uploaded_call_logs_parquet >> create_call_logs_landing_table >> load_call_logs_data_to_snowflake
    uploaded_social_media_parquet >> create_social_media_landing_table >> load_social_media_data_to_snowflake
    # agents_data_to_s3

customer_complaints_pipeline()
