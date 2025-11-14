#!/bin/bash
# Update CloudFormation stack with correct parameters

STACK_NAME="${1:-dev-eu-central-1-bedrock-agent-lambda-stack}"
REGION="${AWS_REGION:-eu-central-1}"
TEMPLATE_FILE="${2:-cfn/2-bedrock-agent-lambda-template.yaml}"

echo "Updating stack: $STACK_NAME"
echo "Template: $TEMPLATE_FILE"
echo ""

# Get current parameters
echo "Getting current stack parameters..."
PARAMS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Parameters' \
    --output json)

if [ $? -ne 0 ]; then
    echo "Error: Could not get stack parameters"
    exit 1
fi

# Build parameter string
PARAM_STRING=""
while IFS= read -r line; do
    KEY=$(echo "$line" | jq -r '.ParameterKey')
    VALUE=$(echo "$line" | jq -r '.ParameterValue')
    if [ -n "$PARAM_STRING" ]; then
        PARAM_STRING="$PARAM_STRING "
    fi
    PARAM_STRING="${PARAM_STRING}ParameterKey=$KEY,ParameterValue=$VALUE"
done <<< "$(echo "$PARAMS" | jq -c '.[]')"

echo "Updating stack with parameters..."
echo ""

aws cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --region "$REGION" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters $PARAM_STRING

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Stack update initiated successfully!"
    echo ""
    echo "Monitoring progress (press Ctrl+C to stop)..."
    echo ""
    
    # Monitor progress
    while true; do
        STATUS=$(aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query 'Stacks[0].StackStatus' \
            --output text 2>/dev/null)
        
        TIMESTAMP=$(date '+%H:%M:%S')
        echo "[$TIMESTAMP] Status: $STATUS"
        
        case "$STATUS" in
            *COMPLETE)
                echo ""
                echo "✅ Stack update completed!"
                echo "The Bedrock agent should automatically prepare a new version."
                echo "Wait 1-2 minutes, then test with: 'Show me some records from the EMIR dataset'"
                break
                ;;
            *FAILED|*ROLLBACK*)
                echo ""
                echo "❌ Stack update failed"
                echo "Check CloudFormation console for details"
                break
                ;;
            UPDATE_IN_PROGRESS*)
                sleep 5
                ;;
            *)
                sleep 2
                ;;
        esac
    done
else
    echo ""
    echo "❌ Failed to initiate stack update"
    exit 1
fi

