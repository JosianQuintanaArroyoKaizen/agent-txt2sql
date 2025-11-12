#!/bin/bash

##############################################################################
# Deploy Streamlit App to AWS App Runner
# This script builds a Docker image, pushes it to ECR, and creates/updates
# an App Runner service
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="${AWS_REGION:-eu-central-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
ALIAS_BASE="${ALIAS:-txt2sql}"
ALIAS_FULL="${ALIAS_BASE}-${ENVIRONMENT}"
SERVICE_NAME="txt2sql-streamlit-${ENVIRONMENT}"
ECR_REPO_NAME="${SERVICE_NAME}"
IMAGE_TAG="latest"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Deploy Streamlit to AWS App Runner${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed.${NC}"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}ERROR: Docker is not installed.${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS credentials are not configured.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
ECR_REPO_URI="${ECR_REGISTRY}/${ECR_REPO_NAME}"

echo -e "${GREEN}✓ AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ Region: ${REGION}${NC}"
echo -e "${GREEN}✓ Service Name: ${SERVICE_NAME}${NC}"
echo -e "${GREEN}✓ ECR Repository: ${ECR_REPO_URI}${NC}"
echo ""

# Get Agent ID and Alias ID - check environment variables first, then deployment-info.txt, then prompt
if [ -z "${AGENT_ID}" ]; then
    if [ -f "deployment-info.txt" ]; then
        AGENT_ID=$(grep "Bedrock Agent ID:" deployment-info.txt | awk '{print $NF}' || echo "")
    fi
fi

if [ -z "${AGENT_ALIAS_ID}" ]; then
    if [ -f "deployment-info.txt" ]; then
        AGENT_ALIAS_ID=$(grep "Agent Alias ID:" deployment-info.txt | awk '{print $NF}' || echo "")
    fi
fi

# Validate and prompt if needed
if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" == "None" ] || [ "$AGENT_ID" == "ACCESS_DENIED" ]; then
    echo -e "${YELLOW}⚠ Agent ID not found${NC}"
    read -p "Enter your Bedrock Agent ID: " AGENT_ID
fi

if [ -z "$AGENT_ALIAS_ID" ] || [ "$AGENT_ALIAS_ID" == "ACCESS_DENIED" ] || [ "$AGENT_ALIAS_ID" == "UNKNOWN" ]; then
    echo -e "${YELLOW}⚠ Agent Alias ID not found${NC}"
    read -p "Enter your Bedrock Agent Alias ID: " AGENT_ALIAS_ID
fi

echo -e "${GREEN}✓ Agent ID: ${AGENT_ID}${NC}"
echo -e "${GREEN}✓ Agent Alias ID: ${AGENT_ALIAS_ID}${NC}"
echo ""

# Step 1: Create ECR repository if it doesn't exist
echo -e "${BLUE}[1/5] Checking ECR repository...${NC}"
if ! aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" --region "${REGION}" &> /dev/null; then
    echo -e "${YELLOW}Creating ECR repository ${ECR_REPO_NAME}...${NC}"
    aws ecr create-repository \
        --repository-name "${ECR_REPO_NAME}" \
        --region "${REGION}" \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
    echo -e "${GREEN}✓ ECR repository created${NC}"
else
    echo -e "${GREEN}✓ ECR repository exists${NC}"
fi

# Step 2: Login to ECR
echo -e "${BLUE}[2/5] Logging in to ECR...${NC}"
aws ecr get-login-password --region "${REGION}" | \
    docker login --username AWS --password-stdin "${ECR_REGISTRY}"
echo -e "${GREEN}✓ Logged in to ECR${NC}"

# Step 3: Build Docker image
echo -e "${BLUE}[3/5] Building Docker image...${NC}"
cd streamlit_app
docker build -t "${SERVICE_NAME}:${IMAGE_TAG}" .
echo -e "${GREEN}✓ Docker image built${NC}"

# Step 4: Tag and push to ECR
echo -e "${BLUE}[4/5] Pushing image to ECR...${NC}"
docker tag "${SERVICE_NAME}:${IMAGE_TAG}" "${ECR_REPO_URI}:${IMAGE_TAG}"
docker push "${ECR_REPO_URI}:${IMAGE_TAG}"
echo -e "${GREEN}✓ Image pushed to ECR${NC}"
cd ..

# Step 5: Create or update App Runner service
echo -e "${BLUE}[5/5] Creating/updating App Runner service...${NC}"

# Create service configuration JSON
SERVICE_CONFIG=$(cat <<EOF
{
  "ServiceName": "${SERVICE_NAME}",
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "${ECR_REPO_URI}:${IMAGE_TAG}",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8501",
        "RuntimeEnvironmentVariables": {
          "AWS_REGION": "${REGION}",
          "AGENT_ID": "${AGENT_ID}",
          "AGENT_ALIAS_ID": "${AGENT_ALIAS_ID}"
        }
      }
    },
    "AutoDeploymentsEnabled": true
  },
  "InstanceConfiguration": {
    "Cpu": "0.25 vCPU",
    "Memory": "0.5 GB"
  },
  "AutoScalingConfigurationArn": ""
}
EOF
)

# Check if service exists
if aws apprunner describe-service --service-arn "arn:aws:apprunner:${REGION}:${ACCOUNT_ID}:service/${SERVICE_NAME}" --region "${REGION}" &> /dev/null 2>&1; then
    echo -e "${YELLOW}Service exists, updating...${NC}"
    # For update, we need to use start-deployment after updating source
    SERVICE_ARN=$(aws apprunner list-services --region "${REGION}" --query "ServiceSummaryList[?ServiceName=='${SERVICE_NAME}'].ServiceArn" --output text)
    
    # Update source configuration
    UPDATE_CONFIG=$(cat <<EOF
{
  "ImageRepository": {
    "ImageIdentifier": "${ECR_REPO_URI}:${IMAGE_TAG}",
    "ImageRepositoryType": "ECR",
    "ImageConfiguration": {
      "Port": "8501",
      "RuntimeEnvironmentVariables": {
        "AWS_REGION": "${REGION}",
        "AGENT_ID": "${AGENT_ID}",
        "AGENT_ALIAS_ID": "${AGENT_ALIAS_ID}"
      }
    }
  },
  "AutoDeploymentsEnabled": true
}
EOF
)
    
    aws apprunner update-service \
        --service-arn "${SERVICE_ARN}" \
        --source-configuration "${UPDATE_CONFIG}" \
        --region "${REGION}" > /dev/null
    
    echo -e "${GREEN}✓ Service updated. Deployment started automatically.${NC}"
else
    echo -e "${YELLOW}Creating new service...${NC}"
    SERVICE_ARN=$(aws apprunner create-service \
        --cli-input-json "${SERVICE_CONFIG}" \
        --region "${REGION}" \
        --query 'Service.ServiceArn' \
        --output text)
    echo -e "${GREEN}✓ Service created${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Deployment Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Your App Runner service is being deployed...${NC}"
echo ""
echo -e "Service ARN: ${SERVICE_ARN}"
echo ""
echo -e "To get your permanent URL, run:"
echo -e "${GREEN}aws apprunner describe-service --service-arn ${SERVICE_ARN} --region ${REGION} --query 'Service.ServiceUrl' --output text${NC}"
echo ""
echo -e "Or check the AWS Console:"
echo -e "${GREEN}https://console.aws.amazon.com/apprunner/home?region=${REGION}#/services${NC}"
echo ""
echo -e "${YELLOW}Note: It may take 5-10 minutes for the service to become available.${NC}"

