#!/usr/bin/env python3
"""Get the schema of an Athena table and format it for Bedrock agent orchestration prompt."""

import argparse
import boto3
from botocore.exceptions import ClientError


def get_table_schema(athena_client, database: str, table_name: str, athena_output: str) -> str:
    """Get the CREATE TABLE statement for an existing Athena table."""
    
    # First, describe the table to get column information
    describe_query = f"DESCRIBE {database}.{table_name}"
    
    print(f"Executing: {describe_query}")
    
    # Execute the describe query
    response = athena_client.start_query_execution(
        QueryString=describe_query,
        ResultConfiguration={'OutputLocation': athena_output},
        QueryExecutionContext={'Database': database}
    )
    
    execution_id = response['QueryExecutionId']
    print(f"Query execution ID: {execution_id}")
    
    # Wait for query to complete
    import time
    while True:
        status_response = athena_client.get_query_execution(QueryExecutionId=execution_id)
        status = status_response['QueryExecution']['Status']['State']
        if status in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            break
        time.sleep(1)
    
    if status != 'SUCCEEDED':
        raise Exception(f"Query failed with status: {status}")
    
    # Get results
    results = athena_client.get_query_results(QueryExecutionId=execution_id)
    
    # Parse column information
    columns = []
    for row in results['ResultSet']['Rows'][1:]:  # Skip header
        if len(row['Data']) >= 2:
            col_name = row['Data'][0].get('VarCharValue', '').strip()
            col_type = row['Data'][1].get('VarCharValue', '').strip()
            if col_name and col_type:
                columns.append(f"  `{col_name}` {col_type}")
    
    # Get table location
    show_create_query = f"SHOW CREATE TABLE {database}.{table_name}"
    show_response = athena_client.start_query_execution(
        QueryString=show_create_query,
        ResultConfiguration={'OutputLocation': athena_output},
        QueryExecutionContext={'Database': database}
    )
    
    show_execution_id = show_response['QueryExecutionId']
    while True:
        show_status_response = athena_client.get_query_execution(QueryExecutionId=show_execution_id)
        show_status = show_status_response['QueryExecution']['Status']['State']
        if show_status in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            break
        time.sleep(1)
    
    location = None
    if show_status == 'SUCCEEDED':
        show_results = athena_client.get_query_results(QueryExecutionId=show_execution_id)
        for row in show_results['ResultSet']['Rows']:
            for data in row.get('Data', []):
                value = data.get('VarCharValue', '')
                if 'LOCATION' in value.upper():
                    # Extract location
                    import re
                    match = re.search(r"LOCATION\s+['\"]([^'\"]+)['\"]", value, re.IGNORECASE)
                    if match:
                        location = match.group(1)
    
    # Build CREATE TABLE statement
    columns_block = ",\n".join(columns)
    
    create_statement = (
        f"CREATE EXTERNAL TABLE {database}.{table_name} (\n"
        f"{columns_block}\n"
        ")"
    )
    
    if location:
        create_statement += f"\nLOCATION '{location}'"
    
    return create_statement


def main():
    parser = argparse.ArgumentParser(description="Get Athena table schema for Bedrock agent")
    parser.add_argument("--database", required=True, help="Athena database name")
    parser.add_argument("--table", required=True, help="Table name")
    parser.add_argument("--athena-output", required=True, help="S3 path for Athena query results")
    parser.add_argument("--region", default="eu-central-1", help="AWS region")
    
    args = parser.parse_args()
    
    athena_client = boto3.client('athena', region_name=args.region)
    
    try:
        schema = get_table_schema(athena_client, args.database, args.table, args.athena_output)
        print("\n" + "="*80)
        print("TABLE SCHEMA FOR BEDROCK AGENT:")
        print("="*80)
        print(schema)
        print("="*80)
        
        # Also output in XML format for easy copy-paste
        print("\n" + "="*80)
        print("XML FORMAT (for Bedrock agent orchestration prompt):")
        print("="*80)
        print(f"<athena_schema>\n{schema}\n</athena_schema>")
        print("="*80)
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())

