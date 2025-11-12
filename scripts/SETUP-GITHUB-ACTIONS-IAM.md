# Setup IAM Permissions for GitHub Actions

Your GitHub Actions workflow needs IAM permissions to:
1. Push Docker images to ECR
2. Create/update App Runner services

## Quick Fix: Attach Policy to IAM User

The IAM user `github-actions-bedrock-helpdesk` needs these permissions.

### Option 1: Using AWS Console

1. **Go to IAM Console**:
   https://console.aws.amazon.com/iam/home?region=eu-central-1#/users/github-actions-bedrock-helpdesk

2. **Click "Add permissions" → "Attach policies directly"**

3. **Attach these AWS managed policies**:
   - `AmazonEC2ContainerRegistryPowerUser` (for ECR)
   - `AWSAppRunnerFullAccess` (for App Runner)

   OR create a custom policy (see Option 2)

### Option 2: Create Custom Policy (Recommended)

1. **Go to IAM → Policies → Create policy**

2. **Use JSON tab and paste this**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:eu-central-1:194561596031:repository/txt2sql-streamlit-dev"
    },
    {
      "Effect": "Allow",
      "Action": [
        "apprunner:CreateService",
        "apprunner:UpdateService",
        "apprunner:DescribeService",
        "apprunner:ListServices",
        "apprunner:StartDeployment"
      ],
      "Resource": "*"
    }
  ]
}
```

3. **Name it**: `GitHubActionsAppRunnerDeploy`

4. **Attach to user**: `github-actions-bedrock-helpdesk`

### Option 3: Using AWS CLI

```bash
# Create the policy
aws iam create-policy \
  --policy-name GitHubActionsAppRunnerDeploy \
  --policy-document file://scripts/github-actions-iam-policy.json \
  --region eu-central-1

# Attach to user
aws iam attach-user-policy \
  --user-name github-actions-bedrock-helpdesk \
  --policy-arn arn:aws:iam::194561596031:policy/GitHubActionsAppRunnerDeploy \
  --region eu-central-1
```

## Verify Permissions

After adding permissions, re-run the GitHub Actions workflow:
1. Go to Actions tab
2. Click on the failed workflow
3. Click "Re-run all jobs"

## Required Permissions Summary

- **ECR**: GetAuthorizationToken, Push/Pull images
- **App Runner**: Create/Update/Describe services, Start deployments

Once permissions are added, the workflow should complete successfully!

