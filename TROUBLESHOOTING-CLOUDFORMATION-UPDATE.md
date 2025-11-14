# Troubleshooting CloudFormation Update Failure

## Issue
The CloudFormation stack update is failing when trying to update the Bedrock agent with the EMIR table schema.

## Why This Might Be Happening

1. **Bedrock Agent Updates**: Bedrock agents deployed via CloudFormation can be tricky to update, especially the orchestration prompt
2. **Agent State**: The agent might be in a state that prevents updates
3. **Template Validation**: There might be a subtle syntax issue in the template

## Alternative Solutions

### Option 1: Update Agent via Console (Recommended if Available)

Even though you couldn't find the orchestration prompt before, try this:

1. **Go to Bedrock Console** → **Agents** → Your Agent
2. Click **Edit**
3. **Scroll ALL the way down** - sometimes "Advanced prompts" is at the very bottom
4. Look for tabs: **Orchestration**, **Pre-processing**, **Post-processing**
5. If you see it, click **Edit** next to **Orchestration**
6. Add the EMIR schema there
7. Save and Prepare

### Option 2: Use AWS CLI to Get Agent Prompt

Let's check what the current prompt looks like:

```bash
# Get your agent ID first
aws bedrock-agent list-agents --region eu-central-1 \
  --query 'agentSummaries[*].[agentId,agentName]' --output table

# Get agent details (replace AGENT_ID)
aws bedrock-agent get-agent --agent-id AGENT_ID --region eu-central-1 | jq '.agent.instruction'
```

### Option 3: Manual Template Fix

The issue might be in how the multiline string is formatted. Let me check the template syntax.

### Option 4: Create New Agent Version Manually

If CloudFormation keeps failing, you could:
1. Export the current agent configuration
2. Modify the orchestration prompt
3. Create a new agent version via API

## Check CloudFormation Error Details

Run this to see the detailed error:

```bash
aws cloudformation describe-stack-events \
  --stack-name dev-eu-central-1-bedrock-agent-lambda-stack \
  --region eu-central-1 \
  --max-items 20 \
  --query 'StackEvents[?ResourceStatus==`UPDATE_FAILED` || ResourceStatus==`CREATE_FAILED`].[Timestamp,ResourceType,ResourceStatus,ResourceStatusReason]' \
  --output table
```

## Quick Workaround: Test with Current Agent

While we troubleshoot, you can test if the EMIR table works by querying it directly in Athena:

```sql
-- In Athena console
SELECT incident_code, incident_description, uti_2_1, valuation_amount_2_21
FROM txt2sql_dev_athena_db.test_population
LIMIT 10;
```

If this works, the table is fine - we just need to update the agent's knowledge of it.

## Next Steps

1. **Check CloudFormation console** for detailed error messages
2. **Try console update again** - scroll all the way down in Edit mode
3. **If console doesn't work**, we may need to:
   - Export agent config
   - Modify it
   - Re-import or create new version

Let me know what error details you see in CloudFormation console!

