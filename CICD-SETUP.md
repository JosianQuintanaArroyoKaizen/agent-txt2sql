# CI/CD Pipeline Setup Guide

This guide will help you set up automated deployments for the Bedrock Text2SQL Agent using GitHub Actions.

## Overview

The CI/CD pipeline will:
- ✅ Validate CloudFormation templates on every PR
- ✅ Deploy to development environment on push to `main`
- ✅ Deploy to production on manual trigger
- ✅ Provide deployment summaries

## Prerequisites

1. GitHub repository with your code
2. AWS account with appropriate permissions
3. AWS IAM credentials for deployment

## Setup Steps

### 1. Create AWS IAM User for CI/CD

Create an IAM user with programmatic access and attach the following policies:

```bash
# Create IAM user
aws iam create-user --user-name github-actions-bedrock-txt2sql

# Attach required policies (adjust for least privilege)
aws iam attach-user-policy \
  --user-name github-actions-bedrock-txt2sql \
  --policy-arn arn:aws:iam::aws:policy/CloudFormationFullAccess

aws iam attach-user-policy \
  --user-name github-actions-bedrock-txt2sql \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-user-policy \
  --user-name github-actions-bedrock-txt2sql \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

aws iam attach-user-policy \
  --user-name github-actions-bedrock-txt2sql \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess

# Create access keys
aws iam create-access-key --user-name github-actions-bedrock-txt2sql
```

**Note**: For production, create a more restrictive custom policy with only required permissions.

### 2. Configure GitHub Secrets

Go to your GitHub repository: **Settings** → **Secrets and variables** → **Actions**

Add the following secrets:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key

### 3. Set Up GitHub Environments (Optional)

For better control and approval workflows:

1. Go to **Settings** → **Environments**
2. Create two environments:
   - `development` (auto-deploy on push)
   - `production` (requires manual approval)

For production:
- Enable **Required reviewers**
- Add yourself or team members as reviewers

### 4. Customize Workflow

Edit `.github/workflows/deploy.yml` to match your needs:

```yaml
env:
  AWS_REGION: us-west-2          # Change to your preferred region
  ALIAS: txt2sql-demo            # Change to your alias
```

## Pipeline Stages

### Stage 1: Validate (on every PR and push)

- Validates all CloudFormation template syntax
- Runs on every pull request and push
- No AWS resources created

### Stage 2: Deploy to Development (on push to main)

- Automatically deploys all stacks to dev environment
- Stack names suffixed with `-dev`
- Resources tagged with environment

### Stage 3: Deploy to Production (manual trigger)

- Requires manual approval (if environment protection is enabled)
- Deploys to production environment
- Stack names suffixed with `-prod`

## Triggering Deployments

### Automatic Deployment (Dev)

Push to main branch:
```bash
git add .
git commit -m "Update infrastructure"
git push origin main
```

### Manual Deployment (Prod)

1. Go to **Actions** tab in GitHub
2. Select **Deploy Bedrock Text2SQL Agent** workflow
3. Click **Run workflow**
4. Select branch and environment
5. Click **Run workflow** button

## Monitoring Deployments

### View Workflow Status

1. Go to **Actions** tab in GitHub repository
2. Click on the running workflow
3. View logs for each step

### View AWS Resources

Check CloudFormation stacks:
```bash
aws cloudformation list-stacks --region us-west-2
```

Get stack status:
```bash
aws cloudformation describe-stacks \
  --stack-name athena-glue-s3-stack-dev \
  --region us-west-2
```

## Advanced CI/CD Features

### Multi-Region Deployment

To deploy to multiple regions, create a matrix strategy:

```yaml
strategy:
  matrix:
    region: [us-west-2, us-east-1, eu-west-1]
steps:
  - name: Deploy to ${{ matrix.region }}
    run: |
      aws cloudformation deploy \
        --region ${{ matrix.region }} \
        ...
```

### Blue-Green Deployment

For zero-downtime deployments:

1. Deploy new stack with different name
2. Update DNS/load balancer to point to new stack
3. Monitor for issues
4. Delete old stack if successful

