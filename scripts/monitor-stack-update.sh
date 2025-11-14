#!/bin/bash
# Monitor CloudFormation stack update progress

STACK_NAME="${1:-dev-eu-central-1-bedrock-agent-lambda-stack}"
REGION="${AWS_REGION:-eu-central-1}"

echo "Monitoring stack update: $STACK_NAME"
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
    STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Error getting stack status"
        break
    fi
    
    TIMESTAMP=$(date '+%H:%M:%S')
    echo "[$TIMESTAMP] Stack Status: $STATUS"
    
    case "$STATUS" in
        *COMPLETE)
            echo ""
            echo "✅ Stack update completed successfully!"
            echo ""
            echo "The Bedrock agent should automatically prepare a new version."
            echo "Wait 1-2 minutes, then test with: 'Show me some records from the EMIR dataset'"
            break
            ;;
        *FAILED|*ROLLBACK*)
            echo ""
            echo "❌ Stack update failed or rolled back"
            echo "Check CloudFormation console for details"
            break
            ;;
        UPDATE_IN_PROGRESS|UPDATE_IN_PROGRESS_CLEANUP_IN_PROGRESS)
            sleep 5
            ;;
        *)
            sleep 2
            ;;
    esac
done

