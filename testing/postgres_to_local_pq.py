import logging

def postgres_to_s3_as_parquet(
    schema: str,
    table: str,
    bucket_name: str,
    s3_key: str,
    chunk_size: int = 10_000
):
    """
    Read a large table in chunks to avoid statement_timeout and save as parquet
    """

    import pandas as pd
    import awswrangler as wr

    sqlalchemy_url = "postgresql://postgres.tmcpekfedsyzscirxhyp:xzkM3JcIznixmlDX@aws-1-eu-west-1.pooler.supabase.com:6543/postgres"
    print(f"SQL Alchemy URI: {sqlalchemy_url}")
    engine = create_engine(sqlalchemy_url, connect_args={"options": "-c statement_timeout=300000"})

    s3_key = os.path.join("s3://", bucket_name, s3_key)

    filename = os.path.basename(s3_key)
    filename_without_ext, ext = os.path.splitext(filename)

    os.makedirs("/tmp/web_forms/", exist_ok=True)
    tmp_dir = tempfile.TemporaryDirectory(suffix=".parquet", prefix=f"/tmp/web_forms/{filename_without_ext}_", delete=False)

    logger.info(f"Reading {schema}.{table} in chunks of {chunk_size}")

    last_ctid = None
    
    i = 0

    while True:
        if last_ctid is None:
            sql = f"""
                SELECT ctid, * FROM {schema}.{table}
                ORDER BY ctid
                LIMIT {chunk_size}
            """
        else:
            sql = f"""
                SELECT ctid, * FROM {schema}.{table}
                WHERE ctid > '{last_ctid}'
                ORDER BY ctid
                LIMIT {chunk_size}
            """
        
        df_chunk = pd.read_sql(sql, engine)
        if df_chunk.empty:
            break
            
        last_ctid = df_chunk['ctid'].iloc[-1]
        # Drop ctid before returning
        df_chunk = df_chunk.drop(columns=['ctid'])
        df_chunk.to_parquet(os.path.join(tmp_dir, f"chunk_{i}.parquet"), index=False)
        i += 1
        logger.info(f"Fetched chunk ending at ctid={last_ctid}")
    
    return tmp_dir

postgres_to_s3_as_parquet(
    schema="customer_complaints",
    table="web_form_request_2025_11_20",
    bucket_name="coretelecoms-data-lake-capstone",
    s3_key=f"raw/website_forms/web_form_request_2025_11_20.parquet"
)
