# Dynamic Schema Retrieval - Lambda-Based Alternative

## Approach
Add a new action group function that returns schema information dynamically, avoiding Knowledge Base costs.

---

## Architecture

```
User: "Show me customer data"
        ↓
Agent: Calls getSchemaInfo("customer")
        ↓
Lambda: Returns customers table schema
        ↓
Agent: Generates SQL with correct columns
        ↓
Lambda: Executes query
```

---

## Implementation

### Step 1: Create Schema Storage

**File: `schema/table-schemas.json`**
```json
{
  "tables": {
    "txt2sql_dev_customers": {
      "description": "Customer account information",
      "columns": [
        {"name": "Cust_Id", "type": "INTEGER", "description": "Unique customer identifier"},
        {"name": "Customer", "type": "VARCHAR", "description": "Customer full name"},
        {"name": "Balance", "type": "INTEGER", "description": "Current balance in dollars"},
        {"name": "Past_Due", "type": "INTEGER", "description": "Past due amount in dollars"},
        {"name": "Vip", "type": "VARCHAR", "description": "VIP status (yes/no)"}
      ],
      "common_queries": [
        "VIP customers with high balances",
        "Customers with past due amounts"
      ]
    },
    "txt2sql_dev_procedures": {
      "description": "Medical procedures with pricing",
      "columns": [
        {"name": "Procedure_ID", "type": "VARCHAR", "description": "Unique identifier"},
        {"name": "Procedure", "type": "VARCHAR", "description": "Procedure name"},
        {"name": "Category", "type": "VARCHAR", "description": "Category type"},
        {"name": "Price", "type": "INTEGER", "description": "Price in dollars"},
        {"name": "Duration", "type": "INTEGER", "description": "Duration in minutes"},
        {"name": "Insurance", "type": "VARCHAR", "description": "Coverage (yes/no)"},
        {"name": "Customer_Id", "type": "INTEGER", "description": "FK to customers"}
      ]
    },
    "test_population": {
      "description": "EMIR derivatives trade data (7,867 rows, 200+ columns)",
      "note": "Only key columns listed - table has 200+ total columns",
      "important": "ALL columns are STRING type. NEVER use SELECT *. CAST numeric columns.",
      "key_columns": {
        "identifiers": [
          {"name": "uti_2_1", "type": "STRING", "description": "Unique Transaction Identifier"},
          {"name": "isin_2_7", "type": "STRING", "description": "ISIN code"}
        ],
        "dates": [
          {"name": "reporting_date_1_1", "type": "STRING", "description": "PRIMARY date - when reported (YYYY-MM-DD)"},
          {"name": "execution_date_2_42", "type": "STRING", "description": "When executed"},
          {"name": "valuation_date_2_23", "type": "STRING", "description": "Valuation date"}
        ],
        "financial": [
          {"name": "valuation_amount_2_21", "type": "STRING", "description": "Valuation amount (CAST to DOUBLE)"},
          {"name": "valuation_currency_2_22", "type": "STRING", "description": "Currency code"},
          {"name": "price_2_48", "type": "STRING", "description": "Trade price"}
        ],
        "classification": [
          {"name": "asset_class_2_11", "type": "STRING", "description": "Asset class"},
          {"name": "contract_type_2_10", "type": "STRING", "description": "Contract type"}
        ],
        "status": [
          {"name": "cleared_2_31", "type": "STRING", "description": "Cleared (Y/N)"},
          {"name": "direction_1_17", "type": "STRING", "description": "Trade direction"}
        ]
      }
    }
  },
  "query_hints": {
    "test_population": {
      "default_date": "reporting_date_1_1",
      "date_format": "YYYY-MM-DD",
      "numeric_cast": "Use CAST(column AS DOUBLE) for numeric operations",
      "avoid": "SELECT * returns 200+ columns - always specify needed columns"
    }
  }
}
```

### Step 2: Update Lambda Function

**File: `function/lambda_function.py`** - Add schema handler:

