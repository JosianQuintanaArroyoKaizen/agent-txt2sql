#!/bin/bash

##############################################################################
# Complete Frontend Setup and Testing Script
# This script ensures everything is deployed and provides testing instructions
##############################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Frontend Deployment & Testing${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

REGION="eu-central-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="txt2sql-frontend-${ACCOUNT_ID}"

# Check bucket exists
if ! aws s3 ls s3://$BUCKET_NAME --region $REGION >/dev/null 2>&1; then
    echo -e "${RED}✗ Bucket does not exist. Running full deployment...${NC}"
    cd "$(dirname "$0")"
    ./deploy-simple.sh
    exit 0
fi

echo -e "${GREEN}✓ S3 Bucket exists: $BUCKET_NAME${NC}"

# Verify website configuration
echo -e "${YELLOW}Checking website configuration...${NC}"
aws s3api get-bucket-website --bucket $BUCKET_NAME --region $REGION >/dev/null 2>&1 && echo -e "${GREEN}✓ Website hosting enabled${NC}" || echo -e "${RED}✗ Website hosting not configured${NC}"

# Verify public access
echo -e "${YELLOW}Checking public access...${NC}"
POLICY=$(aws s3api get-bucket-policy --bucket $BUCKET_NAME --region $REGION 2>&1)
if echo "$POLICY" | grep -q "s3:GetObject"; then
    echo -e "${GREEN}✓ Public read access enabled${NC}"
else
    echo -e "${RED}✗ Public access not configured${NC}"
fi

# Upload files
echo -e "${YELLOW}Uploading latest files...${NC}"
cd "$(dirname "$0")"
aws s3 cp index.html s3://$BUCKET_NAME/ --region $REGION >/dev/null
aws s3 cp app.js s3://$BUCKET_NAME/ --region $REGION >/dev/null
echo -e "${GREEN}✓ Files uploaded${NC}"
echo ""

# Get API endpoint
API_URL=$(aws apigateway get-rest-apis --region $REGION --query "items[?name=='txt2sql-frontend-api'].id" --output text 2>/dev/null || echo "")
if [ -n "$API_URL" ] && [ "$API_URL" != "None" ]; then
    API_ENDPOINT="https://${API_URL}.execute-api.${REGION}.amazonaws.com/prod/chat"
else
    API_ENDPOINT="https://f7tvfb3c2c.execute-api.${REGION}.amazonaws.com/prod/chat"
fi

# The correct S3 website URL format for eu-central-1
FRONTEND_URL="http://${BUCKET_NAME}.s3-website.${REGION}.amazonaws.com"

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}🌐 Frontend URL:${NC}"
echo -e "${BLUE}   $FRONTEND_URL${NC}"
echo ""
echo -e "${GREEN}🔗 API Endpoint:${NC}"
echo -e "${BLUE}   $API_ENDPOINT${NC}"
echo ""
echo -e "${YELLOW}📋 Configuration:${NC}"
echo "   Agent ID:       G1RWZFEZ4O"
echo "   Agent Alias:    TSTALIASID"
echo "   Region:         eu-central-1"
echo ""

# Test the URL
echo -e "${YELLOW}Testing frontend URL...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Frontend is accessible (HTTP 200)${NC}"
else
    echo -e "${RED}✗ Frontend returned HTTP $HTTP_CODE${NC}"
fi
echo ""

# Test API
echo -e "${YELLOW}Testing API endpoint...${NC}"
API_TEST=$(curl -s -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"question": "count records in test_population"}' 2>&1)

if echo "$API_TEST" | grep -q "test_population\|records\|7867"; then
    echo -e "${GREEN}✓ API is working and returning EMIR data${NC}"
else
    echo -e "${YELLOW}⚠ API response: ${API_TEST:0:100}...${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}📖 How to Use:${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "1. Open the frontend URL in your browser:"
echo -e "   ${BLUE}$FRONTEND_URL${NC}"
echo ""
echo "2. Clear your browser cache:"
echo "   - Press F12 → Console tab"
echo "   - Run this command:"
echo ""
echo "     localStorage.setItem('agentConfig', JSON.stringify({"
echo "         agentId: 'G1RWZFEZ4O',"
echo "         agentAliasId: 'TSTALIASID',"
echo "         awsRegion: 'eu-central-1'"
echo "     }));"
echo "     localStorage.setItem('apiEndpoint', '$API_ENDPOINT');"
echo "     location.reload();"
echo ""
echo "3. Or use the UI:"
echo "   - Click 'Set API Endpoint'"
echo "   - Enter: $API_ENDPOINT"
echo "   - Update Agent Alias ID to: TSTALIASID"
echo "   - Click 'Save Configuration'"
echo ""
echo "4. Test queries:"
echo "   - 'Show me 10 records from test_population'"
echo "   - 'Count records in test_population'"
echo "   - 'Show incidents with valuation over 1 million'"
echo ""
echo -e "${GREEN}You should now see EMIR data instead of demo customer data!${NC}"
echo ""
