# Deployment Guide - Bedrock Text2SQL Agent

This guide provides instructions for deploying the Amazon Bedrock Text2SQL Agent using Infrastructure as Code (CloudFormation).

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured (`aws configure`)
3. **Bedrock Model Access**:
   - Navigate to Amazon Bedrock console → Model Access
   - Enable: **Titan Embedding G1 - Text** and **Anthropic: Claude 3 Haiku**

## Quick Start

### Deploy All Stacks

```bash
# Make scripts executable
chmod +x deploy.sh cleanup.sh

# Set environment variables (optional)
export AWS_REGION=us-west-2  # Default region
export ALIAS=txt2sql-demo    # Default alias for resource naming

# Deploy all stacks
./deploy.sh
```

The deployment script will:
1. ✅ Validate AWS credentials
2. ✅ Deploy Athena, Glue, and S3 infrastructure
3. ✅ Deploy Bedrock Agent and Lambda function
4. ✅ Deploy EC2 instance with Streamlit app
5. ✅ Output all necessary configuration details

### Post-Deployment Configuration

After deployment completes, configure the Streamlit app:

```bash
# Get the instance ID from deployment output
export INSTANCE_ID="<your-instance-id>"

# Connect to EC2
aws ec2-instance-connect ssh --instance-id $INSTANCE_ID --region us-west-2

# Edit the invoke_agent.py file
sudo vi /home/ubuntu/app/streamlit_app/invoke_agent.py

# Update these two lines with your actual IDs:
# agentId = "<YOUR-AGENT-ID>"
# agentAliasId = "<YOUR-ALIAS-ID>"

# Start the Streamlit app
streamlit run /home/ubuntu/app/streamlit_app/app.py
```

Access the application at: `http://<PUBLIC-DNS>:8501`

## Manual Deployment (Alternative)

If you prefer to deploy stacks individually:

### Stack 1: Athena, Glue, and S3

```bash
aws cloudformation deploy \
    --template-file cfn/1-athena-glue-s3-template.yaml \
    --stack-name athena-glue-s3-stack \
    --parameter-overrides \
        Alias="txt2sql-demo" \
        AthenaDatabaseName="athena_db" \
    --capabilities CAPABILITY_IAM \
    --region us-west-2
```

### Stack 2: Bedrock Agent and Lambda

```bash
aws cloudformation deploy \
    --template-file cfn/2-bedrock-agent-lambda-template.yaml \
    --stack-name bedrock-agent-lambda-stack \
    --parameter-overrides \
        Alias="txt2sql-demo" \
        FoundationModel="anthropic.claude-3-haiku-20240307-v1:0" \
    --capabilities CAPABILITY_IAM \
    --region us-west-2
```

### Stack 3: EC2 Streamlit

```bash
aws cloudformation deploy \
    --template-file cfn/3-ec2-streamlit-template.yaml \
    --stack-name ec2-streamlit-stack \
    --parameter-overrides \
        InstanceType="t3.small" \
        SSHRegionIPsAllowed="18.237.140.160/29" \
    --capabilities CAPABILITY_IAM \
    --region us-west-2
```

## Testing

### Test in AWS Console

1. Navigate to **Amazon Bedrock** → **Agents**
2. Select your agent
3. Use the test UI to try example queries:
   - "Show me all procedures in the imaging category that are insured"
   - "Show me all customers that are VIP and have a balance over 200 dollars"
   - "Return the number of procedures in the laboratory category"

### Test with Streamlit UI

1. Access the Streamlit app at `http://<PUBLIC-DNS>:8501`
2. Enter natural language queries
3. View SQL query generation and results
4. Review trace data in the sidebar

## Resources Created

| Resource | Description |
|----------|-------------|
| S3 Buckets | Data storage, Athena outputs, replication, logging |
| Athena Database | `athena_db` with `customers` and `procedures` tables |
| Glue Tables | Data catalog for CSV files |
| Lambda Function | Executes Athena queries |
| Bedrock Agent | Orchestrates text-to-SQL conversion |
| EC2 Instance | Hosts Streamlit web interface |
| IAM Roles | Permissions for all services |

## Configuration Parameters

### Stack 1 Parameters
- `Alias`: Resource naming prefix (default: `{ENTER ALIAS}`)
- `AthenaDatabaseName`: Athena database name (default: `athena_db`)

### Stack 2 Parameters
- `Alias`: Resource naming prefix (matches Stack 1)
- `FoundationModel`: Bedrock model ID (default: Claude 3 Haiku)

### Stack 3 Parameters
- `InstanceType`: EC2 instance size (default: `t3.small`)
- `SSHRegionIPsAllowed`: CIDR for SSH access (default: us-west-2)
- `MapPublicIpOnLaunch`: Enable public IP (default: `true`)

## Cleanup

To delete all resources and avoid charges:

```bash
./cleanup.sh
```

This will:
- Empty all S3 buckets
- Delete all CloudFormation stacks
- Remove associated resources

## Troubleshooting

### Issue: Stack deployment fails
**Solution**: Check CloudFormation console for detailed error messages

### Issue: Cannot SSH to EC2 instance
**Solution**: Verify the `SSHRegionIPsAllowed` parameter matches your region's CIDR

### Issue: Streamlit app shows errors
**Solution**: Ensure Agent ID and Alias ID are correctly configured in `invoke_agent.py`

### Issue: Bedrock model not available
**Solution**: Enable model access in Bedrock console (see Prerequisites)

## Cost Optimization

For development/testing:
- Use `t3.small` instance type
- Stop EC2 instance when not in use
- Delete stacks after testing

For production:
- Enable auto-scaling for Lambda
- Use Reserved Instances for EC2
- Implement S3 lifecycle policies

## CI/CD Integration

The CloudFormation templates are ready for CI/CD pipelines. See the next section for setting up automated deployments.

## Support

For issues or questions:
- Check the [main README](README.md)
- Review CloudFormation stack events
- Check Lambda and Bedrock logs in CloudWatch

---

**Next Steps**: Configure your Streamlit app and start querying with natural language! 🚀

