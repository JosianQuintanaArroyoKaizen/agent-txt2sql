# Troubleshooting App Runner JSON Parsing Error

## Error: "Expecting value: line 1 column 1 (char 0)"

This error occurs when the Streamlit app receives an **empty or non-JSON response** from the backend. The JSON parser expects valid JSON but gets an empty string.

## Root Causes & Solutions

### 1. **Missing or Incorrect Environment Variables** ⚠️ MOST COMMON

The App Runner service needs `AGENT_ID` and `AGENT_ALIAS_ID` environment variables.

**Check current values:**
```bash
# Get your App Runner service ARN first
SERVICE_ARN=$(aws apprunner list-services --region eu-central-1 --query 'ServiceSummaryList[?ServiceName==`txt2sql-streamlit-dev`].ServiceArn' --output text)

# Check environment variables
aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region eu-central-1 \
  --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables' \
  --output json
```

**Fix: Update environment variables**
```bash
# Get your Agent ID and Alias ID from Bedrock
AGENT_ID=$(aws bedrock-agent list-agents --region eu-central-1 --query 'agentSummaries[0].agentId' --output text)
AGENT_ALIAS_ID=$(aws bedrock-agent list-agent-aliases \
  --agent-id $AGENT_ID \
  --region eu-central-1 \
  --query 'agentAliasSummaries[0].agentAliasId' \
  --output text)

# Update App Runner service
aws apprunner update-service \
  --service-arn $SERVICE_ARN \
  --region eu-central-1 \
  --source-configuration '{
    "ImageRepository": {
      "ImageIdentifier": "<YOUR_ECR_IMAGE>",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8501",
        "RuntimeEnvironmentVariables": {
          "AWS_REGION": "eu-central-1",
          "AGENT_ID": "'$AGENT_ID'",
          "AGENT_ALIAS_ID": "'$AGENT_ALIAS_ID'"
        }
      }
    },
    "AutoDeploymentsEnabled": true
  }'
```

### 2. **AWS Credentials/Permissions Issue**

App Runner needs IAM permissions to call Bedrock Agent API.

**Check App Runner instance role:**
```bash
aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region eu-central-1 \
  --query 'Service.InstanceConfiguration.InstanceRoleArn' \
  --output text
```

**Required permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeAgent",
        "bedrock-runtime:InvokeAgent"
      ],
      "Resource": "*"
    }
  ]
}
```

**Fix: Attach policy to App Runner instance role**
```bash
# Get the role name
ROLE_ARN=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region eu-central-1 \
  --query 'Service.InstanceConfiguration.InstanceRoleArn' \
  --output text)

ROLE_NAME=$(echo $ROLE_ARN | cut -d'/' -f2)

# Create and attach policy
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name BedrockAgentAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeAgent",
        "bedrock-runtime:InvokeAgent"
      ],
      "Resource": "*"
    }]
  }'
```

### 3. **Bedrock Agent Not Responding**

The Bedrock Agent API might be returning an error or empty response.

**Test Bedrock Agent directly:**
```bash
# Test with AWS CLI
aws bedrock-agent-runtime invoke-agent \
  --agent-id $AGENT_ID \
  --agent-alias-id $AGENT_ALIAS_ID \
  --session-id "TEST-SESSION" \
  --input-text "Hello" \
  --region eu-central-1 \
  output.json

cat output.json
```

**Check Bedrock Agent status:**
```bash
aws bedrock-agent describe-agent \
  --agent-id $AGENT_ID \
  --region eu-central-1 \
  --query 'Agent.AgentStatus' \
  --output text
```

Should return: `PREPARED` or `NOT_PREPARED`

### 4. **Check CloudWatch Logs** 📊

App Runner logs are sent to CloudWatch. Check them for detailed errors:

```bash
# Get log group name
LOG_GROUP="/aws/apprunner/$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region eu-central-1 \
  --query 'Service.ServiceName' \
  --output text)/application"

# View recent logs
aws logs tail $LOG_GROUP --follow --region eu-central-1

# Or view in AWS Console:
# CloudWatch → Log groups → /aws/apprunner/<service-name>/application
```

**Look for:**
- `ERROR: Agent ID or Alias ID not configured`
- `HTTP Error 403` (permissions issue)
- `HTTP Error 404` (agent not found)
- `Empty response received from Bedrock agent`
- `Error making request to Bedrock agent`

### 5. **Network/Connectivity Issues**

App Runner might not be able to reach Bedrock API.

**Check VPC configuration:**
```bash
aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region eu-central-1 \
  --query 'Service.NetworkConfiguration' \
  --output json
