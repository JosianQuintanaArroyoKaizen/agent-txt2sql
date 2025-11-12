#!/usr/bin/env python3

r"""Utility script to load a local CSV into the Bedrock Text2SQL data lake.

Steps performed:
1. Read the local CSV header and build sanitized column names that are safe for Athena.
2. Upload the CSV to the configured S3 data bucket under a deterministic prefix.
3. Execute Athena DDL statements to create the database (if needed),
   create an external table, and optionally a view with the original column names.

Requirements:
- boto3 installed and AWS credentials configured in your environment.
- The Athena workgroup must allow the supplied output location.

Example usage:

    ./scripts/ingest_csv_to_athena.py \
        --csv-path /home/jquintana-arroyo/git/agent-txt2sql/0103a_0103a_Test\
 Population_(C)_PR_2024-11-29\ to\ 2024-11-30_Consolidated\ Errors\ Data_1\ OF\ 1.csv \
        --bucket sl-data-store-txt2sql-dev-123456789012-us-west-2 \
        --athena-output s3://sl-athena-output-txt2sql-dev-123456789012-us-west-2/ \
        --database txt2sql_dev_athena_db \
        --table-name test_population \
        --region us-west-2

"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import time
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

import boto3
from botocore.exceptions import ClientError


def sanitize_identifier(raw: str) -> str:
    """Return a lowercase identifier safe for Athena table/column names."""

    candidate = re.sub(r"[^0-9a-zA-Z_]", "_", raw)
    candidate = re.sub(r"_+", "_", candidate).strip("_")
    candidate = candidate.lower()
    if not candidate:
        candidate = "col"
    if candidate[0].isdigit():
        candidate = f"col_{candidate}"
    return candidate


def unique_identifiers(headers: Iterable[str]) -> List[Tuple[str, str]]:
    """Generate unique sanitized identifiers preserving the original order."""

    used: Dict[str, int] = {}
    result: List[Tuple[str, str]] = []

    for original in headers:
        base = sanitize_identifier(original)
        counter = used.get(base, 0)
        if counter:
            # Increment suffix until unique
            while True:
                counter += 1
                candidate = f"{base}_{counter}"
                if candidate not in used:
                    break
        else:
            candidate = base
            counter = 1

        used[base] = counter
        used[candidate] = 1
        result.append((candidate, original))

    return result


def read_csv_header(csv_path: Path, delimiter: str) -> List[str]:
    with csv_path.open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.reader(fh, delimiter=delimiter)
        try:
            return next(reader)
        except StopIteration as exc:
            raise ValueError(f"CSV file {csv_path} is empty") from exc


def build_create_table_sql(
    database: str,
    table_name: str,
    column_pairs: List[Tuple[str, str]],
    s3_location: str,
    delimiter: str,
    quote_char: str,
) -> str:
    column_lines = [f"  {safe} STRING" for safe, _ in column_pairs]
    columns_block = ",\n".join(column_lines)

    return (
        f"CREATE EXTERNAL TABLE IF NOT EXISTS {database}.{table_name} (\n"
        f"{columns_block}\n"
        ")\n"
        "ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'\n"
        "WITH SERDEPROPERTIES (\n"
        f"  'separatorChar' = '{delimiter}',\n"
        f"  'quoteChar' = '{quote_char}'\n"
        ")\n"
        "STORED AS TEXTFILE\n"
        f"LOCATION '{s3_location}'\n"
        "TBLPROPERTIES ('skip.header.line.count'='1');"
    )


def build_view_sql(
    database: str,
    table_name: str,
    column_pairs: List[Tuple[str, str]],
    view_suffix: str,
) -> str:
    select_lines = [f'  "{safe}" AS "{original}"' for safe, original in column_pairs]
    select_block = ",\n".join(select_lines)
    view_name = f"{table_name}_{view_suffix}"
    return (
        f"CREATE OR REPLACE VIEW {database}.{view_name} AS\n"
        "SELECT\n"
        f"{select_block}\n"
        f"FROM {database}.{table_name};"
    )


def upload_to_s3(
    s3_client,
    bucket: str,
    key: str,
    local_path: Path,
) -> None:
    try:
        s3_client.upload_file(str(local_path), bucket, key)
    except ClientError as exc:
        raise RuntimeError(f"Failed to upload to s3://{bucket}/{key}: {exc}") from exc


def run_athena_query(
    athena_client,
    query: str,
    output_location: str,
    database: str | None = None,
    poll_interval: float = 2.0,
    timeout: float = 300.0,
) -> None:
    params = {
        "QueryString": query,
        "ResultConfiguration": {"OutputLocation": output_location},
    }
    if database:
        params["QueryExecutionContext"] = {"Database": database}

    try:
        execution = athena_client.start_query_execution(**params)
    except ClientError as exc:
        raise RuntimeError(f"Failed to start Athena query: {exc}") from exc

    execution_id = execution["QueryExecutionId"]
    start_time = time.time()

    while True:
        try:
            status = athena_client.get_query_execution(QueryExecutionId=execution_id)
        except ClientError as exc:
            raise RuntimeError(f"Failed to fetch Athena query status: {exc}") from exc

        state = status["QueryExecution"]["Status"]["State"]
        if state in {"SUCCEEDED", "FAILED", "CANCELLED"}:
            if state != "SUCCEEDED":
                details = status["QueryExecution"]["Status"].get("StateChangeReason", "")
                raise RuntimeError(f"Athena query ended with state {state}: {details}")
            return

        if time.time() - start_time > timeout:
            raise TimeoutError(
                f"Athena query {execution_id} did not finish within {timeout} seconds"
            )

        time.sleep(poll_interval)


def dump_column_map(column_pairs: List[Tuple[str, str]], destination: Path) -> None:
    mapping = {safe: original for safe, original in column_pairs}
    destination.write_text(json.dumps(mapping, indent=2), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv-path", required=True, type=Path, help="Path to local CSV file")
    parser.add_argument("--bucket", required=True, help="Target S3 bucket for data upload")
    parser.add_argument(
        "--prefix",
        default="custom",
        help="Optional S3 prefix (folder) to place the file under",
    )
    parser.add_argument(
        "--table-name",
        default=None,
        help="Name for the Athena table (sanitized automatically if omitted)",
    )
    parser.add_argument(
        "--database",
        default="athena_db",
        help="Athena database to use / create",
    )
    parser.add_argument(
        "--athena-output",
        required=True,
        help="S3 location (s3://bucket/prefix/) for Athena query results",
    )
    parser.add_argument("--region", default=None, help="AWS region (defaults to AWS config)")
    parser.add_argument(
        "--delimiter",
        default=",",
        help="CSV delimiter (default ',')",
    )
    parser.add_argument(
        "--quote-char",
        default="\"",
        help='CSV quote character (default "\"")',
    )
    parser.add_argument(
        "--create-view",
        action="store_true",
        help="Create a companion view exposing the original column names",
    )
    parser.add_argument(
        "--view-suffix",
        default="view",
        help="Suffix appended to the table name when creating the view",
    )
    parser.add_argument(
        "--column-map-output",
        type=Path,
        default=None,
        help="Optional path to save the sanitized-to-original column mapping as JSON",
    )
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Skip uploading to S3 (useful if file already present)",
    )
    parser.add_argument(
        "--skip-ddl",
        action="store_true",
        help="Skip executing Athena DDL statements",
    )
    return parser.parse_args()


def ingest_csv(
    *,
    csv_path: Path,
    bucket: str,
    prefix: str,
    table_name: str | None,
    database: str,
    athena_output: str,
    region: str | None = None,
    delimiter: str = ",",
    quote_char: str = "\"",
    create_view: bool = False,
    view_suffix: str = "view",
    column_map_output: Path | None = None,
    skip_upload: bool = False,
    skip_ddl: bool = False,
) -> Dict[str, str | int | None]:
    csv_path = Path(csv_path).expanduser().resolve()
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    headers = read_csv_header(csv_path, delimiter)
    column_pairs = unique_identifiers(headers)

    sanitized_table = sanitize_identifier(table_name if table_name else csv_path.stem)
    sanitized_filename = f"{sanitize_identifier(csv_path.stem)}.csv"

    prefix = prefix or ""
    prefix_clean = prefix.strip("/")
    folder_parts = [p for p in [prefix_clean, sanitized_table] if p]
    data_prefix = "/".join(folder_parts)
    s3_key = "/".join(folder_parts + [sanitized_filename]) if folder_parts else sanitized_filename
    if data_prefix:
        s3_location = f"s3://{bucket}/{data_prefix}/"
    else:
        s3_location = f"s3://{bucket}/"

    session_kwargs = {}
    if region:
        session_kwargs["region_name"] = region

    session = boto3.Session(**session_kwargs)
    s3_client = session.client("s3")
    athena_client = session.client("athena")

    if not skip_upload:
        print(f"Uploading {csv_path} to s3://{bucket}/{s3_key} ...")
        upload_to_s3(s3_client, bucket, s3_key, csv_path)
    else:
        print("Skipping S3 upload as requested")

    if not skip_ddl:
        print(f"Ensuring database {database} exists ...")
        run_athena_query(
            athena_client,
            f"CREATE DATABASE IF NOT EXISTS {database};",
            athena_output,
        )

        print(f"Creating external table {database}.{sanitized_table} ...")
        ddl = build_create_table_sql(
            database=database,
            table_name=sanitized_table,
            column_pairs=column_pairs,
            s3_location=s3_location,
            delimiter=delimiter,
            quote_char=quote_char,
        )
        run_athena_query(
            athena_client,
            ddl,
            athena_output,
            database=database,
        )

        if create_view:
            view_sql = build_view_sql(
                database=database,
                table_name=sanitized_table,
                column_pairs=column_pairs,
                view_suffix=view_suffix,
            )
            print(
                f"Creating view {database}.{sanitized_table}_{view_suffix} with original column names ..."
            )
            run_athena_query(
                athena_client,
                view_sql,
                athena_output,
                database=database,
            )
    else:
        print("Skipping Athena DDL execution as requested")

    if column_map_output:
        column_map_output = column_map_output.expanduser().resolve()
        column_map_output.parent.mkdir(parents=True, exist_ok=True)
        dump_column_map(column_pairs, column_map_output)
        print(f"Column mapping written to {column_map_output}")

    summary: Dict[str, str | int | None] = {
        "table": f"{database}.{sanitized_table}",
        "view": f"{database}.{sanitized_table}_{view_suffix}" if create_view else None,
        "s3_location": s3_location,
        "s3_key": s3_key,
        "athena_output": athena_output,
        "total_columns": len(column_pairs),
        "column_map_path": str(column_map_output) if column_map_output else None,
        "upload_performed": "no" if skip_upload else "yes",
        "ddl_executed": "no" if skip_ddl else "yes",
    }
    return summary


def main() -> None:
    args = parse_args()

    summary = ingest_csv(
        csv_path=args.csv_path,
        bucket=args.bucket,
        prefix=args.prefix,
        table_name=args.table_name,
        database=args.database,
        athena_output=args.athena_output,
        region=args.region,
        delimiter=args.delimiter,
        quote_char=args.quote_char,
        create_view=args.create_view,
        view_suffix=args.view_suffix,
        column_map_output=args.column_map_output,
        skip_upload=args.skip_upload,
        skip_ddl=args.skip_ddl,
    )

    print("\nIngestion complete. Summary:")
    print(f"  Table: {summary['table']}")
    if summary.get("view"):
        print(f"  View: {summary['view']}")
    print(f"  S3 data location: {summary['s3_location']}")
    print(f"  Athena output location: {summary['athena_output']}")
    print(f"  Total columns: {summary['total_columns']}")
    if summary.get("column_map_path"):
        print(f"  Column map: {summary['column_map_path']}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("Aborted by user")

