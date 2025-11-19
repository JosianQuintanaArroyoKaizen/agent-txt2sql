#!/bin/bash
# Automated Table Onboarding Script
# Usage: ./onboard-new-table.sh <csv_file> <table_name> <description_json>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
S3_DATA_BUCKET="${S3_DATA_BUCKET:-txt2sql-dev-data-bucket}"
DATABASE_NAME="${DATABASE_NAME:-txt2sql_dev_athena_db}"
AWS_REGION="${AWS_REGION:-us-west-2}"

# Help function
show_help() {
    cat << EOF
🚀 Automated Table Onboarding Script

USAGE:
    ./onboard-new-table.sh <csv_file> <table_name> <description_json>

ARGUMENTS:
    csv_file         Path to CSV file to upload
    table_name       Name for the table in Athena (e.g., sales_2024)
    description_json Path to JSON file with table/column descriptions

EXAMPLE:
    ./onboard-new-table.sh data/sales.csv sales_2024 metadata/sales_2024.json

DESCRIPTION JSON FORMAT:
    {
      "table_description": "Sales transactions for 2024",
      "common_queries": ["sales by region", "revenue trends"],
      "columns": {
        "sale_id": "Unique sale identifier",
        "customer_id": "Customer ID (FK to customers table)",
        "amount": "Sale amount in USD"
      }
    }

PREREQUISITES:
    - AWS CLI configured with appropriate credentials
    - S3 bucket exists: $S3_DATA_BUCKET
    - Glue database exists: $DATABASE_NAME
    - Python 3 with boto3 installed

EOF
}

# Check arguments
if [ "$#" -lt 3 ]; then
    show_help
    exit 1
fi

CSV_FILE="$1"
TABLE_NAME="$2"
DESCRIPTION_JSON="$3"

# Validate inputs
echo -e "${BLUE}🔍 Validating inputs...${NC}"

if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}❌ Error: CSV file not found: $CSV_FILE${NC}"
    exit 1
fi

if [ ! -f "$DESCRIPTION_JSON" ]; then
    echo -e "${RED}❌ Error: Description JSON not found: $DESCRIPTION_JSON${NC}"
    exit 1
fi

# Validate table name format
if ! [[ "$TABLE_NAME" =~ ^[a-z0-9_]+$ ]]; then
    echo -e "${RED}❌ Error: Table name must be lowercase letters, numbers, and underscores only${NC}"
    exit 1
fi

# Validate JSON format
if ! python3 -c "import json; json.load(open('$DESCRIPTION_JSON'))" 2>/dev/null; then
    echo -e "${RED}❌ Error: Invalid JSON format in $DESCRIPTION_JSON${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Input validation passed${NC}\n"

# Step 1: Upload CSV to S3
echo -e "${BLUE}📤 Step 1: Uploading CSV to S3...${NC}"
S3_PATH="s3://${S3_DATA_BUCKET}/data/${TABLE_NAME}/"

aws s3 cp "$CSV_FILE" "${S3_PATH}" --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ CSV uploaded to ${S3_PATH}${NC}\n"
else
    echo -e "${RED}❌ Failed to upload CSV${NC}"
    exit 1
fi

# Step 2: Run Glue Crawler
echo -e "${BLUE}🕷️  Step 2: Running Glue Crawler...${NC}"
CRAWLER_NAME="${TABLE_NAME}_crawler"

# Check if crawler exists, create if not
if ! aws glue get-crawler --name "$CRAWLER_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${YELLOW}Creating new crawler: $CRAWLER_NAME${NC}"
    
    python3 << PYTHON_SCRIPT
import boto3
import json

glue = boto3.client('glue', region_name='$AWS_REGION')

try:
    glue.create_crawler(
        Name='$CRAWLER_NAME',
        Role='AWSGlueServiceRole-txt2sql',  # Update with your Glue role
        DatabaseName='$DATABASE_NAME',
        Targets={
            'S3Targets': [
                {
                    'Path': '$S3_PATH'
                }
            ]
        },
        SchemaChangePolicy={
            'UpdateBehavior': 'UPDATE_IN_DATABASE',
            'DeleteBehavior': 'LOG'
        }
    )
    print("✅ Crawler created successfully")
except Exception as e:
    print(f"⚠️  Could not create crawler: {e}")
    print("Please create crawler manually or update role name in script")
PYTHON_SCRIPT
fi

# Start crawler
echo -e "${YELLOW}Starting crawler...${NC}"
aws glue start-crawler --name "$CRAWLER_NAME" --region "$AWS_REGION" 2>/dev/null || true

# Wait for crawler to complete
echo -e "${YELLOW}Waiting for crawler to complete (this may take 1-2 minutes)...${NC}"
sleep 10

for i in {1..30}; do
    CRAWLER_STATE=$(aws glue get-crawler --name "$CRAWLER_NAME" --region "$AWS_REGION" --query 'Crawler.State' --output text 2>/dev/null || echo "UNKNOWN")
    
    if [ "$CRAWLER_STATE" == "READY" ]; then
        echo -e "${GREEN}✅ Crawler completed successfully${NC}\n"
        break
    elif [ "$CRAWLER_STATE" == "RUNNING" ]; then
        echo -n "."
        sleep 10
    else
        echo -e "${YELLOW}⚠️  Crawler state: $CRAWLER_STATE${NC}"
        sleep 5
    fi
