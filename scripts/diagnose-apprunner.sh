#!/bin/bash

##############################################################################
# App Runner Diagnostic Script
# Checks common issues that cause "Expecting value: line 1 column 1" error
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REGION="${AWS_REGION:-eu-central-1}"
SERVICE_NAME="${APP_RUNNER_SERVICE_NAME:-txt2sql-streamlit-dev}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  App Runner Diagnostic Tool${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Get service ARN
echo -e "${YELLOW}[1/6] Finding App Runner service...${NC}"
SERVICE_ARN=$(aws apprunner list-services \
  --region $REGION \
  --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn" \
  --output text 2>/dev/null || echo "")

if [ -z "$SERVICE_ARN" ]; then
  echo -e "${RED}❌ Service not found: $SERVICE_NAME${NC}"
  echo -e "${YELLOW}Available services:${NC}"
  aws apprunner list-services --region $REGION --query 'ServiceSummaryList[*].ServiceName' --output table
  exit 1
fi

echo -e "${GREEN}✅ Service ARN: $SERVICE_ARN${NC}"
echo ""

# 2. Check service status
echo -e "${YELLOW}[2/6] Checking service status...${NC}"
STATUS=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --query 'Service.Status' \
  --output text)

if [ "$STATUS" == "RUNNING" ]; then
  echo -e "${GREEN}✅ Service is RUNNING${NC}"
else
  echo -e "${RED}❌ Service status: $STATUS${NC}"
  echo -e "${YELLOW}Service must be RUNNING to work properly${NC}"
fi

SERVICE_URL=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --query 'Service.ServiceUrl' \
  --output text)
echo -e "${GREEN}Service URL: $SERVICE_URL${NC}"
echo ""

# 3. Check environment variables
echo -e "${YELLOW}[3/6] Checking environment variables...${NC}"
ENV_VARS=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables' \
  --output json 2>/dev/null || echo "{}")

AGENT_ID=$(echo $ENV_VARS | jq -r '.AGENT_ID // empty' 2>/dev/null || echo "")
AGENT_ALIAS_ID=$(echo $ENV_VARS | jq -r '.AGENT_ALIAS_ID // empty' 2>/dev/null || echo "")
AWS_REGION_ENV=$(echo $ENV_VARS | jq -r '.AWS_REGION // empty' 2>/dev/null || echo "")

if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" == "null" ] || [ "$AGENT_ID" == "<YOUR AGENT ID>" ]; then
  echo -e "${RED}❌ AGENT_ID is not set or invalid: '$AGENT_ID'${NC}"
  ENV_ERROR=1
else
  echo -e "${GREEN}✅ AGENT_ID: $AGENT_ID${NC}"
fi

if [ -z "$AGENT_ALIAS_ID" ] || [ "$AGENT_ALIAS_ID" == "null" ] || [ "$AGENT_ALIAS_ID" == "<YOUR ALIAS ID>" ]; then
  echo -e "${RED}❌ AGENT_ALIAS_ID is not set or invalid: '$AGENT_ALIAS_ID'${NC}"
  ENV_ERROR=1
else
  echo -e "${GREEN}✅ AGENT_ALIAS_ID: $AGENT_ALIAS_ID${NC}"
fi

if [ -z "$AWS_REGION_ENV" ] || [ "$AWS_REGION_ENV" == "null" ]; then
  echo -e "${YELLOW}⚠ AWS_REGION not set (using default: $REGION)${NC}"
else
  echo -e "${GREEN}✅ AWS_REGION: $AWS_REGION_ENV${NC}"
fi

if [ "${ENV_ERROR:-0}" == "1" ]; then
  echo ""
  echo -e "${RED}⚠️  Environment variables are missing or incorrect!${NC}"
  echo -e "${YELLOW}This is likely the cause of your error.${NC}"
fi
echo ""

# 4. Check Bedrock Agent
if [ -n "$AGENT_ID" ] && [ "$AGENT_ID" != "<YOUR AGENT ID>" ] && [ "$AGENT_ID" != "null" ]; then
  echo -e "${YELLOW}[4/6] Checking Bedrock Agent...${NC}"
  
  AGENT_STATUS=$(aws bedrock-agent describe-agent \
    --agent-id $AGENT_ID \
    --region $REGION \
    --query 'Agent.AgentStatus' \
    --output text 2>/dev/null || echo "ERROR")
  
  if [ "$AGENT_STATUS" == "ERROR" ]; then
    echo -e "${RED}❌ Cannot access Bedrock Agent${NC}"
    echo -e "${YELLOW}Possible causes:${NC}"
    echo "  - Agent ID is incorrect"
    echo "  - IAM permissions missing"
    echo "  - Agent doesn't exist in this region"
  elif [ "$AGENT_STATUS" == "PREPARED" ]; then
    echo -e "${GREEN}✅ Agent status: PREPARED${NC}"
  else
    echo -e "${YELLOW}⚠ Agent status: $AGENT_STATUS${NC}"
  fi
  
  # Check alias
  if [ -n "$AGENT_ALIAS_ID" ] && [ "$AGENT_ALIAS_ID" != "<YOUR ALIAS ID>" ] && [ "$AGENT_ALIAS_ID" != "null" ]; then
    ALIAS_EXISTS=$(aws bedrock-agent get-agent-alias \
      --agent-id $AGENT_ID \
      --agent-alias-id $AGENT_ALIAS_ID \
      --region $REGION \
      --query 'AgentAlias.AgentAliasStatus' \
      --output text 2>/dev/null || echo "ERROR")
    
    if [ "$ALIAS_EXISTS" == "ERROR" ]; then
      echo -e "${RED}❌ Cannot access Agent Alias${NC}"
    elif [ "$ALIAS_EXISTS" == "CREATED" ]; then
      echo -e "${GREEN}✅ Agent Alias status: CREATED${NC}"
    else
      echo -e "${YELLOW}⚠ Agent Alias status: $ALIAS_EXISTS${NC}"
    fi
  fi
  echo ""
