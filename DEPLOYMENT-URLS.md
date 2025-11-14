# Text2SQL Agent Deployment URLs

## DEV Environment

**Frontend URL:** http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com

**Configuration:**
- Agent ID: `PBVMU8ET2X`
- Alias ID: `DLK6WUSZ2Z`
- Region: `eu-central-1`
- Stack: `dev-eu-central-1-bedrock-agent-lambda-stack`
- Database: `txt2sql_dev_athena_db`

**API Gateway:**
- Endpoint: `https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat`

---

## PROD Environment

**Frontend URL:** http://txt2sql-frontend-prod-194561596031.s3-website.eu-central-1.amazonaws.com

**Configuration:**
- Agent ID: `ROSDJHLBKE`
- Alias ID: `GGLDC0ZSDL`
- Region: `eu-central-1`
- Stack: `prod-eu-central-1-bedrock-agent-lambda-stack`
- Database: `txt2sql_dev_athena_db` (shared with dev)

**API Gateway:**
- Endpoint: `https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat` (shared with dev)

---

## Features ✅

Both environments now have:
- ✅ Improved agent instruction that distinguishes greetings from data queries
- ✅ Proper greeting responses without executing SQL
- ✅ Correct table names (test_population, txt2sql_dev_customers, txt2sql_dev_procedures)
- ✅ Database context properly configured
- ✅ Claude 3 Haiku foundation model
- ✅ Separate frontend applications with environment labels

---

## Testing

**Greeting Test:**
```bash
# DEV
curl -X POST https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat \
  -H "Content-Type: application/json" \
  -d '{"agentId":"PBVMU8ET2X","agentAliasId":"DLK6WUSZ2Z","question":"Hi"}'

# PROD
curl -X POST https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat \
  -H "Content-Type: application/json" \
  -d '{"agentId":"ROSDJHLBKE","agentAliasId":"GGLDC0ZSDL","question":"Hi"}'
```

**Data Query Test:**
```bash
# DEV
curl -X POST https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat \
  -H "Content-Type: application/json" \
  -d '{"agentId":"PBVMU8ET2X","agentAliasId":"DLK6WUSZ2Z","question":"How many records?"}'

# PROD
curl -X POST https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat \
  -H "Content-Type: application/json" \
  -d '{"agentId":"ROSDJHLBKE","agentAliasId":"GGLDC0ZSDL","question":"How many records?"}'
```

---

## Deployment

**Dev (Automatic):**
- Push to `dev` branch triggers GitHub Actions auto-deployment

**Prod (Manual):**
- Use deploy-production.sh script or GitHub Actions manual trigger on `main` branch

---

## Cleanup

Old EC2/ECS stacks have been deleted:
- ❌ txt2sql-dev-ecs-alb-streamlit-stack
- ❌ txt2sql-dev-ec2-simple-streamlit-stack
- ❌ txt2sql-dev-ec2-alb-streamlit-stack
- ❌ prod-eu-central-1-ec2-streamlit-stack
- ❌ dev-eu-central-1-ec2-streamlit-stack

---

## Last Updated
November 14, 2025
