#!/bin/bash

##############################################################################
# Amazon Bedrock Text2SQL Agent - CloudFormation Deployment Script
# This script deploys all three CloudFormation stacks in the correct order
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="${AWS_REGION:-us-west-2}"
ALIAS="${ALIAS:-txt2sql-demo}"
STACK_NAME_1="athena-glue-s3-stack"
STACK_NAME_2="bedrock-agent-lambda-stack"
STACK_NAME_3="ec2-streamlit-stack"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Bedrock Text2SQL Agent Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS credentials are not configured.${NC}"
    echo -e "${YELLOW}Please run: aws configure${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ Region: ${REGION}${NC}"
echo -e "${GREEN}✓ Alias: ${ALIAS}${NC}"
echo ""

# Function to wait for stack completion
wait_for_stack() {
    local stack_name=$1
    local operation=$2
    echo -e "${YELLOW}Waiting for stack ${stack_name} to ${operation}...${NC}"
    aws cloudformation wait stack-${operation}-complete \
        --stack-name "${stack_name}" \
        --region "${REGION}" || {
        echo -e "${RED}Stack ${operation} failed. Check CloudFormation console for details.${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ Stack ${stack_name} ${operation}d successfully${NC}"
}

# Deploy Stack 1: Athena, Glue, and S3
echo -e "${BLUE}[1/3] Deploying Athena, Glue, and S3 Stack...${NC}"
aws cloudformation deploy \
    --template-file cfn/1-athena-glue-s3-template.yaml \
    --stack-name "${STACK_NAME_1}" \
    --parameter-overrides \
        Alias="${ALIAS}" \
        AthenaDatabaseName="athena_db" \
    --capabilities CAPABILITY_IAM \
    --region "${REGION}"

wait_for_stack "${STACK_NAME_1}" "create-or-update"

# Get outputs from Stack 1
S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME_1}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text)

ATHENA_OUTPUT_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME_1}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`AthenaOutputBucketName`].OutputValue' \
    --output text)

echo -e "${GREEN}✓ S3 Data Bucket: ${S3_BUCKET}${NC}"
echo -e "${GREEN}✓ Athena Output Bucket: ${ATHENA_OUTPUT_BUCKET}${NC}"
echo ""

# Deploy Stack 2: Bedrock Agent and Lambda
echo -e "${BLUE}[2/3] Deploying Bedrock Agent and Lambda Stack...${NC}"

# Use EU inference profile for EU regions (GDPR compliance)
if [[ "${REGION}" == eu-* ]]; then
    MODEL_ID="eu.anthropic.claude-3-haiku-20240307-v1:0"
    echo -e "${GREEN}Using EU inference profile for GDPR compliance: ${MODEL_ID}${NC}"
else
    MODEL_ID="anthropic.claude-3-haiku-20240307-v1:0"
fi

aws cloudformation deploy \
    --template-file cfn/2-bedrock-agent-lambda-template.yaml \
    --stack-name "${STACK_NAME_2}" \
    --parameter-overrides \
        Alias="${ALIAS}" \
        FoundationModel="${MODEL_ID}" \
    --capabilities CAPABILITY_IAM \
    --region "${REGION}"

wait_for_stack "${STACK_NAME_2}" "create-or-update"

# Get outputs from Stack 2
AGENT_ID=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME_2}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`BedrockAgentName`].OutputValue' \
    --output text)

# Get Agent Alias ID
AGENT_ALIAS_ID=$(aws bedrock-agent list-agent-aliases \
    --agent-id "${AGENT_ID}" \
    --region "${REGION}" \
    --query 'agentAliasSummaries[0].agentAliasId' \
    --output text)

echo -e "${GREEN}✓ Bedrock Agent ID: ${AGENT_ID}${NC}"
echo -e "${GREEN}✓ Bedrock Agent Alias ID: ${AGENT_ALIAS_ID}${NC}"
echo ""

# Deploy Stack 3: EC2 with Streamlit
echo -e "${BLUE}[3/3] Deploying EC2 Instance with Streamlit...${NC}"

# Set EC2 Instance Connect CIDR based on region
case "${REGION}" in
    us-west-2)      SSH_CIDR="18.237.140.160/29" ;;
    us-east-1)      SSH_CIDR="18.206.107.24/29" ;;
    eu-central-1)   SSH_CIDR="3.120.181.40/29" ;;
    eu-west-1)      SSH_CIDR="18.202.216.48/29" ;;
    eu-west-2)      SSH_CIDR="3.8.37.24/29" ;;
    ap-southeast-1) SSH_CIDR="3.0.5.32/29" ;;
    ap-northeast-1) SSH_CIDR="3.112.23.0/29" ;;
    *)              SSH_CIDR="18.237.140.160/29" ;;  # Default to us-west-2
