# How to Find the Orchestration Prompt in Bedrock Agent

## What You're Looking At

The OpenAPI schema you found is for the **Action Group** - that's correct and doesn't need to change. The **Orchestration Prompt** is in a different location.

## Where to Find Orchestration Prompt

### Option 1: In the Agent Edit View

1. **Go to Bedrock Console** → **Agents** → Your Agent
2. Click **Edit** (top right)
3. Look for these sections in order:
   - **Agent overview** (at top)
   - **Foundation model**
   - **Instructions** (this is the main instruction, not what we need)
   - **Action groups** (this is where you saw the OpenAPI schema)
   - **Knowledge base** (if configured)
   - **Advanced prompts** ← **THIS IS WHAT YOU NEED**
4. Under **Advanced prompts**, you should see:
   - **Orchestration** tab
   - **Pre-processing** tab (if configured)
   - **Post-processing** tab (if configured)

5. Click **Edit** next to **Orchestration**
6. You should see a large text editor with the orchestration template

### Option 2: If You Don't See "Advanced Prompts"

If you don't see an "Advanced prompts" section, it might mean:

1. **Your agent was deployed via CloudFormation** - The orchestration prompt is embedded in the CloudFormation template
2. **You need to enable it** - Some agents don't show this until you explicitly enable orchestration override

### Option 3: Check CloudFormation Template

If your agent was deployed via CloudFormation, the orchestration prompt is in:
- File: `cfn/2-bedrock-agent-lambda-template.yaml`
- Section: `PromptOverrideConfiguration` (around line 329)
- Property: `BasePromptTemplate`

You would need to:
1. Update the CloudFormation template
2. Update the stack
3. This will update the agent

## Alternative: Update via CloudFormation

If you can't find it in the console, you can update the CloudFormation template:

1. Edit `cfn/2-bedrock-agent-lambda-template.yaml`
2. Find the `BasePromptTemplate` section (around line 341)
3. Find `<athena_schemas>` section (around line 368)
4. Add the EMIR schema there
5. Update the CloudFormation stack

Let me create a script to help you update the template.

## Quick Check: What Type of Deployment?

Run this to check if your agent was deployed via CloudFormation:

```bash
# Get your agent ID (you'll need this)
aws bedrock-agent list-agents --region eu-central-1 --query 'agentSummaries[*].[agentId,agentName]' --output table

# Then check if it's managed by CloudFormation
aws cloudformation describe-stack-resources --region eu-central-1 --query 'StackResources[?ResourceType==`AWS::Bedrock::Agent`]' --output table
```

## Visual Guide: Where to Look

```
Bedrock Console
└── Agents
    └── [Your Agent Name]
        └── Edit
            ├── Agent overview
            ├── Foundation model
            ├── Instructions ← Not this one
            ├── Action groups ← You found this (OpenAPI schema)
            ├── Knowledge base
            └── Advanced prompts ← THIS ONE!
                └── Orchestration
                    └── Edit ← Click here
                        └── [Large text editor with orchestration template]
```

## If You Still Can't Find It

The orchestration prompt might be:
1. **Hidden** - Try scrolling down more in the Edit view
2. **Not enabled** - You may need to enable "Override orchestration template defaults"
3. **In CloudFormation** - If deployed via IaC, it's in the template

Let me know what you see and I can help you locate it or provide an alternative approach!