else
  echo -e "${YELLOW}[4/6] Skipping Bedrock Agent check (AGENT_ID not set)${NC}"
  echo ""
fi

# 5. Check IAM permissions
echo -e "${YELLOW}[5/6] Checking IAM permissions...${NC}"
INSTANCE_ROLE_ARN=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --query 'Service.InstanceConfiguration.InstanceRoleArn' \
  --output text 2>/dev/null || echo "")

if [ -n "$INSTANCE_ROLE_ARN" ]; then
  echo -e "${GREEN}✅ Instance Role: $INSTANCE_ROLE_ARN${NC}"
  
  ROLE_NAME=$(echo $INSTANCE_ROLE_ARN | cut -d'/' -f2)
  
  # Check if role has Bedrock permissions
  POLICIES=$(aws iam list-attached-role-policies \
    --role-name $ROLE_NAME \
    --query 'AttachedPolicies[*].PolicyArn' \
    --output text 2>/dev/null || echo "")
  
  HAS_BEDROCK=0
  for policy in $POLICIES; do
    POLICY_DOC=$(aws iam get-policy-version \
      --policy-arn $policy \
      --version-id $(aws iam get-policy --policy-arn $policy --query 'Policy.DefaultVersionId' --output text) \
      --query 'PolicyVersion.Document' \
      --output json 2>/dev/null || echo "{}")
    
    if echo $POLICY_DOC | jq -e '.Statement[] | select(.Action[]? | contains("bedrock"))' >/dev/null 2>&1; then
      HAS_BEDROCK=1
      break
    fi
  done
  
  if [ "$HAS_BEDROCK" == "1" ]; then
    echo -e "${GREEN}✅ Bedrock permissions found${NC}"
  else
    echo -e "${RED}❌ No Bedrock permissions found on role${NC}"
    echo -e "${YELLOW}The role needs bedrock:InvokeAgent and bedrock-runtime:InvokeAgent permissions${NC}"
  fi
else
  echo -e "${YELLOW}⚠ Cannot determine instance role${NC}"
fi
echo ""

# 6. Check CloudWatch Logs
echo -e "${YELLOW}[6/6] Checking recent logs...${NC}"
LOG_GROUP="/aws/apprunner/$SERVICE_NAME/application"

# Check if log group exists
LOG_GROUP_EXISTS=$(aws logs describe-log-groups \
  --log-group-name-prefix "/aws/apprunner/$SERVICE_NAME" \
  --region $REGION \
  --query 'logGroups[?logGroupName==`'$LOG_GROUP'`].logGroupName' \
  --output text 2>/dev/null || echo "")

if [ -n "$LOG_GROUP_EXISTS" ]; then
  echo -e "${GREEN}✅ Log group exists: $LOG_GROUP${NC}"
  echo ""
  echo -e "${BLUE}Recent error messages (last 10 minutes):${NC}"
  aws logs tail $LOG_GROUP \
    --since 10m \
    --region $REGION \
    --format short \
    --filter-pattern "ERROR" 2>/dev/null | head -20 || echo "No errors found in recent logs"
  
  echo ""
  echo -e "${BLUE}Recent logs (last 5 lines):${NC}"
  aws logs tail $LOG_GROUP \
    --since 5m \
    --region $REGION \
    --format short 2>/dev/null | tail -5 || echo "No recent logs"
else
  echo -e "${YELLOW}⚠ Log group not found: $LOG_GROUP${NC}"
  echo -e "${YELLOW}Logs may not be configured or service hasn't generated logs yet${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Diagnostic Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "${ENV_ERROR:-0}" == "1" ]; then
  echo -e "${RED}❌ ISSUE FOUND: Environment variables are missing or incorrect${NC}"
  echo ""
  echo -e "${YELLOW}To fix:${NC}"
  echo "1. Get your Agent ID and Alias ID:"
  echo "   aws bedrock-agent list-agents --region $REGION"
  echo "   aws bedrock-agent list-agent-aliases --agent-id <AGENT_ID> --region $REGION"
  echo ""
  echo "2. Update App Runner service (see TROUBLESHOOTING-APP-RUNNER.md for details)"
  echo ""
  exit 1
else
  echo -e "${GREEN}✅ Basic configuration looks good${NC}"
  echo ""
  echo -e "${YELLOW}If you're still getting errors:${NC}"
  echo "1. Check CloudWatch logs: aws logs tail $LOG_GROUP --follow --region $REGION"
  echo "2. Test Bedrock Agent directly with AWS CLI"
  echo "3. Verify network connectivity (if VPC is configured)"
  echo ""
  echo -e "${BLUE}For detailed troubleshooting, see: TROUBLESHOOTING-APP-RUNNER.md${NC}"
fi

