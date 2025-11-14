#!/bin/bash
# Simple EC2 + Elastic IP deployment - Works with single subnet!

set -e

REGION="${AWS_REGION:-eu-central-1}"
ALIAS="${ALIAS:-txt2sql-dev}"
STACK_NAME="${ALIAS}-ec2-simple-streamlit-stack"

echo "=== Deploying Streamlit to EC2 with Elastic IP ==="

# Get Agent IDs
AGENT_ID=$(aws bedrock-agent list-agents --region $REGION --query 'agentSummaries[0].agentId' --output text)
AGENT_ALIAS_ID=$(aws bedrock-agent list-agent-aliases --agent-id "$AGENT_ID" --region $REGION --query 'agentAliasSummaries[0].agentAliasId' --output text)

echo "Agent ID: $AGENT_ID"
echo "Alias ID: $AGENT_ALIAS_ID"

# Get VPC and subnet (only one subnet needed!)
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text)

echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"

# Deploy
aws cloudformation deploy \
  --template-file cfn/6-ec2-elasticip-streamlit-template.yaml \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    Alias="$ALIAS" \
    AgentId="$AGENT_ID" \
    AgentAliasId="$AGENT_ALIAS_ID" \
    VpcId="$VPC_ID" \
    SubnetId="$SUBNET_ID" \
  --capabilities CAPABILITY_IAM \
  --region $REGION

# Get URL
STREAMLIT_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`StreamlitURL`].OutputValue' \
  --output text)

EIP=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ElasticIP`].OutputValue' \
  --output text)

echo ""
echo "=== Deployment Complete! ==="
echo "Your Streamlit app is available at:"
echo "  $STREAMLIT_URL"
echo ""
echo "Elastic IP: $EIP"
echo "This IP address is permanent and will not change."
echo ""
echo "Note: You may need to wait 2-3 minutes for the app to start."

