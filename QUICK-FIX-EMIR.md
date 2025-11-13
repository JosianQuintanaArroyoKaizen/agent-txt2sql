# Quick Fix: Enable EMIR Dataset Queries

## Problem
Your Bedrock agent is still querying the sample dataset (`customers` table) when you ask for EMIR data. This is because the agent's orchestration prompt doesn't know about the `test_population` table yet.

## Solution (No Redeployment Needed!)

You only need to **update the Bedrock agent configuration** in the AWS Console. No CloudFormation redeployment required.

### Step-by-Step Instructions

1. **Open AWS Bedrock Console**
   - Go to: https://console.aws.amazon.com/bedrock/
   - Navigate to **Agents** (left sidebar)
   - Find and click on your agent (e.g., `AthenaAgent-...`)

2. **Edit the Agent**
   - Click the **Edit** button (top right)
   - Scroll down to **Advanced prompts** section
   - Click **Edit** next to **Orchestration**

3. **Add EMIR Table Schema**
   - Find the section that looks like this:
     ```xml
     <athena_schemas>
       <athena_schema> 
       CREATE EXTERNAL TABLE ... customers ...
       </athena_schema>
       <athena_schema> 
       CREATE EXTERNAL TABLE ... procedures ...
       </athena_schema>
     </athena_schemas>
     ```
   - **Add the EMIR schema** right after the `procedures` schema and before `</athena_schemas>`

4. **Get the Schema**
   Run this command to get the exact schema to paste:
   ```bash
   python3 scripts/generate_emir_schema.py
   ```
   
   Or copy from the output below (see "Schema to Add" section)

5. **Update Guidelines**
   - Find the line that says: `The Athena database name is ... and the tables are ... customers and ... procedures:`
   - Update it to: `The Athena database name is txt2sql_dev_athena_db and the tables are customers, procedures, and test_population:`

6. **Save and Prepare**
   - Click **Save and exit**
   - Click **Prepare** (this creates a new version)
   - Wait for "Preparation complete" (usually 1-2 minutes)

7. **Test**
   - Use the test interface in the Bedrock console
   - Try: "Show me some records from the EMIR dataset"
   - Or: "Query the test_population table"

## Schema to Add

Paste this XML block after the `procedures` schema:

```xml
<athena_schema>
CREATE EXTERNAL TABLE txt2sql_dev_athena_db.test_population (
  `incident_code` STRING,
  `incident_description` STRING,
  `uti_2_1` STRING,
  `counterparty_1_reporting_counterparty_1_4` STRING,
  `counterparty_2_1_9` STRING,
  `valuation_amount_2_21` STRING,
  `valuation_currency_2_22` STRING,
  `valuation_date_2_23` STRING,
  `asset_class_2_11` STRING,
  `product_classification_2_9` STRING,
  `contract_type_2_10` STRING,
  `cleared_2_31` STRING,
  `clearing_obligation_2_30` STRING,
  `execution_date_2_42` STRING,
  `effective_date_2_43` STRING,
  `expiration_date_2_44` STRING,
  `notional_amount_of_leg_1_2_55` STRING,
  `notional_amount_of_leg_2_2_64` STRING,
  `isin_2_7` STRING,
  `kr_record_key` STRING,
  `source_file_name` STRING,
  `reporting_date_1_1` STRING,
  `reporting_timestamp_1_1` STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar' = '"'
)
STORED AS TEXTFILE
LOCATION 's3://sl-data-store-txt2sql-dev-194561596031-eu-central-1/custom/test_population/'
TBLPROPERTIES ('skip.header.line.count'='1');
</athena_schema>
```

**Note:** The full schema has 224 columns. The above shows key columns. For the complete schema with all columns, run:
```bash
python3 scripts/generate_emir_schema.py
```

## Verify It Worked

After preparing the new version, test with:
- "Show me 5 records from test_population table"
- "What columns are in the EMIR dataset?"
- "Count the total records in test_population"

If it still returns customer data, make sure:
1. You clicked **Prepare** (not just Save)
2. You're testing with the newly prepared version
3. The schema was added correctly (check for typos)

## Troubleshooting

### Still getting customer data?
- Check that you clicked **Prepare** after saving
- Verify the agent version number increased
- Wait a few seconds after preparation completes

### "Table not found" errors?
- Verify table name: `test_population` (or `test_population_view` if you created a view)
- Check database name: `txt2sql_dev_athena_db`
- Run `SHOW TABLES LIKE 'test_population%';` in Athena to confirm

### Can't find the orchestration section?
- Make sure you're in **Edit** mode
- Look for **Advanced prompts** → **Orchestration** tab
- If using CloudFormation, you may need to update the template and redeploy (but try console first!)

## Why This Happens

The Bedrock agent uses an "orchestration prompt" that tells it what tables exist and how to query them. This prompt is stored in the agent configuration, not in the Lambda function or CloudFormation. That's why you only need to update the agent, not redeploy infrastructure.

