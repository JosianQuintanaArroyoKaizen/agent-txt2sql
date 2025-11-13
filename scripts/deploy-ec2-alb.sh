#!/bin/bash
# Simple EC2 + ALB deployment - This WILL work!

set -e

REGION="${AWS_REGION:-eu-central-1}"
ALIAS="${ALIAS:-txt2sql-dev}"
STACK_NAME="${ALIAS}-ec2-alb-streamlit-stack"
GITHUB_OWNER="${GITHUB_OWNER:-your-username}"
GITHUB_REPO="${GITHUB_REPO:-agent-txt2sql}"

echo "=== Deploying Streamlit to EC2 with ALB ==="

# Get Agent IDs
AGENT_ID=$(aws bedrock-agent list-agents --region $REGION --query 'agentSummaries[0].agentId' --output text)
AGENT_ALIAS_ID=$(aws bedrock-agent list-agent-aliases --agent-id "$AGENT_ID" --region $REGION --query 'agentAliasSummaries[0].agentAliasId' --output text)

echo "Agent ID: $AGENT_ID"
echo "Alias ID: $AGENT_ALIAS_ID"

# Get VPC and subnets (ALB needs at least 2 subnets in different AZs)
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --query 'Vpcs[0].VpcId' --output text)

# Get subnets, prioritizing public subnets, and ensure we have at least 2
SUBNET_LIST=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].[SubnetId,AvailabilityZone]' --output text | sort -k2)

# Count unique availability zones
AZ_COUNT=$(echo "$SUBNET_LIST" | awk '{print $2}' | sort -u | wc -l)
SUBNET_COUNT=$(echo "$SUBNET_LIST" | wc -l)

if [ "$AZ_COUNT" -lt 2 ] || [ "$SUBNET_COUNT" -lt 2 ]; then
  echo "ERROR: ALB requires at least 2 subnets in different availability zones."
  echo "Found $SUBNET_COUNT subnet(s) in $AZ_COUNT availability zone(s)."
  echo "Please create additional subnets in different AZs or use an existing VPC with multiple subnets."
  exit 1
fi

# Get first subnet from first AZ and first subnet from second AZ
SUBNET_IDS=$(echo "$SUBNET_LIST" | awk 'NR==1 {first=$1; first_az=$2} NR>1 && $2!=first_az {print first","$1; exit}')

# If we didn't get 2, just take first 2 subnets
if [ -z "$SUBNET_IDS" ]; then
  SUBNET_IDS=$(echo "$SUBNET_LIST" | head -2 | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
fi

echo "VPC: $VPC_ID"
echo "Subnets: $SUBNET_IDS"

# Deploy
aws cloudformation deploy \
  --template-file cfn/5-ec2-alb-streamlit-template.yaml \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    Alias="$ALIAS" \
    AgentId="$AGENT_ID" \
    AgentAliasId="$AGENT_ALIAS_ID" \
    VpcId="$VPC_ID" \
    SubnetIds="$SUBNET_IDS" \
  --capabilities CAPABILITY_IAM \
  --region $REGION

# Get URL
ALB_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text)

echo ""
echo "=== Deployment Complete! ==="
echo "Your Streamlit app is available at:"
echo "  $ALB_URL"
echo ""
echo "This URL is permanent and will not change."

