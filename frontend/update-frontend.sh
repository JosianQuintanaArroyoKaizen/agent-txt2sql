#!/bin/bash

##############################################################################
# Quick Frontend Update Script
# Updates the S3-hosted frontend files with the new agent alias
##############################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

REGION="${AWS_REGION:-eu-central-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="txt2sql-frontend-${ACCOUNT_ID}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Updating Frontend${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

cd "$(dirname "$0")"

# Check if bucket exists
if ! aws s3 ls "s3://$BUCKET_NAME" --region $REGION >/dev/null 2>&1; then
    echo -e "${YELLOW}Bucket $BUCKET_NAME does not exist.${NC}"
    echo -e "${YELLOW}Please run deploy-simple.sh first to create the infrastructure.${NC}"
    exit 1
fi

echo -e "${YELLOW}Uploading updated frontend files...${NC}"

# Upload updated files
aws s3 cp index.html s3://$BUCKET_NAME/ --region $REGION
aws s3 cp app.js s3://$BUCKET_NAME/ --region $REGION

echo -e "${GREEN}✅ Frontend files updated!${NC}"
echo ""

# Get the frontend URL
FRONTEND_URL="http://${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"

echo -e "${GREEN}Frontend URL:${NC}"
echo -e "${BLUE}$FRONTEND_URL${NC}"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "1. Clear your browser cache or hard refresh (Ctrl+Shift+R)"
echo "2. Open DevTools (F12) → Application → Clear storage → Clear site data"
echo "3. Or run this in the browser console:"
echo ""
echo "   localStorage.setItem('agentConfig', JSON.stringify({"
echo "       agentId: 'G1RWZFEZ4O',"
echo "       agentAliasId: 'TSTALIASID',"
echo "       awsRegion: 'eu-central-1'"
echo "   }));"
echo "   location.reload();"
echo ""
echo -e "${GREEN}Now your frontend will query the test_population EMIR data!${NC}"
