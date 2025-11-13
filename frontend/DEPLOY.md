# Quick Deployment Guide

## Simplest Option: Deploy Lambda + Frontend

### Step 1: Deploy Lambda Function

```bash
cd frontend

# Create deployment package
zip lambda-proxy.zip lambda-proxy.py

# Create Lambda function
aws lambda create-function \
  --function-name txt2sql-frontend-proxy \
  --runtime python3.12 \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-execution-role \
  --handler lambda-proxy.lambda_handler \
  --zip-file fileb://lambda-proxy.zip \
  --environment Variables="{AGENT_ID=G1RWZFEZ4O,AGENT_ALIAS_ID=BW3ALCWPTJ,AWS_REGION=eu-central-1}" \
  --region eu-central-1

# Add Bedrock permissions to Lambda role
aws iam attach-role-policy \
  --role-name lambda-execution-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess
```

### Step 2: Create API Gateway

```bash
# Create REST API
aws apigateway create-rest-api \
  --name txt2sql-frontend-api \
  --region eu-central-1

# Note the API ID from output, then:
API_ID="your-api-id"

# Create resource
aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $(aws apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text) \
  --path-part chat \
  --region eu-central-1

# Create POST method
RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?pathPart==`chat`].id' --output text)

aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --region eu-central-1

# Enable CORS
aws apigateway put-method-response \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters method.response.header.Access-Control-Allow-Origin=true \
  --region eu-central-1
```

### Step 3: Deploy Frontend to S3

```bash
# Create bucket
BUCKET_NAME="txt2sql-frontend-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region eu-central-1

# Upload files
aws s3 cp index.html s3://$BUCKET_NAME/
aws s3 cp app.js s3://$BUCKET_NAME/

# Enable static hosting
aws s3 website s3://$BUCKET_NAME \
  --index-document index.html \
  --error-document index.html

# Make public
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
  }]
}'

echo "Frontend URL: http://$BUCKET_NAME.s3-website-eu-central-1.amazonaws.com"
```

### Step 4: Update Frontend with API URL

1. Get your API Gateway URL
2. Open the frontend
3. Click "Set API Endpoint"
4. Enter: `https://YOUR_API_ID.execute-api.eu-central-1.amazonaws.com/prod/chat`

## Even Simpler: Use the Deploy Script

I can create an automated deployment script that does all of this. Would you like me to create it?

