#!/bin/bash
##############################################################################
# Instructions for deploying via AWS CloudShell
# CloudShell has Docker pre-installed, so you can run the deployment there
##############################################################################

echo "=========================================="
echo "Deploy to App Runner via AWS CloudShell"
echo "=========================================="
echo ""
echo "Follow these steps:"
echo ""
echo "1. Open AWS CloudShell:"
echo "   https://console.aws.amazon.com/cloudshell/home?region=eu-central-1"
echo ""
echo "2. Clone your repository:"
echo "   git clone <your-repo-url>"
echo "   cd agent-txt2sql"
echo ""
echo "3. Set your Agent IDs:"
echo "   export AGENT_ID=G1RWZFEZ4O"
echo "   export AGENT_ALIAS_ID=BW3ALCWPTJ"
echo "   export AWS_REGION=eu-central-1"
echo "   export ENVIRONMENT=dev"
echo ""
echo "4. Run the deployment script:"
echo "   chmod +x scripts/deploy-to-apprunner.sh"
echo "   ./scripts/deploy-to-apprunner.sh"
echo ""
echo "5. Wait 5-10 minutes, then get your URL:"
echo "   aws apprunner list-services --region eu-central-1"
echo "   aws apprunner describe-service --service-arn <ARN> --region eu-central-1 --query 'Service.ServiceUrl' --output text"
echo ""