```

If VPC is configured, ensure:
- VPC has internet gateway or NAT gateway
- Security groups allow outbound HTTPS (port 443)
- Route tables are configured correctly

## Quick Diagnostic Script

Run this to check all common issues:

```bash
#!/bin/bash
REGION="eu-central-1"
SERVICE_NAME="txt2sql-streamlit-dev"

echo "=== App Runner Troubleshooting ==="
echo ""

# 1. Get service ARN
SERVICE_ARN=$(aws apprunner list-services \
  --region $REGION \
  --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn" \
  --output text)

if [ -z "$SERVICE_ARN" ]; then
  echo "❌ Service not found: $SERVICE_NAME"
  exit 1
fi

echo "✅ Service ARN: $SERVICE_ARN"
echo ""

# 2. Check environment variables
echo "=== Environment Variables ==="
ENV_VARS=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables' \
  --output json)

AGENT_ID=$(echo $ENV_VARS | jq -r '.AGENT_ID // "NOT SET"')
AGENT_ALIAS_ID=$(echo $ENV_VARS | jq -r '.AGENT_ALIAS_ID // "NOT SET"')
AWS_REGION=$(echo $ENV_VARS | jq -r '.AWS_REGION // "NOT SET"')

echo "AGENT_ID: $AGENT_ID"
echo "AGENT_ALIAS_ID: $AGENT_ALIAS_ID"
echo "AWS_REGION: $AWS_REGION"
echo ""

if [ "$AGENT_ID" == "NOT SET" ] || [ "$AGENT_ALIAS_ID" == "NOT SET" ]; then
  echo "❌ Environment variables not set correctly!"
  echo "   Fix: Update App Runner service with correct values"
fi

# 3. Check service status
echo "=== Service Status ==="
STATUS=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --query 'Service.Status' \
  --output text)
echo "Status: $STATUS"

# 4. Check Bedrock Agent
if [ "$AGENT_ID" != "NOT SET" ] && [ "$AGENT_ID" != "<YOUR AGENT ID>" ]; then
  echo ""
  echo "=== Bedrock Agent Status ==="
  AGENT_STATUS=$(aws bedrock-agent describe-agent \
    --agent-id $AGENT_ID \
    --region $REGION \
    --query 'Agent.AgentStatus' \
    --output text 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "Agent Status: $AGENT_STATUS"
  else
    echo "❌ Cannot access Bedrock Agent (permissions issue?)"
  fi
fi

# 5. Check logs
echo ""
echo "=== Recent Logs (last 20 lines) ==="
LOG_GROUP="/aws/apprunner/$SERVICE_NAME/application"
aws logs tail $LOG_GROUP --since 10m --region $REGION 2>/dev/null | tail -20 || echo "No logs found or cannot access"

echo ""
echo "=== Next Steps ==="
echo "1. Check CloudWatch logs: aws logs tail $LOG_GROUP --follow --region $REGION"
echo "2. Update environment variables if needed"
echo "3. Check IAM permissions for App Runner instance role"
```

## Common Error Messages & Fixes

| Error Message | Cause | Fix |
|--------------|-------|-----|
| `Expecting value: line 1 column 1 (char 0)` | Empty response body | Check environment variables, permissions, Bedrock agent status |
| `Agent ID or Alias ID not configured` | Environment variables not set | Update App Runner service with AGENT_ID and AGENT_ALIAS_ID |
| `HTTP Error 403` | Permission denied | Add Bedrock permissions to App Runner instance role |
| `HTTP Error 404` | Agent not found | Verify AGENT_ID and AGENT_ALIAS_ID are correct |
| `Empty response received from Bedrock agent` | Bedrock API returned empty | Check Bedrock agent status and test with AWS CLI |

## Still Not Working?

1. **Enable verbose logging** in `invoke_agent.py` (already has print statements)
2. **Check App Runner service health:**
   ```bash
   aws apprunner describe-service --service-arn $SERVICE_ARN --region eu-central-1
   ```
3. **Redeploy the service** to ensure latest code is running
4. **Test locally** first to isolate if it's an App Runner-specific issue

