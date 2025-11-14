#!/bin/bash
# Deploy Streamlit to ECS with ALB
# This provides a constant URL, always-running service, and WebSocket support

set -e

# Configuration
REGION="${AWS_REGION:-eu-central-1}"
ALIAS="${ALIAS:-txt2sql-dev}"
ECR_REPO="${ECR_REPO:-txt2sql-streamlit-dev}"
STACK_NAME="${ALIAS}-ecs-alb-streamlit-stack"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Deploying Streamlit to ECS with ALB ===${NC}"

# Get Agent ID and Alias ID
echo -e "${YELLOW}Getting Bedrock Agent information...${NC}"
AGENT_ID=$(aws bedrock-agent list-agents --region $REGION --query 'agentSummaries[0].agentId' --output text 2>/dev/null || echo "")
if [ -z "$AGENT_ID" ]; then
  echo -e "${RED}Error: Could not find Bedrock Agent. Please provide AGENT_ID environment variable.${NC}"
  exit 1
fi

AGENT_ALIAS_ID=$(aws bedrock-agent list-agent-aliases --agent-id "$AGENT_ID" --region $REGION --query 'agentAliasSummaries[0].agentAliasId' --output text 2>/dev/null || echo "")
if [ -z "$AGENT_ALIAS_ID" ]; then
  echo -e "${RED}Error: Could not find Bedrock Agent Alias. Please provide AGENT_ALIAS_ID environment variable.${NC}"
  exit 1
fi

echo -e "${GREEN}Found Agent ID: $AGENT_ID${NC}"
echo -e "${GREEN}Found Alias ID: $AGENT_ALIAS_ID${NC}"

# Get default VPC and subnets (or use provided)
if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ]; then
  echo -e "${YELLOW}Auto-detecting VPC and subnet information...${NC}"
  VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
  if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
    echo -e "${RED}Error: No default VPC found. Please set VPC_ID and SUBNET_IDS environment variables.${NC}"
    echo -e "${YELLOW}Example: export VPC_ID=vpc-xxxxx && export SUBNET_IDS=subnet-xxxxx,subnet-yyyyy${NC}"
    exit 1
  fi
  echo -e "${GREEN}Found default VPC: $VPC_ID${NC}"
  
  # Get public subnets from default VPC
  SUBNET_IDS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',' 2>/dev/null || echo "")
  if [ -z "$SUBNET_IDS" ]; then
    # Fallback to all subnets
    SUBNET_IDS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',' 2>/dev/null || echo "")
  fi
  if [ -z "$SUBNET_IDS" ]; then
    echo -e "${RED}Error: Could not find subnets in VPC $VPC_ID${NC}"
    exit 1
  fi
  echo -e "${GREEN}Using subnets: $SUBNET_IDS${NC}"
else
  echo -e "${GREEN}Using provided VPC: $VPC_ID${NC}"
  echo -e "${GREEN}Using provided subnets: $SUBNET_IDS${NC}"
fi

# Ensure ECR repository exists
echo -e "${YELLOW}Checking ECR repository...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO}"

if ! aws ecr describe-repositories --repository-names "$ECR_REPO" --region $REGION &>/dev/null; then
  echo -e "${YELLOW}Creating ECR repository...${NC}"
  aws ecr create-repository \
    --repository-name "$ECR_REPO" \
    --region $REGION \
    --image-scanning-configuration scanOnPush=true
fi

# Build and push Docker image
echo -e "${YELLOW}Building and pushing Docker image...${NC}"
cd "$(dirname "$0")/../streamlit_app"

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Build image
docker build -t "$ECR_REPO:latest" .

# Tag and push
docker tag "$ECR_REPO:latest" "$ECR_URI:latest"
docker push "$ECR_URI:latest"

cd - > /dev/null

# Deploy CloudFormation stack
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
  --template-file cfn/4-ecs-alb-streamlit-template.yaml \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    Alias="$ALIAS" \
    ECRRepository="$ECR_REPO" \
    AgentId="$AGENT_ID" \
    AgentAliasId="$AGENT_ALIAS_ID" \
    VpcId="${VPC_ID:-}" \
    SubnetIds="${SUBNET_IDS:-}" \
  --capabilities CAPABILITY_IAM \
  --region $REGION

# Get the ALB URL
echo -e "${YELLOW}Getting ALB URL...${NC}"
ALB_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text)

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text)

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo -e "${GREEN}Your Streamlit app is available at:${NC}"
echo -e "${GREEN}  ${ALB_URL}${NC}"
echo -e "${GREEN}  (DNS: ${ALB_DNS})${NC}"
echo ""
echo -e "${YELLOW}Note: This URL is permanent and will not change.${NC}"
echo -e "${YELLOW}The app is always running and supports WebSocket connections.${NC}"
echo ""
echo -e "${YELLOW}To update the app, just rebuild and push the image, then update the ECS service:${NC}"
echo -e "  cd streamlit_app && docker build -t $ECR_REPO:latest ."
echo -e "  docker tag $ECR_REPO:latest $ECR_URI:latest"
echo -e "  docker push $ECR_URI:latest"
echo -e "  aws ecs update-service --cluster ${ALIAS}-streamlit-cluster --service ${ALIAS}-streamlit-service --force-new-deployment --region $REGION"

