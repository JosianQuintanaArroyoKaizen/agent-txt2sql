# Enable Orchestration Prompt Editing

## What You're Seeing

You're in the right place! You see:
- **Orchestration type: Default** with an **Edit** button

## Step-by-Step Instructions

### Step 1: Enable Orchestration Override

1. Click the **Edit** button next to "Orchestration"
2. You should see options to change the orchestration type
3. **Change from "Default" to "Overridden"** (or "Override orchestration template defaults")
4. This will enable the prompt editor

### Step 2: Find the Prompt Template Editor

Once you enable "Overridden", you should see:
- A large text editor/textarea
- The orchestration prompt template
- Look for sections like `<athena_schemas>` or `athena_schemas`

### Step 3: Locate the Schema Section

Scroll through the prompt template and find:
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

### Step 4: Add EMIR Schema

Add this **right before** the closing `</athena_schemas>` tag:

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

### Step 5: Update Guidelines

Also find the line that says something like:
```
The Athena database name is ... and the tables are ... customers and ... procedures:
```

Update it to:
```
The Athena database name is txt2sql_dev_athena_db and the tables are customers, procedures, and test_population:
```

### Step 6: Save

1. Click **Save** or **Save and exit**
2. Go back to the agent overview
3. Click **Prepare** (this creates a new version)
4. Wait 1-2 minutes for preparation

### Step 7: Test

Try: "Show me some records from the EMIR dataset"

## If You Don't See the Prompt Editor

After clicking "Edit" and changing to "Overridden", if you don't see a text editor:
- Look for a button like "Edit prompt template" or "Override template"
- There might be a toggle to "Activate orchestration template"
- Check if there's a "Prompt template editor" section below

## Full Schema (If Needed)

If you want all 224 columns instead of just the key ones, run:
```bash
python3 scripts/generate_emir_schema.py
```

This will output the complete schema with all columns.

