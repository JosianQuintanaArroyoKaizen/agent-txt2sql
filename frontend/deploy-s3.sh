#!/bin/bash

##############################################################################
# Deploy Simple Frontend to S3 + CloudFront
# Creates a stable HTTPS URL
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REGION="${AWS_REGION:-eu-central-1}"
BUCKET_NAME="txt2sql-frontend-$(date +%s | tail -c 7)"
DISTRIBUTION_ID=""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Deploy Frontend to S3 + CloudFront${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

cd "$(dirname "$0")"

# 1. Create S3 bucket
echo -e "${YELLOW}[1/4] Creating S3 bucket...${NC}"
aws s3 mb s3://$BUCKET_NAME --region $REGION
echo -e "${GREEN}✅ Bucket created: $BUCKET_NAME${NC}"
echo ""

# 2. Upload files
echo -e "${YELLOW}[2/4] Uploading files...${NC}"
aws s3 sync . s3://$BUCKET_NAME \
    --exclude "*.md" \
    --exclude "*.sh" \
    --exclude "amplify/*" \
    --exclude ".git/*" \
    --exclude "node_modules/*" \
    --region $REGION
echo -e "${GREEN}✅ Files uploaded${NC}"
echo ""

# 3. Enable static website hosting
echo -e "${YELLOW}[3/4] Enabling static website hosting...${NC}"
aws s3 website s3://$BUCKET_NAME \
    --index-document index.html \
    --error-document index.html \
    --region $REGION
echo -e "${GREEN}✅ Website hosting enabled${NC}"
echo ""

# 4. Create CloudFront distribution
echo -e "${YELLOW}[4/4] Creating CloudFront distribution...${NC}"
echo -e "${YELLOW}This may take 5-10 minutes...${NC}"

DISTRIBUTION_CONFIG=$(cat <<EOF
{
  "CallerReference": "$(date +%s)",
  "Comment": "Text2SQL Frontend",
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-$BUCKET_NAME",
        "DomainName": "$BUCKET_NAME.s3.$REGION.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$BUCKET_NAME",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
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

DISTRIBUTION_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config "$DISTRIBUTION_CONFIG" \
    --region $REGION \
    --output json)

DISTRIBUTION_ID=$(echo $DISTRIBUTION_OUTPUT | jq -r '.Distribution.Id')
DOMAIN_NAME=$(echo $DISTRIBUTION_OUTPUT | jq -r '.Distribution.DomainName')

echo -e "${GREEN}✅ CloudFront distribution created${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Your frontend will be available at:${NC}"
echo -e "${BLUE}https://$DOMAIN_NAME${NC}"
echo ""
echo -e "${YELLOW}Note: CloudFront distribution takes 5-10 minutes to deploy.${NC}"
echo -e "${YELLOW}The URL above will work once deployment is complete.${NC}"
echo ""
echo -e "${BLUE}Distribution ID: $DISTRIBUTION_ID${NC}"
echo -e "${BLUE}S3 Bucket: $BUCKET_NAME${NC}"
echo ""
echo -e "${YELLOW}To update files later:${NC}"
echo "  aws s3 sync . s3://$BUCKET_NAME --exclude '*.md' --exclude '*.sh'"
echo ""
echo -e "${YELLOW}To invalidate CloudFront cache after updates:${NC}"
echo "  aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths '/*'"

