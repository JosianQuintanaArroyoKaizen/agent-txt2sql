#!/bin/bash

##############################################################################
# Deploy Simple Frontend to AWS Amplify
# This creates a stable URL that doesn't change
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Deploy Frontend to AWS Amplify${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Amplify CLI is installed
if ! command -v amplify &> /dev/null; then
    echo -e "${YELLOW}Amplify CLI not found. Installing...${NC}"
    npm install -g @aws-amplify/cli
fi

cd "$(dirname "$0")"

# Check if already initialized
if [ ! -d "amplify" ]; then
    echo -e "${YELLOW}Initializing Amplify...${NC}"
    echo -e "${YELLOW}When prompted:${NC}"
    echo "  - Project name: txt2sql-frontend"
    echo "  - Environment: dev"
    echo "  - Framework: none"
    echo "  - Source directory: ."
    echo "  - Distribution directory: ."
    echo "  - Build command: (leave empty)"
    echo "  - Start command: (leave empty)"
    echo ""
    
    amplify init --yes \
        --amplify "{\"projectName\":\"txt2sql-frontend\",\"envName\":\"dev\",\"defaultEditor\":\"code\"}" \
        --providers "{\"awscloudformation\":{\"useProfile\":true,\"profileName\":\"default\",\"region\":\"eu-central-1\"}}" \
        --frontend "{\"frontend\":\"javascript\",\"framework\":\"none\",\"config\":{\"SourceDir\":\".\",\"DistributionDir\":\".\"}}"
fi

# Add hosting if not already added
if ! amplify status | grep -q "hosting"; then
    echo -e "${YELLOW}Adding Amplify hosting...${NC}"
    amplify add hosting --yes
fi

# Publish
echo -e "${YELLOW}Publishing to Amplify...${NC}"
amplify publish --yes

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo -e "${BLUE}Your frontend is now available at the URL shown above.${NC}"
echo -e "${BLUE}This URL is stable and won't change.${NC}"

