# Automated Table Onboarding - Quick Start Guide

## Overview

This guide shows you how to automatically add new CSV datasets to your text-to-SQL system with proper schema descriptions.

---

## Prerequisites

✅ AWS CLI configured with credentials  
✅ Python 3 with boto3 installed  
✅ S3 bucket for data storage  
✅ AWS Glue database created  
✅ Proper IAM permissions (S3, Glue, Athena)

---

## One-Command Setup

### Quick Onboard (3 Steps)

```bash
# 1. Generate metadata from your CSV (auto-creates descriptions)
python scripts/generate-table-metadata.py data/your_file.csv --table-name your_table > metadata/your_table.json

# 2. Review and improve the generated metadata
nano metadata/your_table.json  # Edit descriptions to be more accurate

# 3. Run the automated onboarding
./scripts/onboard-new-table.sh data/your_file.csv your_table metadata/your_table.json
```

That's it! Your table is now:
- ✅ Uploaded to S3
- ✅ Cataloged in Glue with descriptions
- ✅ Ready for agent queries
- ✅ Has generated test queries

---

## Detailed Workflow

### Step 1: Prepare Your CSV

Place your CSV file in the project:
```bash
cp /path/to/your/data.csv S3data/sales_2024.csv
```

### Step 2: Generate Metadata Template

Auto-generate a metadata file from your CSV:
```bash
python scripts/generate-table-metadata.py S3data/sales_2024.csv --table-name sales_2024 > metadata/sales_2024.json
```

**What this does:**
- Analyzes column names and sample data
- Detects data types (date, numeric, boolean, string)
- Counts unique values and nulls
- Generates basic descriptions
- Creates JSON template

**Output example:**
```json
{
  "table_description": "Data table with 15 columns and approximately 50000 rows",
  "common_queries": [
    "sales by region",
    "revenue trends"
  ],
  "columns": {
    "sale_id": "Sale Id (numeric value) - likely unique identifier",
    "transaction_date": "Transaction Date (date field)",
    "customer_name": "Customer Name (e.g., John Doe, Jane Smith, Bob Wilson)",
    "total_amount": "Total Amount (numeric value)"
  }
}
```

### Step 3: Improve Metadata (Important!)

Edit the generated JSON to add domain knowledge:
```bash
nano metadata/sales_2024.json
```

**Improvements to make:**
```json
{
  "table_description": "Daily sales transactions for 2024 including product SKUs, customer information, and revenue details. Use for sales analysis, revenue reporting, and customer purchase history.",
  "common_queries": [
    "sales by region",
    "revenue trends",
    "top selling products",
    "customer purchases",
    "monthly sales performance"
  ],
  "columns": {
    "sale_id": "Unique sale transaction identifier (primary key, auto-incrementing integer)",
    "transaction_date": "Date of sale transaction (YYYY-MM-DD format, use for date range queries)",
    "customer_id": "Customer identifier (foreign key to customers table, use for JOIN queries)",
    "total_amount": "Total sale amount in USD (includes tax and discounts, stored as DECIMAL)"
  }
}
```

**Tips:**
- Add context about when to use this table
- Include foreign key relationships
- Specify date formats
- Note if numeric fields are stored as strings
- Add search terms users might actually say

### Step 4: Run Automated Onboarding

Execute the all-in-one script:
```bash
./scripts/onboard-new-table.sh S3data/sales_2024.csv sales_2024 metadata/sales_2024.json
```

**What happens automatically:**

1. **Validates inputs** (CSV exists, JSON is valid, table name is legal)
2. **Uploads CSV to S3** at `s3://your-bucket/data/sales_2024/`
3. **Creates/runs Glue Crawler** to catalog the table
4. **Waits for completion** (polls crawler status)
5. **Adds column descriptions** to Glue Data Catalog
6. **Generates agent snippet** for your instructions
7. **Creates test queries** for validation

**Success output:**
```
✨ Table Onboarding Complete!
════════════════════════════════════════════════════════════

Table Name: sales_2024
S3 Location: s3://txt2sql-dev-data-bucket/data/sales_2024/
Database: txt2sql_dev_athena_db

Next Steps:
1. Review agent snippet: schema/agent-snippets/sales_2024_snippet.txt
2. Add snippet to: docs/enhanced-agent-instruction.txt
3. Test queries in Athena console: tests/queries/sales_2024_tests.sql
4. Update and redeploy Bedrock agent with new instructions
```

### Step 5: Update Agent Instructions

Copy the generated snippet to your agent instructions:
```bash
cat schema/agent-snippets/sales_2024_snippet.txt >> docs/enhanced-agent-instruction.txt
```

Or manually add it in the appropriate section.

### Step 6: Test in Athena

Verify the table is queryable:
```sql
-- Check schema with descriptions
DESCRIBE sales_2024;

-- Run sample query
SELECT * FROM sales_2024 LIMIT 10;

-- Test the generated queries
-- (open tests/queries/sales_2024_tests.sql in Athena console)
```

### Step 7: Redeploy Agent

