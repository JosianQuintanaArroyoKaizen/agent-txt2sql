# Deploy Streamlit to AWS App Runner

This guide will help you deploy your Streamlit app to AWS App Runner for a permanent, always-available URL.

## Prerequisites

- Docker installed and running locally
- AWS CLI configured with appropriate permissions
- Bedrock Agent ID and Alias ID (from your deployment)

## Quick Deployment

1. **Get your Agent ID and Alias ID**:
   ```bash
   # Check your Bedrock console or run:
   aws bedrock-agent list-agents --region eu-central-1 --query 'agentSummaries[*].[agentId,agentName]' --output table
   ```

2. **Run the deployment script**:
   ```bash
   cd /home/jquintana-arroyo/git/agent-txt2sql
   ./scripts/deploy-to-apprunner.sh
   ```

   The script will:
   - Create an ECR repository (if needed)
   - Build a Docker image of your Streamlit app
   - Push the image to ECR
   - Create/update an App Runner service
   - Provide you with the permanent URL

3. **Wait for deployment** (5-10 minutes):
   ```bash
   # Get your service URL
   aws apprunner describe-service \
     --service-arn <SERVICE_ARN> \
     --region eu-central-1 \
     --query 'Service.ServiceUrl' \
     --output text
   ```

## Manual Steps (Alternative)

If you prefer to deploy manually:

### 1. Create ECR Repository
```bash
aws ecr create-repository \
  --repository-name txt2sql-streamlit-dev \
  --region eu-central-1 \
  --image-scanning-configuration scanOnPush=true
```

### 2. Build and Push Docker Image
```bash
# Login to ECR
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com

# Build image
cd streamlit_app
docker build -t txt2sql-streamlit-dev:latest .

# Tag and push
docker tag txt2sql-streamlit-dev:latest \
  <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/txt2sql-streamlit-dev:latest

docker push <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/txt2sql-streamlit-dev:latest
```

### 3. Create App Runner Service
```bash
aws apprunner create-service \
  --service-name txt2sql-streamlit-dev \
  --source-configuration '{
    "ImageRepository": {
      "ImageIdentifier": "<ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/txt2sql-streamlit-dev:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8501",
        "RuntimeEnvironmentVariables": {
          "AWS_REGION": "eu-central-1",
          "AGENT_ID": "<YOUR_AGENT_ID>",
          "AGENT_ALIAS_ID": "<YOUR_ALIAS_ID>"
        }
      }
    },
    "AutoDeploymentsEnabled": true
  }' \
  --instance-configuration '{
    "Cpu": "0.25 vCPU",
    "Memory": "0.5 GB"
  }' \
  --region eu-central-1
```

## Benefits of App Runner

✅ **Permanent URL**: Get a stable `https://xxxxx.eu-central-1.awsapprunner.com` URL  
✅ **Always Available**: No need to manually start/stop the service  
✅ **Auto-scaling**: Automatically scales based on traffic  
✅ **Managed Service**: No EC2 management, patching, or monitoring needed  
✅ **Cost Effective**: Pay only for what you use (~$5-10/month for low traffic)  

## Updating the Service

After making changes to your Streamlit app:

```bash
# Rebuild and push new image
cd streamlit_app
docker build -t txt2sql-streamlit-dev:latest .
docker tag txt2sql-streamlit-dev:latest \
  <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/txt2sql-streamlit-dev:latest
docker push <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/txt2sql-streamlit-dev:latest

# App Runner will auto-deploy if AutoDeploymentsEnabled is true
# Or manually trigger:
aws apprunner start-deployment \
  --service-arn <SERVICE_ARN> \
  --region eu-central-1
```

## Monitoring

View logs:
```bash
aws apprunner list-operations \
  --service-arn <SERVICE_ARN> \
  --region eu-central-1
```

Check service status:
```bash
aws apprunner describe-service \
  --service-arn <SERVICE_ARN> \
  --region eu-central-1
```

## Cost Estimate

- **0.25 vCPU, 0.5 GB RAM**: ~$0.007/hour (~$5/month) for minimal instance
- **Traffic**: Additional charges for requests/data transfer
- **ECR Storage**: ~$0.10/GB/month for Docker images

Total: ~$5-10/month for light usage (much cheaper than running EC2 24/7)

## Troubleshooting

**Service won't start**:
- Check CloudWatch logs in App Runner console
- Verify environment variables (AGENT_ID, AGENT_ALIAS_ID) are set correctly
- Ensure ECR image is accessible

**Can't access URL**:
- Wait 5-10 minutes for initial deployment
- Check service status: `aws apprunner describe-service --service-arn <ARN>`
- Verify security settings allow public access

**Image build fails**:
- Ensure Dockerfile is in `streamlit_app/` directory
- Check that `requirements.txt` exists and is valid
- Verify all dependencies are listed

