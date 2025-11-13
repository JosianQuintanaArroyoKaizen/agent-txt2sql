# Fix: Change Orchestration Back to Overridden

## What Happened

You accidentally restored the orchestration to "Default", which hides the prompt editor. You need to change it back to "Overridden".

## Quick Fix Steps

### Step 1: Click Edit Again

1. Click the **Edit** button next to "Orchestration"
2. You should see a dropdown or toggle for "Orchestration type"

### Step 2: Change to Overridden

1. **Change "Orchestration type" from "Default" to "Overridden"**
   - This might be a dropdown menu
   - Or a toggle/switch
   - Or a radio button selection

2. **Enable "Override orchestration template defaults"** (if you see this checkbox)

3. **Enable "Activate orchestration template"** (if you see this option)

### Step 3: Find the Prompt Editor

After changing to "Overridden", you should see:
- A large text area/editor
- The orchestration prompt template
- Sections with XML-like tags

### Step 4: Locate the Schema Section

In the prompt editor, search for (Ctrl+F or Cmd+F):
- `athena_schemas`
- `customers`
- `procedures`

You should find something like:
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

### Step 5: Add EMIR Schema

Add the EMIR schema right before `</athena_schemas>`:

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

### Step 6: Update Guidelines

Also find and update the line that mentions tables:
- Find: `The Athena database name is ... and the tables are ... customers and ... procedures:`
- Change to: `The Athena database name is txt2sql_dev_athena_db and the tables are customers, procedures, and test_population:`

### Step 7: Save and Prepare

1. Click **Save** or **Save and exit**
2. Go back to agent overview
3. Click **Prepare** (creates new version)
4. Wait 1-2 minutes

## If You Don't See the Option to Change to "Overridden"

If after clicking "Edit" you don't see a way to change from "Default" to "Overridden":
- Look for a toggle switch
- Check for a "Customize" or "Override" button
- There might be a "Prompt template editor" section that appears after enabling override
- Try scrolling down in the Edit dialog

## Screenshot Help

If you can share a screenshot of what you see after clicking "Edit" next to Orchestration, I can give more specific guidance!

