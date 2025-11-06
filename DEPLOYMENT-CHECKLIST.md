# Deployment Checklist ✅

Use this checklist to ensure a smooth deployment of your Bedrock Text2SQL Agent.

## Pre-Deployment (5 minutes)

### AWS Account Setup
- [ ] AWS account with admin access
- [ ] AWS CLI installed: `aws --version`
- [ ] AWS credentials configured: `aws sts get-caller-identity`
- [ ] Confirmed account ID: `194561596031`
- [ ] Confirmed user: `josian.sandbox`

### Region Selection
- [ ] Chosen target region (default: `us-west-2`)
- [ ] Verified Bedrock is available in region
- [ ] Set environment variable: `export AWS_REGION=us-west-2`

### Bedrock Model Access (CRITICAL)
- [ ] Logged into AWS Console
- [ ] Navigated to Amazon Bedrock service
- [ ] Clicked "Model Access" in left sidebar
- [ ] Clicked "Enable specific models"
- [ ] Selected **Titan Embedding G1 - Text**
- [ ] Selected **Anthropic: Claude 3 Haiku**
- [ ] Clicked "Submit" and confirmed "Access granted" status

### Project Setup
- [ ] Cloned/navigated to project: `cd /home/jquintana-arroyo/git/agent-txt2sql`
- [ ] Scripts are executable: `ls -la deploy.sh cleanup.sh`
- [ ] Reviewed CloudFormation templates in `cfn/` directory
- [ ] Read QUICKSTART.md

## Deployment (10 minutes)

### Environment Configuration
- [ ] Set alias (optional): `export ALIAS=my-txt2sql`
- [ ] Confirmed AWS region: `echo $AWS_REGION`
- [ ] Reviewed deployment script: `cat deploy.sh`

### Execute Deployment
- [ ] Run deployment: `./deploy.sh`
- [ ] Monitor progress (8-12 minutes expected)
- [ ] Watched for any error messages
- [ ] Confirmed Stack 1 completion (Athena/Glue/S3)
- [ ] Confirmed Stack 2 completion (Bedrock Agent/Lambda)
- [ ] Confirmed Stack 3 completion (EC2/Streamlit)

### Capture Deployment Info
- [ ] Saved Agent ID from output
- [ ] Saved Agent Alias ID from output
- [ ] Saved EC2 Instance ID from output
- [ ] Saved Public DNS from output
- [ ] Reviewed `deployment-info.txt` file

## Post-Deployment Configuration (5 minutes)

### Streamlit App Setup
- [ ] Connected to EC2: `aws ec2-instance-connect ssh --instance-id <INSTANCE-ID>`
- [ ] Navigated to app directory: `cd /home/ubuntu/app/streamlit_app`
- [ ] Edited invoke_agent.py: `sudo nano invoke_agent.py`
- [ ] Updated `agentId` with your Agent ID
- [ ] Updated `agentAliasId` with your Alias ID
- [ ] Saved file (Ctrl+O, Enter, Ctrl+X)
- [ ] Verified changes: `grep "agentId\|agentAliasId" invoke_agent.py`

### Launch Application
- [ ] Started Streamlit: `streamlit run /home/ubuntu/app/streamlit_app/app.py`
- [ ] Noted the External URL
- [ ] Opened browser to: `http://<PUBLIC-DNS>:8501`
- [ ] Verified UI loaded correctly

## Testing (5 minutes)

### Basic Functionality
- [ ] Tested Query 1: "Show me all VIP customers"
- [ ] Verified results displayed correctly
- [ ] Tested Query 2: "Show me procedures in the imaging category that are insured"
- [ ] Reviewed trace data in sidebar
- [ ] Tested Query 3: "Return the number of procedures in the laboratory category"

### AWS Console Verification
- [ ] Opened Bedrock console: https://console.aws.amazon.com/bedrock
- [ ] Navigated to Agents section
- [ ] Found your agent in the list
- [ ] Tested in console UI
- [ ] Reviewed agent configuration

### CloudFormation Verification
- [ ] Opened CloudFormation console
- [ ] Verified all 3 stacks show "CREATE_COMPLETE"
- [ ] Reviewed stack outputs
- [ ] Checked for any warnings

### S3 Verification
- [ ] Opened S3 console
- [ ] Verified data bucket exists
- [ ] Checked CSV files are uploaded
- [ ] Verified Athena output bucket exists

### Lambda Verification
- [ ] Opened Lambda console
- [ ] Found `AthenaQueryLambda-<ACCOUNT-ID>` function
- [ ] Checked recent invocations
- [ ] Reviewed CloudWatch logs

## Optional: CI/CD Setup (30 minutes)

### GitHub Repository
- [ ] Created GitHub repository (or use existing)
- [ ] Pushed code to repository
- [ ] Verified `.github/workflows/deploy.yml` exists

### GitHub Secrets
- [ ] Navigated to Settings → Secrets and variables → Actions
- [ ] Added `AWS_ACCESS_KEY_ID` secret
- [ ] Added `AWS_SECRET_ACCESS_KEY` secret
- [ ] Verified secrets are saved

