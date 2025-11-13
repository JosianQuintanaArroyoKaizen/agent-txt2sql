# Simple Text2SQL Agent Frontend

A minimal, functional frontend for the Bedrock Text2SQL Agent. No WebSockets, no complex dependencies - just HTML, CSS, and JavaScript.

## Features

- ✅ Simple, clean interface
- ✅ Conversation history (stored in browser)
- ✅ Direct Bedrock Agent API calls
- ✅ Configurable Agent ID and Alias ID
- ✅ Works with AWS Amplify or S3 + CloudFront
- ✅ Stable URL (doesn't change)

## Deployment Options

### Option 1: AWS Amplify (Recommended - Easiest)

1. **Install Amplify CLI** (if not already installed):
   ```bash
   npm install -g @aws-amplify/cli
   ```

2. **Initialize Amplify**:
   ```bash
   cd frontend
   amplify init
   # Follow prompts:
   # - Project name: txt2sql-frontend
   # - Environment: dev
   # - Default editor: (your choice)
   # - App type: javascript
   # - Framework: none
   # - Source directory: .
   # - Distribution directory: .
   # - Build command: (leave empty)
   # - Start command: (leave empty)
   ```

3. **Add hosting**:
   ```bash
   amplify add hosting
   # Select: Hosting with Amplify Console
   ```

4. **Deploy**:
   ```bash
   amplify publish
   ```

5. **Get your URL**: Amplify will provide a stable URL like `https://main.xxxxx.amplifyapp.com`

### Option 2: S3 + CloudFront (Simple & Free)

1. **Create S3 bucket**:
   ```bash
   aws s3 mb s3://txt2sql-frontend-$(date +%s) --region eu-central-1
   ```

2. **Upload files**:
   ```bash
   cd frontend
   aws s3 sync . s3://your-bucket-name --exclude "README.md"
   ```

3. **Enable static website hosting**:
   ```bash
   aws s3 website s3://your-bucket-name \
     --index-document index.html \
     --error-document index.html
   ```

4. **Create CloudFront distribution** (for HTTPS and stable URL):
   - Go to CloudFront console
   - Create distribution
   - Origin: Your S3 bucket
   - Default root object: `index.html`
   - Get your CloudFront URL

### Option 3: Manual S3 Upload (Quickest)

1. **Upload to S3**:
   ```bash
   cd frontend
   aws s3 cp index.html s3://your-bucket-name/
   aws s3 cp app.js s3://your-bucket-name/
   ```

2. **Make bucket public** (for testing):
   ```bash
   aws s3api put-bucket-policy --bucket your-bucket-name --policy '{
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": "*",
       "Action": "s3:GetObject",
       "Resource": "arn:aws:s3:::your-bucket-name/*"
     }]
   }'
   ```

3. **Access via**: `http://your-bucket-name.s3-website-eu-central-1.amazonaws.com`

## AWS Credentials Setup

The frontend needs AWS credentials to call Bedrock. You have two options:

### Option A: AWS Cognito Identity Pool (Recommended for Production)

1. **Create Cognito Identity Pool**:
   - Go to AWS Cognito Console
   - Create Identity Pool
   - Enable "Unauthenticated access"
   - Note the Identity Pool ID

2. **Attach IAM policy to unauthenticated role**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": [
         "bedrock:InvokeAgent",
         "bedrock-runtime:InvokeAgent"
       ],
       "Resource": "*"
     }]
   }
   ```

3. **Update `app.js`**:
   Replace `YOUR_IDENTITY_POOL_ID` with your actual Identity Pool ID

### Option B: Use AWS CLI Credentials (Development Only)

For testing, you can use your AWS CLI credentials, but this is **NOT recommended for production**.

## Configuration

The frontend allows users to configure:
- Agent ID (default: G1RWZFEZ4O)
- Agent Alias ID (default: BW3ALCWPTJ)
- AWS Region (default: eu-central-1)

Configuration is saved in browser localStorage.

## Troubleshooting

**"AWS credentials not configured"**:
- Set up Cognito Identity Pool (Option A above)
- Or ensure AWS CLI credentials are available (development only)

**"Access denied" or "403 Forbidden"**:
- Check IAM permissions for Bedrock Agent
- Ensure the Cognito unauthenticated role has Bedrock permissions

**"Agent not found" or "404"**:
- Verify Agent ID and Alias ID are correct
- Check that the agent exists in the specified region

## Quick Deploy Script

I can create a deployment script if you'd like. Just ask!

