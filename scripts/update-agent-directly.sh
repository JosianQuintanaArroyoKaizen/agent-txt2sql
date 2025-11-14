#!/bin/bash
# Update Bedrock agent orchestration prompt directly via API
# This avoids CloudFormation update issues

set -e

AGENT_ID="${AGENT_ID:-}"
REGION="${AWS_REGION:-eu-central-1}"

if [ -z "$AGENT_ID" ]; then
    echo "ERROR: AGENT_ID environment variable not set"
    echo ""
    echo "Find your agent ID:"
    echo "  aws bedrock-agent list-agents --region $REGION --query 'agentSummaries[*].[agentId,agentName]' --output table"
    echo ""
    echo "Then run:"
    echo "  AGENT_ID=<your-agent-id> ./scripts/update-agent-directly.sh"
    exit 1
fi

echo "Updating Bedrock Agent: $AGENT_ID"
echo "Region: $REGION"
echo ""

# Get current agent configuration
echo "Getting current agent configuration..."
AGENT_CONFIG=$(aws bedrock-agent get-agent \
    --agent-id "$AGENT_ID" \
    --region "$REGION")

echo "✅ Got agent configuration"
echo ""

# Note: Direct API update of orchestration prompt is complex
# The better approach is to use the console or update via prepare-agent API
echo "⚠️  Direct API update of orchestration prompt is not straightforward."
echo ""
echo "RECOMMENDED APPROACH:"
echo "1. Go to AWS Console → Bedrock → Agents → $AGENT_ID"
echo "2. Click 'Edit'"
echo "3. Look for 'Advanced prompts' or 'Orchestration' section"
echo "4. If you can't find it, the agent was deployed via CloudFormation"
echo ""
echo "ALTERNATIVE: Update via CloudFormation (but we're having issues)"
echo "  OR manually edit the agent in console if the option appears"
echo ""
echo "Let me check if we can get the orchestration prompt via API..."

# Try to get the agent version and prompt configuration
LATEST_VERSION=$(echo "$AGENT_CONFIG" | jq -r '.agent.latestAgentVersion')
echo "Latest Agent Version: $LATEST_VERSION"
echo ""
echo "The orchestration prompt is embedded in the agent version."
echo "To update it, you need to either:"
echo "  1. Update via CloudFormation (currently failing)"
echo "  2. Update via Console (if available)"
echo "  3. Create a new agent version with updated prompt"
echo ""
echo "Since CloudFormation is failing, let's try a different approach..."
echo "Check the CloudFormation console for detailed error messages."

