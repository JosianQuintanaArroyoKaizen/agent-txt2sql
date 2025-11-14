# Update Bedrock Agent for EMIR via CloudFormation

## What You Found

The OpenAPI schema you found is for the **Action Group** - that's correct and doesn't need to change. The **Orchestration Prompt** is embedded in the CloudFormation template.

## Solution: Update CloudFormation Template

I've already updated the CloudFormation template (`cfn/2-bedrock-agent-lambda-template.yaml`) to include the EMIR table schema. Now you need to update the CloudFormation stack.

## Steps to Update

### Option 1: Update Stack via AWS Console (Easiest)

1. **Go to CloudFormation Console**
   - Navigate to: https://console.aws.amazon.com/cloudformation/
   - Find your stack (likely named something like `AthenaAgent-...` or `2-bedrock-agent-lambda`)

2. **Update the Stack**
   - Select your stack
   - Click **Update**
   - Choose **Replace current template**
   - Upload the updated file: `cfn/2-bedrock-agent-lambda-template.yaml`
   - Click **Next** through the wizard
   - Review and submit

3. **Wait for Update**
   - The stack update will take 2-5 minutes
   - The agent will automatically prepare a new version (because `AutoPrepare: 'True'`)

4. **Test**
   - Go to Bedrock Console → Agents → Your Agent
   - Test with: "Show me some records from the EMIR dataset"

### Option 2: Update via AWS CLI

```bash
# Make sure you're in the project directory
cd /home/jquintana-arroyo/git/agent-txt2sql

# Find your stack name
aws cloudformation list-stacks \
  --region eu-central-1 \
  --query 'StackSummaries[?contains(StackName, `bedrock`) || contains(StackName, `agent`)].StackName' \
  --output table

# Update the stack (replace STACK_NAME with your actual stack name)
aws cloudformation update-stack \
  --stack-name STACK_NAME \
  --template-body file://cfn/2-bedrock-agent-lambda-template.yaml \
  --region eu-central-1 \
  --capabilities CAPABILITY_NAMED_IAM

# Wait for update to complete
aws cloudformation wait stack-update-complete \
  --stack-name STACK_NAME \
  --region eu-central-1
```

## What Was Changed

The template now includes:

1. **EMIR Table Schema** (added after procedures schema):
   - Table: `txt2sql_dev_athena_db.test_population`
   - Key columns: incident_code, uti_2_1, counterparty info, valuation fields, etc.
   - Location: `s3://sl-data-store-.../custom/test_population/`

2. **Updated Guidelines**:
   - Now mentions `test_population` table alongside customers and procedures

3. **Example Query**:
   - Added an example query for the EMIR dataset

## Important Notes

- **No data loss**: This only updates the agent configuration, not your data
- **Auto-prepare**: The agent will automatically prepare a new version after the stack update
- **S3 Location**: Make sure the S3 location in the schema matches where your CSV was uploaded
  - Current: `s3://sl-data-store-${Alias}-${AWS::AccountId}-${AWS::Region}/custom/test_population/`
  - Verify this matches your actual S3 bucket structure

## Verify After Update

1. **Check Agent Version**:
   ```bash
   aws bedrock-agent describe-agent \
     --agent-id YOUR_AGENT_ID \
     --region eu-central-1 \
     --query 'latestAgentVersion'
   ```
   The version number should have increased.

2. **Test Query**:
   - "Show me 5 records from test_population table"
   - "What is the total valuation amount in the EMIR dataset?"

## If You Prefer Console Update Instead

If you can find the "Advanced prompts" → "Orchestration" section in the Bedrock console:

1. Go to Bedrock → Agents → Your Agent → Edit
2. Scroll to **Advanced prompts** section
3. Click **Edit** next to **Orchestration**
4. Find `<athena_schemas>` section
5. Add the EMIR schema (see `QUICK-FIX-EMIR.md` for the full schema)
6. Save and Prepare

But if you can't find it (which seems to be your case), updating CloudFormation is the way to go!

