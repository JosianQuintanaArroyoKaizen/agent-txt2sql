#!/bin/bash

# Script to generate frontend config from CloudFormation stack outputs
# Usage: ./generate-config.sh <environment> <region>

ENVIRONMENT=${1:-dev}
REGION=${2:-eu-central-1}
STACK_NAME="${ENVIRONMENT}-${REGION}-bedrock-agent-lambda-stack"

echo "Fetching configuration from stack: $STACK_NAME in $REGION..."

# Get stack outputs
AGENT_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`AgentId`].OutputValue' \
  --output text)

AGENT_ALIAS_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`AgentAliasId`].OutputValue' \
  --output text)

if [ -z "$AGENT_ID" ] || [ -z "$AGENT_ALIAS_ID" ]; then
  echo "Error: Could not retrieve agent configuration from stack"
  exit 1
fi

# Generate config.js
cat > config.js << EOF
// Auto-generated configuration from CloudFormation stack: $STACK_NAME
// Generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
// DO NOT EDIT MANUALLY - Run generate-config.sh to update

window.AGENT_CONFIG = {
    environment: '${ENVIRONMENT}',
    agentId: '${AGENT_ID}',
    agentAliasId: '${AGENT_ALIAS_ID}',
    awsRegion: '${REGION}'
};
EOF

echo "✓ Configuration generated successfully!"
echo ""
echo "Agent ID: $AGENT_ID"
echo "Agent Alias ID: $AGENT_ALIAS_ID"
echo "Region: $REGION"
echo ""
echo "Config file written to: config.js"
