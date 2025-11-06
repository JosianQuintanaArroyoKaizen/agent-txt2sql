# Quick Start Guide - Bedrock Text2SQL Agent

Get up and running in **5 minutes**! ⚡

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Bedrock model access enabled (Claude 3 Haiku)

## 3-Step Deployment

### Step 1: Enable Bedrock Models (One-time setup)

```bash
# Open Bedrock console
open https://console.aws.amazon.com/bedrock

# Navigate to: Model Access (left sidebar)
# Click: Enable specific models
# Select: ✓ Titan Embedding G1 - Text
#         ✓ Anthropic: Claude 3 Haiku
# Click: Submit
```

### Step 2: Deploy Infrastructure

```bash
# Clone repository (if not already done)
cd /home/jquintana-arroyo/git/agent-txt2sql

# Set your configuration (optional)
export AWS_REGION=us-west-2        # Your preferred region
export ENVIRONMENT=dev             # Deployment environment (e.g., dev, prod)
export ALIAS=my-txt2sql            # Base alias for resource naming

# Deploy everything with one command
./deploy.sh
```

**Expected time**: 8-12 minutes ⏱️

### Step 3: Configure & Launch Streamlit App

After deployment completes, you'll see output like:

```
Agent ID: ABCD1234EFGH
Agent Alias ID: ZYXW9876VUTS
EC2 Instance ID: i-0123456789abcdef
```

Now configure the app:

```bash
# Copy your Agent ID and Alias ID from deployment output above

# Connect to EC2
aws ec2-instance-connect ssh --instance-id <YOUR-INSTANCE-ID>

# Edit configuration
sudo nano /home/ubuntu/app/streamlit_app/invoke_agent.py

# Update these lines:
# agentId = "YOUR-AGENT-ID"
# agentAliasId = "YOUR-ALIAS-ID"
# Save: Ctrl+O, Enter, Ctrl+X

# Start the app
streamlit run /home/ubuntu/app/streamlit_app/app.py
```

Access your app at: `http://<PUBLIC-DNS>:8501` 🎉

## Test Queries

Try these sample queries in the app:

1. **Basic Query**
   ```
   Show me all procedures in the imaging category that are insured
   ```

2. **Aggregation**
   ```
   Return the number of procedures in the laboratory category
   ```

3. **Complex Query**
   ```
   Get me data of all procedures that were not insured, with customer names
   ```

4. **Filtering**
   ```
   Show me all customers that are VIP and have a balance over 200 dollars
   ```

## Architecture at a Glance

```
User Input → Streamlit UI → Bedrock Agent → Lambda → Athena → S3 Data
                                ↓
                        Natural Language → SQL
```

## Quick Commands Reference

### Deploy
```bash
./deploy.sh
```

### Cleanup (Delete everything)
```bash
ENVIRONMENT=$ENVIRONMENT AWS_REGION=$AWS_REGION ALIAS=$ALIAS ./cleanup.sh
```

### Check deployment status
```bash
aws cloudformation describe-stacks \
  --stack-name athena-glue-s3-stack \
  --region us-west-2
```

### View Agent in Console
```bash
# Get your Agent ID from deployment-info.txt
cat deployment-info.txt

# Then open:
open https://console.aws.amazon.com/bedrock/home?region=us-west-2#/agents
```

### Test Agent via CLI
```bash
aws bedrock-agent-runtime invoke-agent \
  --agent-id YOUR-AGENT-ID \
  --agent-alias-id YOUR-ALIAS-ID \
  --session-id test-session-1 \
  --input-text "Show me all customers" \
  --region us-west-2
```

### View Lambda Logs
```bash
aws logs tail /aws/lambda/AthenaQueryLambda-<ACCOUNT-ID> \
  --follow \
  --region us-west-2
```

## What Gets Deployed?

| Resource | Purpose | Cost |
|----------|---------|------|
| **S3 Buckets (4)** | Data storage, outputs, logging | ~$1/month |
| **Athena Database** | SQL query engine | Pay per query |
| **Lambda Function** | Query executor | ~$0.20/month |
| **Bedrock Agent** | AI orchestrator | Pay per token |
| **EC2 Instance (t3.small)** | Web UI host | ~$17/month |

**Total estimated**: ~$20-30/month for light usage

## Common Issues & Fixes

### ❌ "Model not available"
**Fix**: Enable model access in Bedrock console (Step 1 above)

### ❌ "Cannot connect to EC2"
**Fix**: Ensure your region's SSH CIDR is correct in template

### ❌ "Stack already exists"
**Fix**: Use `./cleanup.sh` first, then re-deploy

### ❌ "Insufficient permissions"
**Fix**: Ensure your AWS user has CloudFormation, S3, IAM, Bedrock permissions

### ❌ "Streamlit shows errors"
**Fix**: Verify Agent ID and Alias ID are correctly set in `invoke_agent.py`

## How It Works

1. **User** asks a question in natural language
2. **Streamlit** sends request to Bedrock Agent
3. **Agent** uses Claude 3 Haiku to understand intent
4. **Agent** generates SQL query based on schema
5. **Lambda** executes query via Athena
6. **Athena** queries CSV data in S3
7. **Results** returned to user via Streamlit

## Customization

### Use Your Own Data

1. Prepare CSV files with your schema
2. Upload to S3 bucket
3. Update Athena table definitions
4. Update agent prompt with new schema

### Change Model

Edit `cfn/2-bedrock-agent-lambda-template.yaml`:

```yaml
Parameters:
  FoundationModel:
    Default: 'anthropic.claude-3-sonnet-20240229-v1:0'  # Better quality
```

### Adjust Instance Size

Edit `deploy.sh` or template:

```bash
InstanceType="t3.medium"  # More powerful
```

## Cost Control

### Development
```bash
# Stop EC2 when not in use
aws ec2 stop-instances --instance-ids <INSTANCE-ID>

# Start when needed
aws ec2 start-instances --instance-ids <INSTANCE-ID>
```

### Production
- Use Spot Instances for EC2
- Enable S3 Intelligent Tiering
- Set CloudWatch alarms for costs

## Next Steps

- [ ] Deploy the infrastructure ✅
- [ ] Test with sample queries ✅
- [ ] Customize with your own data 📊
- [ ] Set up CI/CD pipeline 🚀
- [ ] Add authentication to Streamlit 🔐
- [ ] Create custom dashboards 📈

## Support & Resources

- **Detailed Guide**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- **CI/CD Setup**: See [CICD-SETUP.md](CICD-SETUP.md)
- **Main README**: See [README.md](README.md)
- **AWS Bedrock Docs**: https://docs.aws.amazon.com/bedrock/
- **CloudWatch Logs**: Check for errors and debugging

## Cleanup

When you're done testing:

```bash
./cleanup.sh
# Confirm with 'yes' when prompted
```

This removes ALL resources and stops charges.

---

**Ready to deploy?** Run `./deploy.sh` and let's go! 🚀

Questions? Check the deployment output and logs first, or review the full documentation.

