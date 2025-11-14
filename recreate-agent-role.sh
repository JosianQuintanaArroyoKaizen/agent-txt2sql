#!/bin/bash

# Recreate the Bedrock Agent Execution Role that was deleted during stack rollback

REGION="eu-central-1"
ACCOUNT_ID="194561596031"
ROLE_NAME="AmazonBedrockExecutionRoleForAgents_txt2sql_dev"
LAMBDA_FUNCTION="AthenaQueryLambda-txt2sql-dev-eu-central-1-194561596031"

echo "Creating Bedrock Agent Execution Role..."

# Create trust policy for Bedrock service
cat > /tmp/bedrock-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "bedrock.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/bedrock-trust-policy.json \
  --description "Execution role for Bedrock Agent txt2sql-dev" \
  --region "$REGION"

# Attach AmazonBedrockFullAccess managed policy
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess \
  --region "$REGION"

# Create inline policy for Lambda invocation
cat > /tmp/lambda-invoke-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_FUNCTION}"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "LambdaInvokePolicy" \
  --policy-document file:///tmp/lambda-invoke-policy.json \
  --region "$REGION"

echo ""
echo "✅ Role created: $ROLE_NAME"
echo ""
echo "Role ARN: arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "Waiting 10 seconds for IAM to propagate..."
sleep 10
echo ""
echo "✅ Done! You can now test the agent:"
echo "   http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com"
