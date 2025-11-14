# Lambda Permissions Fix

## Problem
Frontend was showing error:
```
Error: An error occurred (accessDeniedException) when calling the InvokeAgent operation: 
Access denied when calling Bedrock. Check your request permissions and retry the request.
```

## Root Cause
The Lambda function `txt2sql-frontend-proxy` had `AmazonBedrockFullAccess` managed policy attached, but this policy alone doesn't grant permission to invoke Bedrock Agents. It needs explicit `bedrock:InvokeAgent` permission.

## Solution
Added inline policy `BedrockAgentInvokePolicy` to the Lambda role with:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeAgent",
        "bedrock:InvokeModel"
      ],
      "Resource": [
        "arn:aws:bedrock:eu-central-1:194561596031:agent/G1RWZFEZ4O",
        "arn:aws:bedrock:eu-central-1:194561596031:agent-alias/G1RWZFEZ4O/*",
        "arn:aws:bedrock:*::foundation-model/*"
      ]
    }
  ]
}
```

## Permissions Granted
- `bedrock:InvokeAgent` - Allows Lambda to call the Bedrock Agent
- `bedrock:InvokeModel` - Allows calling foundation models directly if needed

## Lambda Role Summary
**Role:** `txt2sql-frontend-lambda-role`

**Policies:**
1. `AWSLambdaBasicExecutionRole` (Managed) - CloudWatch Logs
2. `AmazonBedrockFullAccess` (Managed) - General Bedrock access
3. `BedrockAgentInvokePolicy` (Inline) - **NEW** - Agent invoke permission

## Testing
Frontend should now work:
http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com

Try: "Show me 5 incidents with code E_A_C_09"

## Files Created
- `fix-lambda-permissions.sh` - Script to add the policy

## Notes
- This is a common issue when using Bedrock Agents via Lambda
- The managed `AmazonBedrockFullAccess` policy doesn't include agent-specific permissions
- Always scope permissions to specific agents and aliases for security
