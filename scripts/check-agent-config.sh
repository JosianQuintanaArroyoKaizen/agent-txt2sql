#!/bin/bash
# Script to check Bedrock agent configuration

set -e

AGENT_ID="${AGENT_ID:-}"
REGION="${AWS_REGION:-eu-central-1}"

if [ -z "$AGENT_ID" ]; then
    echo "ERROR: AGENT_ID environment variable not set"
    echo "Usage: AGENT_ID=<your-agent-id> ./scripts/check-agent-config.sh"
    exit 1
fi

echo "Checking Bedrock Agent: $AGENT_ID"
echo "Region: $REGION"
echo ""

# Get agent details
echo "=== Agent Details ==="
aws bedrock-agent describe-agent \
    --agent-id "$AGENT_ID" \
    --region "$REGION" \
    --query '{Name:agentName,Status:agentStatus,LatestVersion:latestAgentVersion}' \
    --output table

echo ""
echo "=== Checking if EMIR table is in orchestration prompt ==="

# Get the latest agent version
LATEST_VERSION=$(aws bedrock-agent describe-agent \
    --agent-id "$AGENT_ID" \
    --region "$REGION" \
    --query 'latestAgentVersion' \
    --output text)

echo "Latest Agent Version: $LATEST_VERSION"
echo ""

# Get the agent's instruction/orchestration prompt
echo "Checking orchestration prompt for EMIR references..."
aws bedrock-agent get-agent \
    --agent-id "$AGENT_ID" \
    --region "$REGION" \
    --query 'agent.instruction' \
    --output text | grep -i "test_population\|emir" && echo "✓ Found EMIR references" || echo "✗ No EMIR references found"

echo ""
echo "=== Next Steps ==="
echo "1. Go to AWS Console → Bedrock → Agents → $AGENT_ID"
echo "2. Click 'Edit'"
echo "3. Navigate to 'Advanced prompts' → 'Orchestration'"
echo "4. Add the EMIR table schema (see UPDATE-AGENT-FOR-EMIR.md)"
echo "5. Click 'Save and exit'"
echo "6. Click 'Prepare' to create a new version"
echo "7. Wait for preparation to complete"
echo "8. Test again with: 'Show me some records from the EMIR dataset'"

