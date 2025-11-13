#!/usr/bin/env python3
"""Generate the EMIR table schema for Bedrock agent orchestration prompt."""

import json
from pathlib import Path

# Based on the ingestion config
DATABASE = "txt2sql_dev_athena_db"
TABLE_NAME = "test_population"  # or "test_population_view" if views were created
S3_BUCKET = "sl-data-store-txt2sql-dev-194561596031-eu-central-1"
S3_PREFIX = "custom/test_population"
REGION = "eu-central-1"

# Read the column mapping
COLUMN_MAP_PATH = Path(__file__).parent.parent / "schema" / "column-maps" / "test_population.json"

def generate_schema():
    """Generate the CREATE TABLE statement for the EMIR dataset."""
    
    # Read column mapping
    with open(COLUMN_MAP_PATH, 'r') as f:
        column_map = json.load(f)
    
    # Generate column definitions (all STRING type as per ingestion script)
    columns = []
    for sanitized_name in sorted(column_map.keys()):
        columns.append(f"  `{sanitized_name}` STRING")
    
    columns_block = ",\n".join(columns)
    s3_location = f"s3://{S3_BUCKET}/{S3_PREFIX}/"
    
    create_statement = (
        f"CREATE EXTERNAL TABLE {DATABASE}.{TABLE_NAME} (\n"
        f"{columns_block}\n"
        ")\n"
        "ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'\n"
        "WITH SERDEPROPERTIES (\n"
        "  'separatorChar' = ',',\n"
        "  'quoteChar' = '\"'\n"
        ")\n"
        "STORED AS TEXTFILE\n"
        f"LOCATION '{s3_location}'\n"
        "TBLPROPERTIES ('skip.header.line.count'='1');"
    )
    
    return create_statement


def main():
    schema = generate_schema()
    
    print("="*80)
    print("EMIR TABLE SCHEMA FOR BEDROCK AGENT")
    print("="*80)
    print()
    print("XML FORMAT (copy this into Bedrock agent orchestration prompt):")
    print()
    print(f"<athena_schema>")
    print(schema)
    print(f"</athena_schema>")
    print()
    print("="*80)
    print()
    print("NOTE: If you created a view, use 'test_population_view' instead of 'test_population'")
    print("="*80)


if __name__ == "__main__":
    main()

