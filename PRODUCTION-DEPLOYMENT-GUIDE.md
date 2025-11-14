# CloudFormation Template Updates for Production-Ready Deployment

## Summary of Manual Fixes Applied

During development, we made several manual fixes that need to be incorporated into the CloudFormation templates for production deployments:

### 1. Agent Instruction Updates (`cfn/2-bedrock-agent-lambda-template.yaml`)

**What we fixed manually:**
- Added test_population table schema with 200+ columns
- Added instruction to EXECUTE queries (not just return SQL)
- Added output formatting guidelines (select only relevant columns, not SELECT *)
- Added explicit query examples

**Required Template Change:**
Replace the `Instruction:` section in `BedrockAgent` resource (lines 228-247) with the updated instruction from `fix-output-format.sh`

**Location:** Lines 228-247 in `cfn/2-bedrock-agent-lambda-template.yaml`

### 2. Frontend Lambda Permissions

**What we fixed manually:**
- Added `bedrock-runtime:InvokeAgent` permission (critical!)
- Added `bedrock:InvokeAgent` permission
- Both are required for Lambda to call Bedrock agents

**Required Template Change:**
If you create a CloudFormation template for the frontend Lambda (`txt2sql-frontend-proxy`), ensure the IAM role includes:

```yaml
  FrontendLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        - arn:aws:iam::aws:policy/AmazonBedrockFullAccess
      Policies:
        - PolicyName: BedrockAgentInvokePolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - bedrock:InvokeModel
                  - bedrock:InvokeAgent
                  - bedrock-runtime:InvokeModel
                  - bedrock-runtime:InvokeAgent
                Resource: "*"
```

**Location:** `frontend/deploy-simple.sh` already updated with this fix

### 3. Agent Alias Configuration

**What we fixed manually:**
- Changed from `BW3ALCWPTJ` (version 1, outdated) to `TSTALIASID` (DRAFT, with test_population)
- Frontend and Lambda now use `TSTALIASID`

**Required Change:**
- `frontend/deploy-simple.sh`: Line 19 now defaults to `TSTALIASID` ✅ (already fixed)
- `frontend/index.html`: Line with default alias now uses `TSTALIASID` ✅ (already fixed)
- `frontend/app.js`: Hardcoded API endpoint ✅ (already fixed)

### 4. Agent Execution Role

**Critical Issue Found:**
The stack `dev-eu-central-1-bedrock-agent-lambda-stack` rolled back and deleted the `AmazonBedrockExecutionRoleForAgents_txt2sql_dev` role.

**Fix Applied:**
Created `recreate-agent-role.sh` to manually recreate the role.

**For Production:**
Ensure CloudFormation template creates the role properly and doesn't have JSON validation errors that cause rollbacks.

## Files Updated for Production Readiness

### ✅ Already Updated:
1. `frontend/deploy-simple.sh` - bedrock-runtime permissions added
2. `frontend/index.html` - uses TSTALIASID
3. `frontend/app.js` - uses TSTALIASID and hardcoded endpoint
4. `.github/workflows/deploy.yml` - triggers on dev branch

### ⚠️ Needs Manual Update:
1. `cfn/2-bedrock-agent-lambda-template.yaml` - Agent instruction (lines 228-247)
   - Copy instruction from `fix-output-format.sh` or from the agent console

## Testing a Fresh Deployment

### For Dev (Current Setup):
```bash
# Already working - frontend deployment script has all fixes
cd frontend
./deploy-simple.sh
```

### For Prod (New Deployment):
```bash
# 1. Deploy CloudFormation stacks
cd cfn
aws cloudformation create-stack \
  --stack-name prod-eu-central-1-athena-glue-s3-stack \
  --template-body file://1-athena-glue-s3-template.yaml \
  --parameters ParameterKey=Alias,ParameterValue=txt2sql-prod \
  --capabilities CAPABILITY_NAMED_IAM \
  --region eu-central-1

# Wait for completion, then deploy agent stack
aws cloudformation create-stack \
  --stack-name prod-eu-central-1-bedrock-agent-lambda-stack \
  --template-body file://2-bedrock-agent-lambda-template.yaml \
  --parameters ParameterKey=Alias,ParameterValue=txt2sql-prod \
  --capabilities CAPABILITY_NAMED_IAM \
  --region eu-central-1

# 2. After agent is created, update instruction manually (until template is fixed)
# Run the equivalent of fix-output-format.sh with prod agent ID

# 3. Deploy frontend
cd ../frontend
AGENT_ID=<prod-agent-id> AGENT_ALIAS_ID=<prod-alias-id> ./deploy-simple.sh
```

## Key Takeaways for Prod

1. **Agent Instruction**: Must include test_population schema and output formatting guidelines
2. **Lambda Permissions**: Must have `bedrock-runtime:InvokeAgent` (not just `bedrock:InvokeAgent`)
3. **Agent Alias**: Use the DRAFT alias or create a versioned alias after testing
4. **Execution Role**: Must exist and have permissions for Lambda invoke + Bedrock

## Quick Fix Script for New Deployments

Create a post-deployment script that:
1. Gets the agent ID from CloudFormation output
2. Runs the updated instruction (from fix-output-format.sh)
3. Prepares the agent
4. Updates frontend with correct agent ID and alias

Would you like me to create this script?
