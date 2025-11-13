#!/bin/bash

# Fix Lambda permissions to invoke Bedrock Agent

REGION="eu-central-1"
ACCOUNT_ID="194561596031"
ROLE_NAME="txt2sql-frontend-lambda-role"
AGENT_ID="G1RWZFEZ4O"

echo "Adding Bedrock Agent invoke permission to Lambda role..."

# Create policy document
cat > /tmp/bedrock-agent-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeAgent",
        "bedrock:InvokeModel"
      ],
      "Resource": [
        "arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:agent/${AGENT_ID}",
        "arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:agent-alias/${AGENT_ID}/*",
        "arn:aws:bedrock:*::foundation-model/*"
      ]
    }
  ]
}
EOF

# Add inline policy to Lambda role
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "BedrockAgentInvokePolicy" \
  --policy-document file:///tmp/bedrock-agent-policy.json \
  --region "$REGION"

if [ $? -eq 0 ]; then
    echo "✅ Successfully added Bedrock Agent invoke permission"
    echo ""
    echo "Lambda role now has permission to:"
    echo "  - bedrock:InvokeAgent on agent ${AGENT_ID}"
    echo "  - bedrock:InvokeModel on foundation models"
    echo ""
    echo "Test again from frontend:"
    echo "http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com"
else
    echo "❌ Failed to add policy"
    exit 1
fi