esac

echo -e "${GREEN}Using EC2 Instance Connect CIDR for ${REGION}: ${SSH_CIDR}${NC}"

aws cloudformation deploy \
    --template-file cfn/3-ec2-streamlit-template.yaml \
    --stack-name "${STACK_NAME_3}" \
    --parameter-overrides \
        InstanceType="t3.small" \
        SSHRegionIPsAllowed="${SSH_CIDR}" \
        MapPublicIpOnLaunch="true" \
    --capabilities CAPABILITY_IAM \
    --region "${REGION}"

wait_for_stack "${STACK_NAME_3}" "create-or-update"

# Get EC2 instance details
INSTANCE_ID=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME_3}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
    --output text)

PUBLIC_DNS=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME_3}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`PublicDnsName`].OutputValue' \
    --output text)

echo -e "${GREEN}✓ EC2 Instance ID: ${INSTANCE_ID}${NC}"
echo -e "${GREEN}✓ Public DNS: ${PUBLIC_DNS}${NC}"
echo ""

# Display summary and next steps
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Deployment Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Configure Streamlit App${NC}"
echo ""
echo -e "1. Connect to EC2 instance:"
echo -e "   ${GREEN}aws ec2-instance-connect ssh --instance-id ${INSTANCE_ID} --region ${REGION}${NC}"
echo ""
echo -e "2. Edit the Streamlit configuration:"
echo -e "   ${GREEN}sudo vi /home/ubuntu/app/streamlit_app/invoke_agent.py${NC}"
echo ""
echo -e "3. Update the following lines:"
echo -e "   ${GREEN}agentId = \"${AGENT_ID}\"${NC}"
echo -e "   ${GREEN}agentAliasId = \"${AGENT_ALIAS_ID}\"${NC}"
echo ""
echo -e "4. Start the Streamlit app:"
echo -e "   ${GREEN}streamlit run /home/ubuntu/app/streamlit_app/app.py${NC}"
echo ""
echo -e "5. Access the app at:"
echo -e "   ${GREEN}http://${PUBLIC_DNS}:8501${NC}"
echo ""
echo -e "${YELLOW}Resources Created:${NC}"
echo -e "  • S3 Data Bucket: ${S3_BUCKET}"
echo -e "  • Athena Output Bucket: ${ATHENA_OUTPUT_BUCKET}"
echo -e "  • Bedrock Agent ID: ${AGENT_ID}"
echo -e "  • Agent Alias ID: ${AGENT_ALIAS_ID}"
echo -e "  • EC2 Instance: ${INSTANCE_ID}"
echo ""
echo -e "${YELLOW}To test the agent in AWS Console:${NC}"
echo -e "  Navigate to Amazon Bedrock > Agents > ${AGENT_ID}"
echo ""
echo -e "${GREEN}Deployment information saved to deployment-info.txt${NC}"

# Save deployment info to file
cat > deployment-info.txt <<EOF
===========================================
Bedrock Text2SQL Agent - Deployment Info
===========================================
Deployment Date: $(date)
AWS Region: ${REGION}
AWS Account: ${ACCOUNT_ID}
Alias: ${ALIAS}

Stack Names:
  - Stack 1: ${STACK_NAME_1}
  - Stack 2: ${STACK_NAME_2}
  - Stack 3: ${STACK_NAME_3}

Resources:
  - S3 Data Bucket: ${S3_BUCKET}
  - Athena Output Bucket: ${ATHENA_OUTPUT_BUCKET}
  - Athena Database: athena_db
  - Bedrock Agent ID: ${AGENT_ID}
  - Agent Alias ID: ${AGENT_ALIAS_ID}
  - EC2 Instance ID: ${INSTANCE_ID}
  - Public DNS: ${PUBLIC_DNS}

Streamlit App URL: http://${PUBLIC_DNS}:8501

EC2 Connect Command:
  aws ec2-instance-connect ssh --instance-id ${INSTANCE_ID} --region ${REGION}

Cleanup Command:
  ./cleanup.sh
===========================================
EOF

echo ""
echo -e "${BLUE}For cleanup, run: ${GREEN}./cleanup.sh${NC}"
echo ""

