# Current Working Configuration

**Date**: November 14, 2025  
**Status**: ✅ WORKING

## Environment: Dev (eu-central-1)

### Agent Configuration
- **Agent ID**: NZI3ZPKNUW
- **Alias Name**: txt2sql-dev-eu-central-1-alias
- **Alias ID**: PA5UI5F0DM
- **Foundation Model**: anthropic.claude-3-haiku-20240307-v1:0
- **Region**: eu-central-1

### Endpoints
- **Frontend URL**: http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com
- **API Gateway**: https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat
- **Lambda Proxy**: txt2sql-frontend-proxy

### Lambda Environment Variables
```
AGENT_ID=NZI3ZPKNUW
AGENT_ALIAS_NAME=txt2sql-dev-eu-central-1-alias
BEDROCK_REGION=eu-central-1
```

### Database
- **Database**: txt2sql_dev_athena_db
- **Main Table**: test_population (7,867 EMIR records)
- **S3 Output**: s3://sl-athena-output-txt2sql-dev-194561596031-eu-central-1/

## Key Features Working
✅ Agent responds to greetings without executing SQL  
✅ Agent uses actual table names (test_population)  
✅ Athena queries execute with proper database context  
✅ Frontend communicates with API Gateway  
✅ Lambda dynamically resolves alias by name  

## Tested Queries
- "Hi" → Returns greeting
- "How many records are there?" → Returns 7867
- "Show me 3 incident reports" → Returns data

## For Production Deployment

When deploying to prod:
1. Push changes to `dev` branch (auto-deploys dev environment)
2. Run `bash deploy-production.sh` for manual prod deployment
3. Update frontend with new prod agent IDs
4. Clear browser cache: `localStorage.clear(); location.reload()`

## Known Issues/Limitations
- Claude 3.7 Sonnet has tool name validation issues (use Claude 3 Haiku)
- API Gateway has 29 second timeout limit
- Agent alias must be recreated when changing models across versions
- Frontend requires localStorage clear when agent IDs change

## Important Notes
- Agent instruction emphasizes using real table names (not placeholders)
- Lambda resolves alias by name to avoid constant ID changes
- Database name is set in Lambda env var and passed to Athena