done

# Step 3: Add column descriptions to Glue
echo -e "${BLUE}📝 Step 3: Adding column descriptions to Glue Data Catalog...${NC}"

python3 << PYTHON_SCRIPT
import boto3
import json
import sys

glue = boto3.client('glue', region_name='$AWS_REGION')

# Load description JSON
with open('$DESCRIPTION_JSON', 'r') as f:
    metadata = json.load(f)

table_desc = metadata.get('table_description', '')
column_descriptions = metadata.get('columns', {})

try:
    # Get current table definition
    response = glue.get_table(
        DatabaseName='$DATABASE_NAME',
        Name='$TABLE_NAME'
    )
    
    table_input = response['Table']
    
    # Remove read-only fields
    for field in ['DatabaseName', 'CreateTime', 'UpdateTime', 'CreatedBy', 
                  'IsRegisteredWithLakeFormation', 'CatalogId', 'VersionId']:
        table_input.pop(field, None)
    
    # Update table description
    if table_desc:
        table_input['Description'] = table_desc
    
    # Update column descriptions
    updated_count = 0
    for column in table_input['StorageDescriptor']['Columns']:
        col_name_lower = column['Name'].lower()
        if col_name_lower in column_descriptions:
            column['Comment'] = column_descriptions[col_name_lower]
            updated_count += 1
            print(f"  ✓ {column['Name']}: {column['Comment'][:60]}...")
    
    # Update the table
    glue.update_table(
        DatabaseName='$DATABASE_NAME',
        TableInput=table_input
    )
    
    print(f"\n✅ Updated {updated_count} column descriptions")
    sys.exit(0)
    
except Exception as e:
    print(f"❌ Error updating Glue catalog: {e}")
    sys.exit(1)
PYTHON_SCRIPT

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to add column descriptions${NC}"
    exit 1
fi

echo ""

# Step 4: Update agent instructions
echo -e "${BLUE}📋 Step 4: Generating agent instruction snippet...${NC}"

AGENT_SNIPPET_FILE="${PROJECT_ROOT}/schema/agent-snippets/${TABLE_NAME}_snippet.txt"
mkdir -p "$(dirname "$AGENT_SNIPPET_FILE")"

python3 << PYTHON_SCRIPT
import json

with open('$DESCRIPTION_JSON', 'r') as f:
    metadata = json.load(f)

table_desc = metadata.get('table_description', '')
common_queries = metadata.get('common_queries', [])
columns = metadata.get('columns', {})

# Generate agent instruction snippet
snippet = f"""
### Table: $TABLE_NAME
{table_desc}

**Key Columns:**
"""

for col_name, col_desc in list(columns.items())[:20]:  # Top 20 columns
    snippet += f"- \`{col_name}\`: {col_desc}\n"

if len(columns) > 20:
    snippet += f"\n**Note:** Table has {len(columns)} total columns. Use DESCRIBE to see all columns.\n"

if common_queries:
    snippet += f"\n**Common Query Terms:** {', '.join(common_queries)}\n"

with open('$AGENT_SNIPPET_FILE', 'w') as f:
    f.write(snippet)

print(snippet)
PYTHON_SCRIPT

echo -e "\n${GREEN}✅ Agent snippet saved to: $AGENT_SNIPPET_FILE${NC}"
echo -e "${YELLOW}📝 Add this snippet to docs/enhanced-agent-instruction.txt${NC}\n"

# Step 5: Create test queries
echo -e "${BLUE}🧪 Step 5: Generating test queries...${NC}"

TEST_FILE="${PROJECT_ROOT}/tests/queries/${TABLE_NAME}_tests.sql"
mkdir -p "$(dirname "$TEST_FILE")"

cat > "$TEST_FILE" << SQL_TESTS
-- Test Queries for $TABLE_NAME
-- Generated: $(date)

-- Test 1: Count total records
SELECT COUNT(*) as total_records FROM $TABLE_NAME;

-- Test 2: Show sample records
SELECT * FROM $TABLE_NAME LIMIT 5;

-- Test 3: Describe table schema
DESCRIBE $TABLE_NAME;

-- Add more specific tests based on your table structure
SQL_TESTS

echo -e "${GREEN}✅ Test queries saved to: $TEST_FILE${NC}\n"

# Summary
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✨ Table Onboarding Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Table Name:${NC} $TABLE_NAME"
echo -e "${BLUE}S3 Location:${NC} $S3_PATH"
echo -e "${BLUE}Database:${NC} $DATABASE_NAME"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Review agent snippet: ${AGENT_SNIPPET_FILE}"
echo -e "2. Add snippet to: docs/enhanced-agent-instruction.txt"
echo -e "3. Test queries in Athena console: ${TEST_FILE}"
echo -e "4. Update and redeploy Bedrock agent with new instructions"
echo ""
echo -e "${BLUE}Verify in Athena:${NC}"
echo -e "   DESCRIBE $TABLE_NAME;"
echo ""
