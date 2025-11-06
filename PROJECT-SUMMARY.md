# Project Summary - Bedrock Text2SQL Agent

## 📋 What Is This Project?

**Amazon Bedrock Text2SQL Agent** is an AI-powered application that allows users to query databases using natural language instead of writing SQL queries.

### Key Features

- 🗣️ **Natural Language to SQL**: Ask questions in plain English
- 🤖 **AI-Powered**: Uses Amazon Bedrock with Claude 3 Haiku
- ⚡ **Serverless**: Scales automatically with AWS managed services
- 🎨 **User-Friendly UI**: Web interface built with Streamlit
- 📊 **Real-time Results**: Instant query execution via Amazon Athena

### Example Usage

Instead of writing:
```sql
SELECT * FROM customers WHERE vip = 'yes' AND balance > 200;
```

Just ask:
```
Show me all VIP customers with a balance over 200 dollars
```

## 🏗️ Architecture

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  Streamlit UI   │  (EC2 Instance)
│  Port 8501      │
└────────┬────────┘
         │
         ▼
┌──────────────────────┐
│  Amazon Bedrock      │
│  Agent               │  ← AI orchestration
│  (Claude 3 Haiku)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  AWS Lambda          │  ← Query executor
│  (Python 3.12)       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Amazon Athena       │  ← SQL engine
│  + AWS Glue          │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Amazon S3           │  ← Data storage
│  (CSV files)         │
└──────────────────────┘
```

## 🎯 Use Cases

This solution is perfect for:

### 1. **Business Intelligence**
- Enable non-technical users to query data
- Self-service analytics for business analysts
- Ad-hoc reporting without SQL knowledge

### 2. **Customer Support**
- Support agents querying customer data quickly
- Natural language access to order histories
- Fast lookup of account information

### 3. **Healthcare Data**
- Query patient records (as demonstrated)
- Procedure and billing information
- Compliance-friendly data access

### 4. **E-commerce**
- Product inventory queries
- Customer purchase patterns
- Sales analytics

### 5. **Internal Tools**
- Employee data queries
- Project management lookups
- Resource allocation insights

## 📦 What You Get

### Infrastructure Components

| Component | Description | Purpose |
|-----------|-------------|---------|
| **S3 Buckets** | 4 buckets for data, outputs, replication, logs | Data storage and management |
| **Athena Database** | `athena_db` with 2 tables | SQL query engine |
| **Glue Tables** | `customers` and `procedures` | Data catalog |
| **Lambda Function** | Python 3.12, 1GB RAM, 1 min timeout | Query executor |
| **Bedrock Agent** | Claude 3 Haiku with action groups | AI orchestrator |
| **EC2 Instance** | t3.small Ubuntu 22.04 | Web UI host |
| **IAM Roles** | Multiple service roles | Security and permissions |
| **VPC** | Dedicated VPC with subnet | Network isolation |
| **Security Groups** | Port 8501 (web), 22 (SSH) | Access control |

### Deployment Tools

| File | Purpose |
|------|---------|
| `deploy.sh` | One-command deployment script |
| `cleanup.sh` | Remove all resources |
| `QUICKSTART.md` | 5-minute getting started guide |
| `DEPLOYMENT.md` | Detailed deployment instructions |
| `CICD-SETUP.md` | CI/CD pipeline configuration |
| `.github/workflows/deploy.yml` | GitHub Actions workflow |

### Sample Data

- **Customers Table**: Mock customer data with VIP status, balances
- **Procedures Table**: Medical procedures with categories, pricing, insurance

## 💰 Cost Breakdown

### Monthly Cost Estimate (Light Usage)

| Service | Usage | Cost |
|---------|-------|------|
| **EC2 (t3.small)** | 730 hours/month | $17.74 |
| **AWS Lambda** | 100K invocations | $0.20 |
| **Bedrock (Input)** | 300K tokens | $75.00 |
| **Bedrock (Output)** | 400K tokens | $500.00 |
| **S3 Storage** | <5GB | $0.12 |
| **Athena** | <1TB scanned | $0.50 |
| **Data Transfer** | <10GB | $0.90 |
| **Total** | | **~$594/month** |

### Cost Optimization Tips

1. **Stop EC2 when not in use**: Save ~$17/month
2. **Use Lambda only**: Remove EC2, save $17/month
3. **Reduce token usage**: Optimize prompts
4. **Use reserved instances**: Save 30-50% on EC2
5. **Enable S3 lifecycle**: Auto-archive old data

## 🚀 Deployment Options

### Option 1: Automated Deployment (Recommended)
```bash
./deploy.sh
```
**Time**: 10 minutes | **Difficulty**: Easy ⭐

### Option 2: Manual CloudFormation
Deploy each stack individually via AWS Console.
**Time**: 20 minutes | **Difficulty**: Medium ⭐⭐

### Option 3: CI/CD Pipeline
Set up GitHub Actions for automated deployments.
**Time**: 30 minutes | **Difficulty**: Advanced ⭐⭐⭐

## 📊 Sample Queries

### Customer Queries
```
1. "Show me all VIP customers"
2. "List customers with past due amounts over 70"
3. "How many customers have a balance over 300?"
```

### Procedure Queries
```
1. "Show me all procedures in the imaging category"
2. "Which procedures are not covered by insurance?"
3. "What's the average price of laboratory procedures?"
```

### Complex Queries
```
1. "Get all procedures that were not insured with customer names"
2. "Show me VIP customers and their procedure history"
3. "List all imaging procedures for customers with balances over 200"
```

## 🔐 Security Features

- ✅ **IAM Role-based access**: No hardcoded credentials
- ✅ **VPC isolation**: Dedicated network
- ✅ **Encrypted S3**: Server-side encryption (AES-256)
- ✅ **Versioned S3**: Data backup and recovery
- ✅ **Security Groups**: Restricted port access
- ✅ **CloudWatch Logging**: Audit trail
- ✅ **Resource replication**: Data durability

## 📈 Scalability

The solution automatically scales:

- **Lambda**: Concurrent executions (up to 1000 default)
- **Athena**: Serverless query processing
- **S3**: Unlimited storage
- **Bedrock**: Managed AI inference

For high traffic, consider:
- Add Application Load Balancer
- Use Auto Scaling Group for EC2
- Implement caching with ElastiCache
- Use RDS/DynamoDB for structured data

## 🔄 CI/CD Ready

### GitHub Actions Pipeline
- ✅ Validate templates on PR
- ✅ Deploy to dev on push to main
- ✅ Manual deploy to production
- ✅ Automated testing
- ✅ Rollback capabilities

### Future Enhancements
- [ ] Blue-green deployments
- [ ] A/B testing
- [ ] Performance monitoring
- [ ] Cost tracking
- [ ] Automated cleanup

## 🛠️ Customization Guide

### Add Your Own Data

1. **Prepare CSV files** with your schema
2. **Upload to S3** data bucket
3. **Update Glue tables** with new schema
4. **Modify agent prompt** with table definitions
5. **Test queries** in Bedrock console

### Change AI Model

```yaml
# In cfn/2-bedrock-agent-lambda-template.yaml
FoundationModel: 'anthropic.claude-3-sonnet-20240229-v1:0'  # More powerful
# or
FoundationModel: 'anthropic.claude-3-haiku-20240307-v1:0'   # Faster & cheaper
```

### Add Authentication

```python
# In streamlit_app/app.py
import streamlit_authenticator as stauth

