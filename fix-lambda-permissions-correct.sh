#!/bin/bash

# Fix Lambda permissions with correct service name: bedrock-runtime

REGION="eu-central-1"
ACCOUNT_ID="194561596031"
ROLE_NAME="txt2sql-frontend-lambda-role"
AGENT_ID="G1RWZFEZ4O"

echo "Updating Bedrock Agent invoke permission with correct service name..."

# Create policy document with BOTH bedrock and bedrock-runtime
cat > /tmp/bedrock-agent-policy-fixed.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeAgent",
        "bedrock-runtime:InvokeModel",
        "bedrock-runtime:InvokeAgent"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Update inline policy
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "BedrockAgentInvokePolicy" \
  --policy-document file:///tmp/bedrock-agent-policy-fixed.json \
  --region "$REGION"

if [ $? -eq 0 ]; then
    echo "✅ Successfully updated Bedrock permissions with correct service names"
    echo ""
    echo "Lambda role now has permission to:"
    echo "  - bedrock:InvokeAgent"
    echo "  - bedrock:InvokeModel"
    echo "  - bedrock-runtime:InvokeAgent (CRITICAL)"
    echo "  - bedrock-runtime:InvokeModel"
    echo ""
    echo "Wait 10-30 seconds for IAM to propagate, then test:"
    echo "http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com"
else
    echo "❌ Failed to update policy"
    exit 1
fi
