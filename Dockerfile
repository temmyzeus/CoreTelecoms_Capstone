ARG AIRFLOW_IMAGE_NAME=apache/airflow:${AIRFLOW_IMAGE_VERSION:-3.0.6}

FROM ${AIRFLOW_IMAGE_NAME}

RUN pip install --no-cache-dir \
    awswrangler==3.14.0 \
    gspread==0.0.1 \
    oauth2client==4.1.3 \
    apache-airflow-providers-snowflake==6.5.4 \
    apache-airflow-providers-dbt-cloud==4.6.0

RUN python -m venv dbt_venv && source dbt_venv/bin/activate && \
    pip install --no-cache-dir dbt-snowflake && deactivate

RUN pip install --no-cache-dir astronomer-cosmos

USER root

RUN chmod 777 -R "$AIRFLOW_HOME/dbt_venv" "/tmp/.cache"

USER airflow
