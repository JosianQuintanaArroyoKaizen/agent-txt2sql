#!/bin/bash

##############################################################################
# Amazon Bedrock Text2SQL Agent - Cleanup Script
# This script deletes all CloudFormation stacks and associated resources
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="${AWS_REGION:-us-west-2}"
ALIAS="${ALIAS:-txt2sql-demo}"
STACK_NAME_1="athena-glue-s3-stack"
STACK_NAME_2="bedrock-agent-lambda-stack"
STACK_NAME_3="ec2-streamlit-stack"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Bedrock Text2SQL Agent Cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will delete all resources created by the deployment.${NC}"
echo -e "${YELLOW}This includes S3 buckets and their contents!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${RED}Cleanup cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Starting cleanup...${NC}"
echo ""

# Get account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Function to empty and delete S3 bucket
empty_bucket() {
    local bucket_name=$1
    if aws s3 ls "s3://${bucket_name}" 2>/dev/null; then
        echo -e "${YELLOW}Emptying S3 bucket: ${bucket_name}${NC}"
        # Remove all versions and delete markers
        aws s3api delete-objects \
            --bucket "${bucket_name}" \
            --delete "$(aws s3api list-object-versions \
                --bucket "${bucket_name}" \
                --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
                --max-items 1000)" \
            2>/dev/null || true
        
        aws s3api delete-objects \
            --bucket "${bucket_name}" \
            --delete "$(aws s3api list-object-versions \
                --bucket "${bucket_name}" \
                --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
                --max-items 1000)" \
            2>/dev/null || true
        
        # Remove all objects
        aws s3 rm "s3://${bucket_name}" --recursive 2>/dev/null || true
        echo -e "${GREEN}✓ Bucket ${bucket_name} emptied${NC}"
    fi
}

# Function to delete stack
delete_stack() {
    local stack_name=$1
    if aws cloudformation describe-stacks --stack-name "${stack_name}" --region "${REGION}" &>/dev/null; then
        echo -e "${YELLOW}Deleting stack: ${stack_name}${NC}"
        aws cloudformation delete-stack \
            --stack-name "${stack_name}" \
            --region "${REGION}"
        
        echo -e "${YELLOW}Waiting for stack deletion...${NC}"
        aws cloudformation wait stack-delete-complete \
            --stack-name "${stack_name}" \
            --region "${REGION}" || true
        
        echo -e "${GREEN}✓ Stack ${stack_name} deleted${NC}"
    else
        echo -e "${YELLOW}Stack ${stack_name} not found, skipping${NC}"
    fi
}

# Delete stacks in reverse order
echo -e "${BLUE}[1/3] Deleting EC2 Streamlit Stack...${NC}"
delete_stack "${STACK_NAME_3}"

echo ""
echo -e "${BLUE}[2/3] Deleting Bedrock Agent and Lambda Stack...${NC}"
delete_stack "${STACK_NAME_2}"

echo ""
echo -e "${BLUE}[3/3] Deleting Athena, Glue, and S3 Stack...${NC}"

# Empty S3 buckets first
empty_bucket "sl-data-store-${ALIAS}-${ACCOUNT_ID}-${REGION}"
empty_bucket "sl-athena-output-${ALIAS}-${ACCOUNT_ID}-${REGION}"
empty_bucket "sl-replication-${ALIAS}-${ACCOUNT_ID}-${REGION}"
empty_bucket "logging-bucket-${ACCOUNT_ID}-${REGION}"

delete_stack "${STACK_NAME_1}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cleanup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}All resources have been deleted.${NC}"
echo ""

# Remove deployment info file if it exists
if [ -f "deployment-info.txt" ]; then
    rm deployment-info.txt
    echo -e "${GREEN}Removed deployment-info.txt${NC}"
fi

