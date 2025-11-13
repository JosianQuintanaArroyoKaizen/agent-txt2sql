#!/bin/bash

##############################################################################
# Fix App Runner Environment Variables
# Updates App Runner service with AGENT_ID and AGENT_ALIAS_ID
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
ENVIRONMENT="${ENVIRONMENT:-dev}"
STACK_SUFFIX="${ENVIRONMENT}-${REGION}"
STACK_NAME_2="${STACK_SUFFIX}-bedrock-agent-lambda-stack"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Fix App Runner Environment Variables${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Get App Runner service ARN
echo -e "${YELLOW}[1/4] Finding App Runner service...${NC}"
SERVICE_ARN=$(aws apprunner list-services \
  --region $REGION \
  --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn" \
  --output text 2>/dev/null || echo "")

if [ -z "$SERVICE_ARN" ]; then
  echo -e "${RED}❌ Service not found: $SERVICE_NAME${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Service ARN: $SERVICE_ARN${NC}"
echo ""

# 2. Get current service configuration
echo -e "${YELLOW}[2/4] Getting current service configuration...${NC}"
SERVICE_CONFIG=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --output json)

# Extract current image configuration
IMAGE_IDENTIFIER=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.ImageIdentifier')
IMAGE_REPO_TYPE=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.ImageRepositoryType')
ACCESS_ROLE_ARN=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.AuthenticationConfiguration.AccessRoleArn // empty')
AUTO_DEPLOY=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.AutoDeploymentsEnabled // false')

echo -e "${GREEN}✅ Image: $IMAGE_IDENTIFIER${NC}"
echo ""

# 3. Get Agent ID and Alias ID from CloudFormation stack
echo -e "${YELLOW}[3/4] Getting Bedrock Agent ID and Alias ID...${NC}"

# Try to get from CloudFormation stack
AGENT_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME_2" \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`BedrockAgentName`].OutputValue' \
  --output text 2>/dev/null || echo "")

if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" == "None" ]; then
  echo -e "${YELLOW}⚠ Could not get Agent ID from CloudFormation stack${NC}"
  echo -e "${YELLOW}Trying to list agents directly...${NC}"
  AGENT_ID=$(aws bedrock-agent list-agents \
    --region $REGION \
    --query 'agentSummaries[0].agentId' \
    --output text 2>/dev/null || echo "")
fi

if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" == "None" ]; then
  echo -e "${RED}❌ Could not find Bedrock Agent ID${NC}"
  echo -e "${YELLOW}Please provide your Agent ID manually:${NC}"
  read -p "Agent ID: " AGENT_ID
  if [ -z "$AGENT_ID" ]; then
    echo -e "${RED}Agent ID is required. Exiting.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✅ Agent ID: $AGENT_ID${NC}"
fi

# Get Agent Alias ID
AGENT_ALIAS_ID=$(aws bedrock-agent list-agent-aliases \
  --agent-id "$AGENT_ID" \
  --region $REGION \
  --query 'agentAliasSummaries[0].agentAliasId' \
  --output text 2>/dev/null || echo "")

if [ -z "$AGENT_ALIAS_ID" ] || [ "$AGENT_ALIAS_ID" == "None" ]; then
  echo -e "${YELLOW}⚠ Could not get Agent Alias ID automatically${NC}"
  echo -e "${YELLOW}Please provide your Agent Alias ID manually:${NC}"
  read -p "Agent Alias ID: " AGENT_ALIAS_ID
  if [ -z "$AGENT_ALIAS_ID" ]; then
    echo -e "${RED}Agent Alias ID is required. Exiting.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✅ Agent Alias ID: $AGENT_ALIAS_ID${NC}"
fi
echo ""

# 4. Update App Runner service
echo -e "${YELLOW}[4/4] Updating App Runner service...${NC}"

# Build the update command
UPDATE_CMD="aws apprunner update-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --source-configuration '{
    \"ImageRepository\": {
      \"ImageIdentifier\": \"$IMAGE_IDENTIFIER\",
      \"ImageRepositoryType\": \"$IMAGE_REPO_TYPE\""

# Add authentication if it exists
if [ -n "$ACCESS_ROLE_ARN" ] && [ "$ACCESS_ROLE_ARN" != "null" ]; then
  UPDATE_CMD="$UPDATE_CMD,
      \"AuthenticationConfiguration\": {
        \"AccessRoleArn\": \"$ACCESS_ROLE_ARN\"
      }"