```python
import boto3
import json
from time import sleep
import os

athena_client = boto3.client('athena')
s3_client = boto3.client('s3')

# Cache for schema data
SCHEMA_CACHE = None

def load_schema_definitions():
    """Load schema definitions from S3 or local cache"""
    global SCHEMA_CACHE
    
    if SCHEMA_CACHE:
        return SCHEMA_CACHE
    
    try:
        # Try loading from S3 first
        bucket = os.environ.get('SCHEMA_BUCKET')
        key = 'table-schemas.json'
        
        if bucket:
            response = s3_client.get_object(Bucket=bucket, Key=key)
            SCHEMA_CACHE = json.loads(response['Body'].read())
        else:
            # Fallback to embedded schemas
            SCHEMA_CACHE = get_embedded_schemas()
            
        return SCHEMA_CACHE
    except Exception as e:
        print(f"Error loading schemas: {e}")
        return get_embedded_schemas()

def get_embedded_schemas():
    """Fallback embedded schema definitions"""
    return {
        "tables": {
            "txt2sql_dev_customers": {
                "columns": ["Cust_Id", "Customer", "Balance", "Past_Due", "Vip"],
                "description": "Customer accounts"
            },
            "txt2sql_dev_procedures": {
                "columns": ["Procedure_ID", "Procedure", "Category", "Price", "Duration", "Insurance", "Customer_Id"],
                "description": "Medical procedures"
            },
            "test_population": {
                "key_columns": {
                    "dates": ["reporting_date_1_1", "execution_date_2_42", "valuation_date_2_23"],
                    "financial": ["valuation_amount_2_21", "valuation_currency_2_22"],
                    "classification": ["asset_class_2_11", "contract_type_2_10"]
                },
                "description": "EMIR trade data (200+ columns)",
                "note": "All columns STRING type. Use CAST for numeric ops."
            }
        }
    }

def schema_info_handler(event):
    """Return schema information for requested tables"""
    
    # Extract table names from request
    properties = event['requestBody']['content']['application/json']['properties']
    table_param = next((p for p in properties if p['name'] == 'table_name'), None)
    
    table_name = table_param['value'] if table_param else None
    
    schemas = load_schema_definitions()
    
    if table_name and table_name in schemas['tables']:
        # Return specific table schema
        result = {
            'table': table_name,
            'schema': schemas['tables'][table_name]
        }
    else:
        # Return all table names and descriptions
        result = {
            'available_tables': {
                name: {"description": info.get('description', '')}
                for name, info in schemas['tables'].items()
            }
        }
    
    return result

def lambda_handler(event, context):
    print(event)
    
    api_path = event.get('apiPath')
    action_group = event.get('actionGroup')
    
    result = ''
    response_code = 200
    
    # Route to appropriate handler
    if api_path == '/athenaQuery':
        result = athena_query_handler(event)
    elif api_path == '/getSchemaInfo':
        result = schema_info_handler(event)
    else:
        response_code = 404
        result = {"error": f"Unrecognized api path: {action_group}::{api_path}"}
    
    response_body = {
        'application/json': {
            'body': result
        }
    }
    
    action_response = {
        'actionGroup': action_group,
        'apiPath': api_path,
        'httpMethod': event.get('httpMethod'),
        'httpStatusCode': response_code,
        'responseBody': response_body
    }
    
    return {'messageVersion': '1.0', 'response': action_response}

def athena_query_handler(event):
    """Existing athena query handler"""
    query = event['requestBody']['content']['application/json']['properties'][0]['value']
    
    if not query or query.strip() == '':
        return {
            'ResultSet': {
                'Rows': [
                    {'Data': [{'VarCharValue': 'Hello! I can help you query the database.'}]}
                ]
            }
        }
    
    print("Received QUERY:", query)
    
    s3_output = os.environ.get('S3Output', 's3://athena-destination-store-alias')
    database_name = os.environ.get('DatabaseName')
    
    execution_id = execute_athena_query(query, s3_output, database_name)
    result = get_query_results(execution_id)
    
    return result

def execute_athena_query(query, s3_output, database_name=None):
    query_execution_params = {
        'QueryString': query,
        'ResultConfiguration': {'OutputLocation': s3_output}
    }
    
    if database_name:
        query_execution_params['QueryExecutionContext'] = {'Database': database_name}
    
    response = athena_client.start_query_execution(**query_execution_params)
    return response['QueryExecutionId']

def check_query_status(execution_id):
    response = athena_client.get_query_execution(QueryExecutionId=execution_id)
    return response['QueryExecution']['Status']['State']

def get_query_results(execution_id):
    while True:
        status = check_query_status(execution_id)
        if status in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            break
        sleep(1)
    
    if status == 'SUCCEEDED':
        return athena_client.get_query_results(QueryExecutionId=execution_id)
    else:
        raise Exception(f"Query failed with status '{status}'")
```