authenticator = stauth.Authenticate(...)
name, authentication_status, username = authenticator.login('Login', 'main')

if authentication_status:
    # Show app
elif authentication_status == False:
    st.error('Username/password is incorrect')
```

### Connect to RDS/Redshift

Replace Athena with RDS/Redshift in Lambda:

```python
import psycopg2
conn = psycopg2.connect(
    host=os.environ['DB_HOST'],
    database=os.environ['DB_NAME'],
    user=os.environ['DB_USER'],
    password=os.environ['DB_PASSWORD']
)
```

## 📚 Documentation Structure

```
agent-txt2sql/
├── README.md                  # Original project README
├── QUICKSTART.md             # 5-minute setup guide (NEW)
├── DEPLOYMENT.md             # Detailed deployment (NEW)
├── CICD-SETUP.md             # CI/CD configuration (NEW)
├── PROJECT-SUMMARY.md        # This file (NEW)
├── deploy.sh                 # Deployment script (NEW)
├── cleanup.sh                # Cleanup script (NEW)
├── cfn/                      # CloudFormation templates
│   ├── 1-athena-glue-s3-template.yaml
│   ├── 2-bedrock-agent-lambda-template.yaml
│   └── 3-ec2-streamlit-template.yaml
├── function/                 # Lambda function code
│   └── lambda_function.py
├── streamlit_app/            # Streamlit UI
│   ├── app.py
│   ├── invoke_agent.py
│   └── requirements.txt
└── .github/                  # CI/CD workflows (NEW)
    └── workflows/
        └── deploy.yml
```

## 🎓 Learning Path

### Beginner
1. Deploy with `./deploy.sh`
2. Test sample queries
3. Review AWS Console resources

### Intermediate
1. Customize with your own data
2. Modify agent prompts
3. Add new action groups

### Advanced
1. Set up CI/CD pipeline
2. Implement authentication
3. Add monitoring and alerting
4. Multi-region deployment

## 🐛 Troubleshooting

See [QUICKSTART.md](QUICKSTART.md) for common issues and fixes.

## 📞 Support

- **Documentation**: Check MD files in this repo
- **AWS Support**: Use AWS Support Center
- **CloudWatch Logs**: Debug Lambda and agent issues
- **Stack Traces**: Check CloudFormation events

## 🎯 Next Steps

1. **Deploy**: Run `./deploy.sh`
2. **Test**: Try sample queries
3. **Customize**: Add your own data
4. **Automate**: Set up CI/CD
5. **Monitor**: Add CloudWatch dashboards
6. **Optimize**: Reduce costs

## 🤝 Contributing

To improve this solution:
1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## 📄 License

MIT-0 License - Free to use and modify

---

**Your AWS Environment**:
- Account: `194561596031`
- User: `josian.sandbox`
- Region: `us-west-2` (default)

**Ready to deploy?** Run `./deploy.sh` 🚀