### GitHub Environments (Optional)
- [ ] Created `development` environment
- [ ] Created `production` environment
- [ ] Added required reviewers for production
- [ ] Set environment-specific secrets

### Pipeline Testing
- [ ] Pushed to `main` branch
- [ ] Monitored GitHub Actions workflow
- [ ] Verified successful deployment
- [ ] Checked deployment summary

## Documentation Review

### Read Documentation
- [ ] Read QUICKSTART.md
- [ ] Read DEPLOYMENT.md
- [ ] Read CICD-SETUP.md
- [ ] Read PROJECT-SUMMARY.md
- [ ] Reviewed original README.md

### Save Important Information
- [ ] Bookmarked Streamlit URL
- [ ] Saved Agent ID in secure location
- [ ] Noted EC2 Instance ID
- [ ] Documented any custom configurations
- [ ] Created team documentation (if applicable)

## Security Review

### IAM Roles
- [ ] Reviewed Lambda execution role permissions
- [ ] Reviewed Bedrock agent role permissions
- [ ] Reviewed EC2 instance role permissions
- [ ] Verified least privilege principles

### Network Security
- [ ] Reviewed security group rules
- [ ] Verified SSH CIDR is appropriate for your region
- [ ] Checked VPC configuration
- [ ] Confirmed public access is intended

### Data Security
- [ ] Verified S3 bucket encryption is enabled
- [ ] Checked S3 bucket public access is blocked
- [ ] Reviewed IAM policies for data access
- [ ] Confirmed sensitive data handling (if applicable)

## Cost Management

### Budget Setup
- [ ] Created AWS Budget for the project
- [ ] Set cost alert threshold
- [ ] Configured email notifications
- [ ] Reviewed cost allocation tags

### Resource Tagging
- [ ] Verified resources have appropriate tags
- [ ] Added project-specific tags (optional)
- [ ] Tagged resources for cost allocation

### Cost Optimization
- [ ] Documented EC2 stop/start commands
- [ ] Reviewed Lambda memory settings
- [ ] Checked S3 lifecycle policies
- [ ] Planned cleanup schedule

## Monitoring & Alerts

### CloudWatch Setup
- [ ] Opened CloudWatch console
- [ ] Found Lambda logs: `/aws/lambda/AthenaQueryLambda-<ACCOUNT-ID>`
- [ ] Set up log insights query (optional)
- [ ] Created dashboard (optional)

### Alarms (Optional)
- [ ] Created alarm for Lambda errors
- [ ] Created alarm for high Lambda duration
- [ ] Created alarm for Bedrock throttling
- [ ] Set up SNS topic for notifications

## Backup & Recovery

### Backup Strategy
- [ ] Confirmed S3 versioning is enabled
- [ ] Verified replication bucket exists
- [ ] Documented recovery procedures
- [ ] Tested restore process (optional)

### Disaster Recovery
- [ ] Saved CloudFormation templates in version control
- [ ] Documented manual configuration steps
- [ ] Created runbook for recovery
- [ ] Identified RTO/RPO requirements

## Knowledge Transfer

### Team Onboarding
- [ ] Shared documentation with team
- [ ] Provided access to AWS resources
- [ ] Scheduled demo session
- [ ] Created training materials

### Operational Procedures
- [ ] Documented deployment process
- [ ] Created troubleshooting guide
- [ ] Established escalation path
- [ ] Set up on-call rotation (if applicable)

## Final Checks

### Functionality
- [ ] All sample queries work correctly
- [ ] UI is responsive and user-friendly
- [ ] Error handling works as expected
- [ ] Performance is acceptable

### Compliance
- [ ] Meets security requirements
- [ ] Follows organizational policies
- [ ] Data handling is compliant
- [ ] Audit logging is enabled

### Production Readiness
- [ ] Load testing completed (if going to prod)
- [ ] Disaster recovery tested
- [ ] Monitoring is in place
- [ ] Runbooks are documented

## Cleanup (Optional)

If you're just testing and want to remove everything:

- [ ] Run cleanup script: `./cleanup.sh`
- [ ] Confirm deletion with 'yes'
- [ ] Verify all stacks deleted
- [ ] Check S3 buckets are empty
- [ ] Confirm no lingering resources

---

## Status Summary

### Deployment Date: _______________
### Deployed By: josian.sandbox
### Environment: Development / Production (circle one)
### Status: ⬜ Not Started | ⬜ In Progress | ⬜ Complete

### Resources Created:
- Agent ID: _______________________________
- Alias ID: _______________________________
- Instance ID: ____________________________
- App URL: http://_________________________:8501

### Notes:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

---

**Congratulations! Your Bedrock Text2SQL Agent is ready! 🎉**

Next steps:
1. Start using the application
2. Customize with your own data
3. Set up CI/CD pipeline
4. Share with your team

Questions? Review the documentation or check AWS CloudWatch logs.

