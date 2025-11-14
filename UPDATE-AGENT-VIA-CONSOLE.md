# Update Bedrock Agent via Console (Since CloudFormation is Failing)

## Your Stacks

**Frontend/UI Stacks** (not the agent):
- `txt2sql-dev-ecs-alb-streamlit-stack` - ECS with ALB
- `txt2sql-dev-ec2-simple-streamlit-stack` - EC2 Simple (this one is working!)
- `txt2sql-dev-ec2-alb-streamlit-stack` - EC2 with ALB

**Bedrock Agent Stack**:
- `dev-eu-central-1-bedrock-agent-lambda-stack` - This is the one with the agent (currently in rollback state)

## Since CloudFormation Update Failed

Since the CloudFormation update keeps failing, let's update the agent directly via the AWS Console. This is actually simpler!

## Step-by-Step: Update Agent Orchestration Prompt

### Step 1: Find Your Agent

1. Go to **AWS Bedrock Console**: https://console.aws.amazon.com/bedrock/
2. Click **Agents** in the left sidebar
3. You should see your agent (likely named something like `AthenaAgent-txt2sql-dev-...`)

### Step 2: Edit the Agent

1. Click on your agent name
2. Click the **Edit** button (top right)
3. **Scroll ALL the way down** - the "Advanced prompts" section is often at the very bottom
4. Look for a section called **"Advanced prompts"** or **"Prompt overrides"**

### Step 3: Find Orchestration Prompt

If you see "Advanced prompts":
1. Click **Edit** next to **"Orchestration"**
2. You should see a large text editor with the orchestration template
3. Look for `<athena_schemas>` section

If you DON'T see "Advanced prompts":
- The agent might have been created without prompt overrides
- We may need to enable it first
- Or update via API (more complex)

### Step 4: Add EMIR Schema

Once you find the `<athena_schemas>` section:

1. Find the closing `</athena_schema>` tag for the `procedures` table
2. **Add this** right before `</athena_schemas>`:

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

3. Also update the guidelines line to mention `test_population` table

### Step 5: Save and Prepare

1. Click **Save and exit**
2. Click **Prepare** (this creates a new agent version)
3. Wait 1-2 minutes for preparation to complete

### Step 6: Test

Try: "Show me some records from the EMIR dataset"

## If You Still Can't Find "Advanced Prompts"

If the "Advanced prompts" section doesn't exist in the console:

1. **Check if the agent was created with prompt overrides** - Some agents don't have this section
2. **Try the API approach** - We can update via AWS CLI/API (more complex)
3. **Check agent version** - Older agent versions might not support this

Let me know what you see in the Edit view, and I can help you locate it!

## Quick Test: Verify Agent is Working

While we troubleshoot, you can verify the agent works with the sample data:

- "Show me all customers"
- "List procedures in the imaging category"

If these work, the agent is fine - we just need to add the EMIR table to its knowledge.

