# Deploy to App Runner Without Local Docker

Since you don't have Docker on your company computer, here are two options:

## Option 1: AWS CloudShell (Easiest - Recommended)

AWS CloudShell has Docker pre-installed and runs in your browser.

### Steps:

1. **Open AWS CloudShell**:
   - Go to: https://console.aws.amazon.com/cloudshell/home?region=eu-central-1
   - Click "Open CloudShell" (top right)

2. **Clone your repository**:
   ```bash
   git clone <your-repo-url>
   cd agent-txt2sql
   ```

3. **Set environment variables**:
   ```bash
   export AGENT_ID=G1RWZFEZ4O
   export AGENT_ALIAS_ID=BW3ALCWPTJ
   export AWS_REGION=eu-central-1
   export ENVIRONMENT=dev
   ```

4. **Run deployment**:
   ```bash
   chmod +x scripts/deploy-to-apprunner.sh
   ./scripts/deploy-to-apprunner.sh
   ```

5. **Get your permanent URL** (wait 5-10 minutes first):
   ```bash
   aws apprunner list-services --region eu-central-1
   aws apprunner describe-service \
     --service-arn <SERVICE_ARN> \
     --region eu-central-1 \
     --query 'Service.ServiceUrl' \
     --output text
   ```

## Option 2: GitHub Actions (Automated CI/CD)

This will automatically deploy whenever you push changes to your repository.

### Setup:

1. **Add GitHub Secrets** (Settings → Secrets and variables → Actions):
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
   - `AGENT_ID` - `G1RWZFEZ4O`
   - `AGENT_ALIAS_ID` - `BW3ALCWPTJ`

2. **Push the workflow file**:
   ```bash
   git add .github/workflows/deploy-apprunner.yml
   git commit -m "Add App Runner deployment workflow"
   git push
   ```

3. **Trigger deployment**:
   - The workflow will run automatically on push to `main`
   - Or manually trigger: Actions → "Deploy Streamlit to AWS App Runner" → Run workflow

4. **Get your URL**:
   - Check the Actions tab for the deployment status
   - The workflow will output the service URL at the end

### Benefits of GitHub Actions:
- ✅ Fully automated - deploy on every push
- ✅ No local setup needed
- ✅ Builds happen in GitHub's cloud
- ✅ Easy to track deployments

## Option 3: AWS CodeBuild (Alternative)

If you prefer AWS-native CI/CD:

1. Create a CodeBuild project that:
   - Builds the Docker image
   - Pushes to ECR
   - Updates App Runner service

2. Can be triggered via:
   - CodeCommit push
   - S3 upload
   - Manual trigger
   - Scheduled

## Recommendation

**Use Option 1 (CloudShell)** for a quick one-time deployment, or **Option 2 (GitHub Actions)** if you want automated deployments going forward.

Both options will give you the same permanent URL: `https://xxxxx.eu-central-1.awsapprunner.com`