Update your Bedrock agent with the new instructions:
```bash
# Via AWS Console: Bedrock → Agents → Your Agent → Edit → Update Instructions
# Or via CLI/CloudFormation if automated
```

---

## Environment Variables

Configure these in your environment or `.env` file:

```bash
export S3_DATA_BUCKET="txt2sql-dev-data-bucket"
export DATABASE_NAME="txt2sql_dev_athena_db"
export AWS_REGION="us-west-2"
export AWS_PROFILE="your-profile"  # Optional
```

---

## Troubleshooting

### Crawler Creation Fails

**Error:** "Could not create crawler: Access Denied"

**Fix:** Update the IAM role name in the script:
```bash
# Edit scripts/onboard-new-table.sh, line ~103
Role='AWSGlueServiceRole-txt2sql',  # Change to your Glue role name
```

### Column Descriptions Not Appearing

**Fix:** Run the standalone script:
```bash
python scripts/add-column-descriptions.py
```

### Table Already Exists

**Fix:** Either:
- Delete the old table in Glue
- Use a different table name
- Manually update the existing table

---

## Batch Processing Multiple Tables

Process multiple CSV files at once:

```bash
#!/bin/bash
# batch-onboard.sh

for csv_file in S3data/*.csv; do
    table_name=$(basename "$csv_file" .csv)
    
    echo "Processing: $table_name"
    
    # Generate metadata
    python scripts/generate-table-metadata.py "$csv_file" \
        --table-name "$table_name" > "metadata/${table_name}.json"
    
    # Review prompt
    echo "Review metadata/${table_name}.json and press Enter to continue..."
    read
    
    # Onboard
    ./scripts/onboard-new-table.sh "$csv_file" "$table_name" "metadata/${table_name}.json"
    
    echo "Completed: $table_name"
    echo "---"
done
```

---

## Maintenance

### Adding More Column Descriptions Later

If you initially uploaded a table without descriptions:

1. Create metadata JSON file
2. Run only the description update:
```bash
python scripts/add-column-descriptions.py
```

### Updating Existing Table

When CSV schema changes:

1. Upload new CSV to S3 (overwrites old)
2. Run Glue Crawler manually or wait for scheduled run
3. Update metadata JSON if columns changed
4. Re-run description script

### Removing Tables

```bash
# Delete from Glue
aws glue delete-table --database-name txt2sql_dev_athena_db --name sales_2024

# Delete from S3
aws s3 rm s3://your-bucket/data/sales_2024/ --recursive

# Remove from agent instructions
# (manually edit docs/enhanced-agent-instruction.txt)
```

---

## Best Practices

### ✅ DO:
- Always review auto-generated metadata before onboarding
- Add domain-specific context to descriptions
- Include foreign key relationships in column descriptions
- Test queries in Athena before agent deployment
- Version control your metadata JSON files
- Document common query patterns

### ❌ DON'T:
- Upload CSV files with spaces in filenames
- Use uppercase in table names (Athena is case-sensitive)
- Skip the metadata review step
- Forget to update agent instructions after onboarding
- Leave cryptic column names without descriptions

---

## File Structure After Onboarding

```
agent-txt2sql/
├── S3data/
│   └── sales_2024.csv                    # Your source CSV
├── metadata/
│   └── sales_2024.json                   # Table metadata
├── schema/
│   └── agent-snippets/
│       └── sales_2024_snippet.txt        # Generated agent snippet
├── tests/
│   └── queries/
│       └── sales_2024_tests.sql          # Test queries
└── docs/
    └── enhanced-agent-instruction.txt    # Agent instructions (update this)
```

---

## Complete Example

Let's onboard a sales dataset:

```bash
# 1. Generate metadata template
python scripts/generate-table-metadata.py S3data/mock-data-procedures.csv \
    --table-name procedures_2024 > metadata/procedures_2024.json

# 2. Improve the metadata (edit the JSON)
nano metadata/procedures_2024.json

# 3. Run automated onboarding
./scripts/onboard-new-table.sh \
    S3data/mock-data-procedures.csv \
    procedures_2024 \
    metadata/procedures_2024.json

# 4. Verify in Athena
aws athena start-query-execution \
    --query-string "DESCRIBE procedures_2024" \
    --result-configuration "OutputLocation=s3://your-athena-results/" \
    --query-execution-context "Database=txt2sql_dev_athena_db"

# 5. Update agent instructions
cat schema/agent-snippets/procedures_2024_snippet.txt

# 6. Test with agent
# (Use Bedrock console to test: "Show me all procedures in the imaging category")
```

---

## Next Steps

After onboarding tables, you should:

1. **Build test suite** - Create comprehensive test queries
2. **Monitor usage** - Track which tables are queried most
3. **Iterate on descriptions** - Improve based on query failures
4. **Document relationships** - Map out foreign keys between tables
5. **Set up CI/CD** - Automate agent deployment when instructions change

---

## Support

If you encounter issues:
1. Check AWS CloudWatch logs for Glue Crawler
2. Verify IAM permissions for S3, Glue, and Athena
3. Test queries manually in Athena console
4. Review Bedrock agent logs for query generation errors
