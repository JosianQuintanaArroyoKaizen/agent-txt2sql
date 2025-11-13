#!/bin/bash

##############################################################################
# Simple Deployment: Lambda + API Gateway + S3 Frontend
# Creates everything needed for a working frontend with stable URL
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REGION="${AWS_REGION:-eu-central-1}"
AGENT_ID="${AGENT_ID:-G1RWZFEZ4O}"
AGENT_ALIAS_ID="${AGENT_ALIAS_ID:-BW3ALCWPTJ}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Simple Frontend Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Agent ID: $AGENT_ID${NC}"
echo -e "${GREEN}Agent Alias ID: $AGENT_ALIAS_ID${NC}"
echo -e "${GREEN}Region: $REGION${NC}"
echo ""

cd "$(dirname "$0")"

# 1. Create Lambda execution role
echo -e "${YELLOW}[1/6] Creating Lambda execution role...${NC}"
ROLE_NAME="txt2sql-frontend-lambda-role"

if ! aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
    # Create trust policy
    cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF
    
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --region $REGION >/dev/null
    
    # Attach basic Lambda execution policy
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
        --region $REGION
    
    # Attach Bedrock policy
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess \
        --region $REGION
    
    echo -e "${GREEN}✅ Role created${NC}"
else
    echo -e "${GREEN}✅ Role already exists${NC}"
fi

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""

# 2. Package Lambda function
echo -e "${YELLOW}[2/6] Packaging Lambda function...${NC}"
zip -q lambda-proxy.zip lambda-proxy.py
echo -e "${GREEN}✅ Lambda packaged${NC}"
echo ""

# 3. Create/Update Lambda function
echo -e "${YELLOW}[3/6] Deploying Lambda function...${NC}"
FUNCTION_NAME="txt2sql-frontend-proxy"

if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION >/dev/null 2>&1; then
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://lambda-proxy.zip \
        --region $REGION >/dev/null
    
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --environment Variables="{AGENT_ID=$AGENT_ID,AGENT_ALIAS_ID=$AGENT_ALIAS_ID,BEDROCK_REGION=$REGION}" \
        --region $REGION >/dev/null
    
    echo -e "${GREEN}✅ Lambda updated${NC}"
else
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.12 \
        --role $ROLE_ARN \
        --handler lambda-proxy.lambda_handler \
        --zip-file fileb://lambda-proxy.zip \
        --timeout 30 \
        --environment Variables="{AGENT_ID=$AGENT_ID,AGENT_ALIAS_ID=$AGENT_ALIAS_ID,BEDROCK_REGION=$REGION}" \
        --region $REGION >/dev/null
    
    echo -e "${GREEN}✅ Lambda created${NC}"
fi

LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"
echo ""

# 4. Create API Gateway
echo -e "${YELLOW}[4/6] Creating API Gateway...${NC}"
API_NAME="txt2sql-frontend-api"

# Check if API exists
EXISTING_API=$(aws apigateway get-rest-apis --region $REGION --query "items[?name=='$API_NAME'].id" --output text)

if [ -n "$EXISTING_API" ] && [ "$EXISTING_API" != "None" ]; then
    API_ID=$EXISTING_API
    echo -e "${GREEN}✅ Using existing API: $API_ID${NC}"
else
    API_ID=$(aws apigateway create-rest-api \
        --name $API_NAME \
        --region $REGION \
        --query 'id' \
        --output text)
    echo -e "${GREEN}✅ API created: $API_ID${NC}"
fi

# Get root resource
ROOT_RESOURCE=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION \
    --query 'items[?path==`/`].id' \
    --output text)

# Create /chat resource if it doesn't exist
RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION \
    --query "items[?path=='/chat'].id" \
    --output text)

if [ -z "$RESOURCE_ID" ] || [ "$RESOURCE_ID" == "None" ]; then
    RESOURCE_ID=$(aws apigateway create-resource \
        --rest-api-id $API_ID \
        --parent-id $ROOT_RESOURCE \
        --path-part chat \
        --region $REGION \
        --query 'id' \
        --output text)
    echo -e "${GREEN}✅ Resource /chat created${NC}"
fi

# Create POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE \
    --region $REGION >/dev/null 2>&1 || echo "Method already exists"

# Create OPTIONS method for CORS
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region $REGION >/dev/null 2>&1 || echo "OPTIONS method already exists"

# Set up Lambda integration
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region $REGION >/dev/null

# Add CORS headers
aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters "method.response.header.Access-Control-Allow-Origin=true,method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true" \
    --region $REGION >/dev/null 2>&1

aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters "{\"method.response.header.Access-Control-Allow-Origin\":\"'*'\",\"method.response.header.Access-Control-Allow-Headers\":\"'Content-Type'\",\"method.response.header.Access-Control-Allow-Methods\":\"'POST,OPTIONS'\"}" \
    --region $REGION >/dev/null 2>&1

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
    --region $REGION >/dev/null 2>&1 || echo "Permission already exists"

# Deploy API
DEPLOYMENT_ID=$(aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $REGION \
    --query 'id' \
    --output text 2>/dev/null || echo "deployment-exists")

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/chat"
echo -e "${GREEN}✅ API Gateway configured${NC}"
echo -e "${BLUE}API URL: $API_URL${NC}"
echo ""

# 5. Deploy frontend to S3
echo -e "${YELLOW}[5/6] Deploying frontend to S3...${NC}"
BUCKET_NAME="txt2sql-frontend-${ACCOUNT_ID}"

if ! aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
    aws s3 mb s3://$BUCKET_NAME --region $REGION
    echo -e "${GREEN}✅ Bucket created${NC}"
fi

aws s3 cp index.html s3://$BUCKET_NAME/ --region $REGION
aws s3 cp app.js s3://$BUCKET_NAME/ --region $REGION

aws s3 website s3://$BUCKET_NAME \
    --index-document index.html \
    --error-document index.html \
    --region $REGION

# Make bucket public
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Effect\": \"Allow\",
    \"Principal\": \"*\",
    \"Action\": \"s3:GetObject\",
    \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\"
  }]
}" --region $REGION

FRONTEND_URL="http://${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"
echo -e "${GREEN}✅ Frontend deployed${NC}"
echo ""

# 6. Create CloudFront distribution (optional, for HTTPS)
echo -e "${YELLOW}[6/6] Creating CloudFront distribution (for HTTPS)...${NC}"
echo -e "${YELLOW}This may take 5-10 minutes...${NC}"

DIST_CONFIG=$(cat <<EOF
{
  "CallerReference": "$(date +%s)",
  "Comment": "Text2SQL Frontend",
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [{
      "Id": "S3-$BUCKET_NAME",
      "DomainName": "$BUCKET_NAME.s3.$REGION.amazonaws.com",
      "S3OriginConfig": {"OriginAccessIdentity": ""}
    }]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$BUCKET_NAME",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"], "CachedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"]}},
    "ForwardedValues": {"QueryString": false, "Cookies": {"Forward": "none"}},
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "Compress": true
  },
  "Enabled": true,
  "PriceClass": "PriceClass_100"
}
EOF
)

DIST_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config "$DIST_CONFIG" \
    --region $REGION \
    --output json 2>/dev/null || echo '{"Distribution":{"Id":"existing"}}')

CF_DOMAIN=$(echo $DIST_OUTPUT | jq -r '.Distribution.DomainName // empty')
CF_ID=$(echo $DIST_OUTPUT | jq -r '.Distribution.Id // empty')

if [ -n "$CF_DOMAIN" ] && [ "$CF_DOMAIN" != "null" ] && [ "$CF_DOMAIN" != "existing" ]; then
    HTTPS_URL="https://$CF_DOMAIN"
    echo -e "${GREEN}✅ CloudFront distribution created${NC}"
    echo -e "${YELLOW}Note: CloudFront takes 5-10 minutes to deploy${NC}"
else
    HTTPS_URL=""
    echo -e "${YELLOW}⚠ CloudFront distribution may already exist or creation failed${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Frontend URL (HTTP):${NC}"
echo -e "${BLUE}$FRONTEND_URL${NC}"
echo ""

if [ -n "$HTTPS_URL" ]; then
    echo -e "${GREEN}Frontend URL (HTTPS - available in 5-10 min):${NC}"
    echo -e "${BLUE}$HTTPS_URL${NC}"
    echo ""
fi

echo -e "${GREEN}API Gateway URL:${NC}"
echo -e "${BLUE}$API_URL${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Open the frontend URL above"
echo "2. Click 'Set API Endpoint' button"
echo "3. Enter: $API_URL"
echo "4. Start chatting!"
echo ""
echo -e "${BLUE}Files deployed:${NC}"
echo "  - Lambda: $FUNCTION_NAME"
echo "  - API Gateway: $API_ID"
echo "  - S3 Bucket: $BUCKET_NAME"
if [ -n "$CF_ID" ] && [ "$CF_ID" != "null" ] && [ "$CF_ID" != "existing" ]; then
    echo "  - CloudFront: $CF_ID"
fi
echo ""

# Cleanup
rm -f lambda-proxy.zip /tmp/trust-policy.json

