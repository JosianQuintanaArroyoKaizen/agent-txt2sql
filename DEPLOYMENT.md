# Text2SQL Deployment Guide# Deployment Guide - Bedrock Text2SQL Agent



## Quick StartThis guide provides instructions for deploying the Amazon Bedrock Text2SQL Agent using Infrastructure as Code (CloudFormation).



### Deploy to Dev## Prerequisites

```bash

./deploy-production.sh1. **AWS Account** with appropriate permissions

```2. **AWS CLI** installed and configured (`aws configure`)

3. **Bedrock Model Access**:

### Deploy to Prod   - Navigate to Amazon Bedrock console → Model Access

```bash   - Enable: **Titan Embedding G1 - Text** and **Anthropic: Claude 3 Haiku**

ENVIRONMENT=prod ./deploy-production.sh

```## Quick Start



## What Gets Deployed### Deploy All Stacks



1. **CloudFormation Stacks**```bash

   - Athena/Glue/S3 infrastructure# Make scripts executable

   - Bedrock Agent with Lambda functionchmod +x deploy.sh cleanup.sh

   - Agent execution role with proper permissions

# Set environment variables (optional)

2. **Agent Configuration**export AWS_REGION=us-west-2   # Target AWS region

   - Updated instruction with EMIR test_population schemaexport ENVIRONMENT=dev        # Deployment environment (dev, prod, etc.)

   - Output formatting (selects only relevant columns)export ALIAS=txt2sql         # Base alias used in resource names

   - Query execution enabled

# Deploy all stacks

3. **Frontend**./deploy.sh

   - Lambda proxy with bedrock-runtime:InvokeAgent permissions```

   - API Gateway

   - S3 static website hostingThe deployment script will:

   - Configured with correct agent ID and alias1. ✅ Validate AWS credentials

2. ✅ Deploy Athena, Glue, and S3 infrastructure

## Key Features3. ✅ Deploy Bedrock Agent and Lambda function

4. ✅ Deploy EC2 instance with Streamlit app

✅ **Automatic query execution** - Agent executes queries instead of just returning SQL5. ✅ Output all necessary configuration details

✅ **Smart column selection** - Returns 5-10 relevant columns, not all 200+

✅ **EMIR data support** - Includes test_population table schema### Post-Deployment Configuration

✅ **Production-ready permissions** - All IAM roles configured correctly

✅ **Idempotent deployment** - Safe to run multiple timesAfter deployment completes, configure the Streamlit app:



## Testing```bash

# Get the instance ID from deployment output

After deployment, test with these queries:export INSTANCE_ID="<your-instance-id>"

1. "How many records in test_population?"

2. "Show me 5 incidents with code E_A_C_09"# Connect to EC2

3. "Show me incidents where valuation currency is EUR"aws ec2-instance-connect ssh --instance-id $INSTANCE_ID --region us-west-2



Expected results:# Edit the invoke_agent.py file

- ✅ Query executes (not just SQL returned)sudo vi /home/ubuntu/app/streamlit_app/invoke_agent.py

- ✅ Results show 5-10 relevant columns (not 200+)

- ✅ Actual EMIR data displayed# Update these two lines with your actual IDs:

# agentId = "<YOUR-AGENT-ID>"

## Troubleshooting# agentAliasId = "<YOUR-ALIAS-ID>"



See `PRODUCTION-DEPLOYMENT-GUIDE.md` for detailed troubleshooting and architecture information.# Start the Streamlit app

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
        Alias="txt2sql-dev" \
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
        Alias="txt2sql-dev" \
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
ENVIRONMENT=dev AWS_REGION=us-west-2 ALIAS=txt2sql ./cleanup.sh
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