### Rollback Strategy

Automatic rollback on failure:

```yaml
- name: Deploy with Rollback
  run: |
    aws cloudformation deploy \
      --stack-name my-stack \
      --on-failure ROLLBACK \
      ...
```

### Infrastructure Testing

Add testing after deployment:

```yaml
- name: Test Deployment
  run: |
    # Wait for resources to be ready
    sleep 60
    
    # Test Bedrock agent
    aws bedrock-agent get-agent \
      --agent-id ${{ steps.agent.outputs.agent_id }} \
      --region ${{ env.AWS_REGION }}
    
    # Test Lambda function
    aws lambda invoke \
      --function-name AthenaQueryLambda-${{ steps.account.outputs.account_id }} \
      --region ${{ env.AWS_REGION }} \
      response.json
```

## Cost Management

### Automatic Cleanup of Dev Environment

Add a scheduled workflow to clean up dev resources:

```yaml
name: Cleanup Dev Environment

on:
  schedule:
    - cron: '0 0 * * 0'  # Every Sunday at midnight
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete Dev Stacks
        run: |
          aws cloudformation delete-stack --stack-name ec2-streamlit-stack-dev
          aws cloudformation delete-stack --stack-name bedrock-agent-lambda-stack-dev
          aws cloudformation delete-stack --stack-name athena-glue-s3-stack-dev
```

### Cost Alerting

Set up AWS Budgets alerts in your CI/CD:

```yaml
- name: Check AWS Budget
  run: |
    BUDGET_THRESHOLD=$(aws budgets describe-budget \
      --account-id ${{ steps.account.outputs.account_id }} \
      --budget-name "Monthly-Budget" \
      --query 'Budget.CalculatedSpend.ActualSpend.Amount' \
      --output text)
    
    if (( $(echo "$BUDGET_THRESHOLD > 100" | bc -l) )); then
      echo "::warning::Budget threshold exceeded!"
    fi
```

## Security Best Practices

### 1. Use OIDC Instead of Long-Lived Credentials

Replace static credentials with OIDC:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
    aws-region: us-west-2
```

### 2. Enable CloudFormation Stack Policy

Protect critical resources from accidental updates:

```json
{
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "Update:Delete",
      "Principal": "*",
      "Resource": "LogicalResourceId/S3Bucket"
    }
  ]
}
```

### 3. Use Parameter Store for Secrets

Store sensitive configuration in AWS Systems Manager Parameter Store:

```yaml
- name: Get Parameters
  run: |
    AGENT_ID=$(aws ssm get-parameter \
      --name /bedrock-txt2sql/agent-id \
      --query 'Parameter.Value' \
      --output text)
```

## Alternative CI/CD Tools

### AWS CodePipeline

Use `buildspec.yml`:

```yaml
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.12
  build:
    commands:
      - chmod +x deploy.sh
      - ./deploy.sh
artifacts:
  files:
    - deployment-info.txt
```

### GitLab CI/CD

Use `.gitlab-ci.yml`:

```yaml
deploy:
  stage: deploy
  image: amazon/aws-cli
  script:
    - chmod +x deploy.sh
    - ./deploy.sh
  only:
    - main
```

### Jenkins

Use `Jenkinsfile`:

```groovy
pipeline {
  agent any
  stages {
    stage('Deploy') {
      steps {
        sh 'chmod +x deploy.sh'
        sh './deploy.sh'
      }
    }
  }
}
```

## Troubleshooting

### Issue: GitHub Actions fails with permission error
**Solution**: Verify IAM user has required permissions

### Issue: Stack already exists error
**Solution**: Use `aws cloudformation deploy` which handles create/update automatically

### Issue: Workflow times out
**Solution**: Increase timeout in workflow file:
```yaml
timeout-minutes: 60
```

## Next Steps

1. ✅ Set up GitHub secrets
2. ✅ Commit workflow file to repository
3. ✅ Push to trigger first deployment
4. ✅ Monitor CloudFormation stacks
5. ✅ Configure production environment protections

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

---

**Ready to automate your deployments!** 🚀