fi

# Add image configuration with environment variables
UPDATE_CMD="$UPDATE_CMD,
      \"ImageConfiguration\": {
        \"Port\": \"8501\",
        \"RuntimeEnvironmentVariables\": {
          \"AWS_REGION\": \"$REGION\",
          \"AGENT_ID\": \"$AGENT_ID\",
          \"AGENT_ALIAS_ID\": \"$AGENT_ALIAS_ID\"
        }
      }
    },
    \"AutoDeploymentsEnabled\": $AUTO_DEPLOY
  }'"

echo -e "${BLUE}Updating service with:${NC}"
echo "  AGENT_ID: $AGENT_ID"
echo "  AGENT_ALIAS_ID: $AGENT_ALIAS_ID"
echo "  AWS_REGION: $REGION"
echo ""

# Execute the update
eval $UPDATE_CMD > /tmp/apprunner-update.json

OPERATION_ID=$(cat /tmp/apprunner-update.json | jq -r '.OperationId')

if [ -n "$OPERATION_ID" ] && [ "$OPERATION_ID" != "null" ]; then
  echo -e "${GREEN}✅ Update initiated successfully${NC}"
  echo -e "${GREEN}Operation ID: $OPERATION_ID${NC}"
  echo ""
  echo -e "${YELLOW}⏳ Waiting for update to complete (this may take 5-10 minutes)...${NC}"
  
  # Wait for the update to complete
  MAX_WAIT=600  # 10 minutes
  WAIT_INTERVAL=30
  ELAPSED=0
  
  while [ $ELAPSED -lt $MAX_WAIT ]; do
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
    
    STATUS=$(aws apprunner describe-service \
      --service-arn $SERVICE_ARN \
      --region $REGION \
      --query 'Service.Status' \
      --output text)
    
    echo -e "${BLUE}Status: $STATUS (${ELAPSED}s elapsed)${NC}"
    
    if [ "$STATUS" == "RUNNING" ]; then
      # Check if there's an active operation
      ACTIVE_OPS=$(aws apprunner list-operations \
        --service-arn $SERVICE_ARN \
        --region $REGION \
        --query 'OperationSummaryList[?Status==`IN_PROGRESS`] | length(@)' \
        --output text)
      
      if [ "$ACTIVE_OPS" == "0" ]; then
        echo -e "${GREEN}✅ Update completed successfully!${NC}"
        break
      fi
    fi
  done
  
  if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${YELLOW}⚠ Update is taking longer than expected${NC}"
    echo -e "${YELLOW}Check status manually:${NC}"
    echo "  aws apprunner describe-service --service-arn $SERVICE_ARN --region $REGION"
  fi
  
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${GREEN}✅ Environment variables updated!${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  echo -e "${YELLOW}Your App Runner service should now work correctly.${NC}"
  echo -e "${YELLOW}Test it at: $(echo $SERVICE_CONFIG | jq -r '.Service.ServiceUrl')${NC}"
  echo ""
  echo -e "${BLUE}Note: If you still see errors, check:${NC}"
  echo "  1. IAM permissions for Bedrock (see TROUBLESHOOTING-APP-RUNNER.md)"
  echo "  2. CloudWatch logs for detailed error messages"
  
else
  echo -e "${RED}❌ Failed to initiate update${NC}"
  cat /tmp/apprunner-update.json
  exit 1
fi

