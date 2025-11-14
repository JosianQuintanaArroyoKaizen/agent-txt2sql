#!/bin/bash

##############################################################################
# Setup IAM Role for App Runner with Bedrock Permissions
# Creates an IAM role and updates App Runner service to use it
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
ROLE_NAME="AppRunner-Bedrock-Access-${SERVICE_NAME}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Setup App Runner IAM Role${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Get App Runner service ARN
echo -e "${YELLOW}[1/5] Finding App Runner service...${NC}"
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

# 2. Check if role already exists
echo -e "${YELLOW}[2/5] Checking for existing IAM role...${NC}"
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo -e "${GREEN}✅ Role already exists: $ROLE_NAME${NC}"
  ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
  echo -e "${GREEN}Role ARN: $ROLE_ARN${NC}"
else
  echo -e "${YELLOW}Creating new IAM role...${NC}"
  
  # Create trust policy for App Runner
  TRUST_POLICY='{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "tasks.apprunner.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'
  
  # Create the role
  ROLE_ARN=$(aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --query 'Role.Arn' \
    --output text)
  
  echo -e "${GREEN}✅ Created role: $ROLE_NAME${NC}"
  echo -e "${GREEN}Role ARN: $ROLE_ARN${NC}"
fi
echo ""

# 3. Attach Bedrock permissions
echo -e "${YELLOW}[3/5] Attaching Bedrock permissions...${NC}"

# Create inline policy for Bedrock access
BEDROCK_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeAgent",
        "bedrock-runtime:InvokeAgent",
        "bedrock:InvokeModel",
        "bedrock-runtime:InvokeModel"
      ],
      "Resource": "*"
    }
  ]
}'

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "BedrockAgentAccess" \
  --policy-document "$BEDROCK_POLICY" > /dev/null

echo -e "${GREEN}✅ Bedrock permissions attached${NC}"
echo ""

# 4. Get current service configuration
echo -e "${YELLOW}[4/5] Getting current service configuration...${NC}"
SERVICE_CONFIG=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --output json)

IMAGE_IDENTIFIER=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.ImageIdentifier')
IMAGE_REPO_TYPE=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.ImageRepositoryType')
ACCESS_ROLE_ARN=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.AuthenticationConfiguration.AccessRoleArn // empty')
AUTO_DEPLOY=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.AutoDeploymentsEnabled // false')
ENV_VARS=$(echo $SERVICE_CONFIG | jq -r '.Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables // {}')

echo -e "${GREEN}✅ Current configuration retrieved${NC}"
echo ""

# 5. Update App Runner service with instance role
echo -e "${YELLOW}[5/5] Updating App Runner service with instance role...${NC}"

# Build the update command - match the exact structure from describe-service
UPDATE_JSON=$(cat <<EOF
{
  "ImageRepository": {
    "ImageIdentifier": "$IMAGE_IDENTIFIER",
    "ImageRepositoryType": "$IMAGE_REPO_TYPE",
    "ImageConfiguration": {
      "Port": "8501",
      "RuntimeEnvironmentVariables": $(echo $ENV_VARS | jq -c .)
    }
  },
  "AutoDeploymentsEnabled": $AUTO_DEPLOY
}
EOF
)

# Add authentication if it exists
if [ -n "$ACCESS_ROLE_ARN" ] && [ "$ACCESS_ROLE_ARN" != "null" ] && [ "$ACCESS_ROLE_ARN" != "" ]; then
  UPDATE_JSON=$(echo $UPDATE_JSON | jq ".AuthenticationConfiguration = {\"AccessRoleArn\": \"$ACCESS_ROLE_ARN\"}")
fi

# Save to temp file
echo $UPDATE_JSON > /tmp/apprunner-update.json

# Update the service
echo -e "${BLUE}Updating service with instance role: $ROLE_ARN${NC}"

UPDATE_RESULT=$(aws apprunner update-service \
  --service-arn $SERVICE_ARN \
  --region $REGION \
  --source-configuration file:///tmp/apprunner-update.json \
  --instance-configuration "InstanceRoleArn=$ROLE_ARN" \
  --output json)

OPERATION_ID=$(echo $UPDATE_RESULT | jq -r '.OperationId')

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
  echo -e "${GREEN}✅ IAM Role configured!${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  echo -e "${GREEN}Role ARN: $ROLE_ARN${NC}"
  echo -e "${GREEN}Role Name: $ROLE_NAME${NC}"
  echo ""
  echo -e "${YELLOW}Your App Runner service now has Bedrock permissions.${NC}"
  echo -e "${YELLOW}Test it at: $(echo $SERVICE_CONFIG | jq -r '.Service.ServiceUrl')${NC}"
  
else
  echo -e "${RED}❌ Failed to initiate update${NC}"
  echo $UPDATE_RESULT | jq .
  exit 1
fi