### Step 3: Update OpenAPI Schema

**File: `schema/athena-schema.json`** - Add new endpoint:

```json
{
  "openapi": "3.0.1",
  "info": {
    "title": "AthenaQuery API",
    "description": "API for querying data from an Athena database with schema discovery",
    "version": "1.0.0"
  },
  "paths": {
    "/athenaQuery": {
      "post": {
        "description": "Execute a SQL query on an Athena database",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "Query": {
                    "type": "string",
                    "description": "SQL Query to execute"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Query results",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "ResultSet": {
                      "type": "array",
                      "description": "Query result rows"
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    "/getSchemaInfo": {
      "post": {
        "description": "Get schema information for database tables. Call this BEFORE generating SQL to understand available tables and columns.",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "table_name": {
                    "type": "string",
                    "description": "Name of the table to get schema for. If omitted, returns all available tables."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Schema information",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "table": {
                      "type": "string",
                      "description": "Table name"
                    },
                    "schema": {
                      "type": "object",
                      "description": "Table schema with columns and types"
                    },
                    "available_tables": {
                      "type": "object",
                      "description": "List of all available tables (when no specific table requested)"
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

### Step 4: Update Agent Instructions

Replace schema section with:

```
## DATABASE SCHEMA DISCOVERY

You have access to a `getSchemaInfo` function to discover table schemas dynamically.

**Workflow:**
1. When user asks about data, first call `getSchemaInfo()` to see available tables
2. If you need details about a specific table, call `getSchemaInfo(table_name="table_name")`
3. Use the returned schema to generate accurate SQL
4. Call `athenaQuery` with the SQL

**Example:**
User: "Show me customer data"
1. Call getSchemaInfo(table_name="txt2sql_dev_customers")
2. Review returned columns: Cust_Id, Customer, Balance, Past_Due, Vip
3. Generate: SELECT * FROM txt2sql_dev_customers LIMIT 10
4. Call athenaQuery with the SQL

**Important:**
- For test_population table: NEVER use SELECT * (200+ columns)
- All test_population columns are STRING type
- Default date field: reporting_date_1_1
```

---

## Benefits vs Knowledge Base

| Feature | Knowledge Base | Lambda Schema |
|---------|---------------|---------------|
| Cost | ~$45/month | ~$0 (included in Lambda) |
| Setup complexity | Medium | Low |
| Retrieval speed | Fast (parallel) | Fast (sub-100ms) |
| Semantic search | Yes | No |
| Schema updates | Update S3 | Update Lambda/S3 |
| Token efficiency | Best | Good |

**Use Lambda approach if:**
- Budget conscious
- Exact table names in queries
- Simpler setup preferred

**Use Knowledge Base if:**
- Need semantic search
- Fuzzy table/column matching
- Many related schemas
- Budget allows

---

## Testing

Test the schema endpoint:

```python
# Test getSchemaInfo in Lambda console
{
  "actionGroup": "QueryGroup",
  "apiPath": "/getSchemaInfo",
  "httpMethod": "POST",
  "requestBody": {
    "content": {
      "application/json": {
        "properties": [
          {"name": "table_name", "value": "txt2sql_dev_customers"}
        ]
      }
    }
  }
}
```

Expected response:
```json
{
  "table": "txt2sql_dev_customers",
  "schema": {
    "columns": ["Cust_Id", "Customer", "Balance", "Past_Due", "Vip"],
    "description": "Customer accounts"
  }
}
```
