# Frontend URLs - PERMANENT

These URLs are **permanent** and will NOT change with deployments.
Only the agent configuration (Agent ID and Alias ID) gets updated automatically.

## Production Frontend URLs

### HTTP (S3 Website)
```
http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com
```
- No SSL certificate
- Direct S3 website hosting
- Fastest to update (immediate)

### HTTPS (CloudFront) - RECOMMENDED
```
https://d2i7avdpb8ou01.cloudfront.net
```
- SSL/HTTPS enabled
- Global CDN distribution
- Best performance worldwide
- Takes 5-10 minutes to reflect S3 changes (caching)

### API Gateway Endpoint
```
https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat
```

## Current Agent Configuration

**Environment:** dev  
**Agent ID:** ZDBQB8IQCO  
**Agent Alias ID:** O7D1KC5YFO  
**Region:** eu-central-1

Last Updated: 2025-11-17

## How It Works

1. **Frontend files** (index.html, app.js, config.js) are stored in S3 bucket: `txt2sql-frontend-194561596031`
2. **CloudFront** distributes these files globally via HTTPS
3. **config.js** contains the agent configuration (auto-generated from CloudFormation)
4. **Lambda proxy** (`txt2sql-frontend-proxy`) handles API requests
5. **API Gateway** provides the stable endpoint for the Lambda

## Deployment Updates

When you deploy updates:
- Agent ID/Alias ID may change (new CloudFormation stack)
- Frontend files get updated with new config.js
- **URLs stay the same** ✅
- S3 updates are immediate
- CloudFront cache takes ~5-10 minutes to refresh

## Testing

Test the API directly:
```bash
curl -X POST https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat \
  -H "Content-Type: application/json" \
  -d '{"agentId":"ZDBQB8IQCO","agentAliasId":"O7D1KC5YFO","question":"How many records?"}'
```

## Troubleshooting

If the frontend doesn't work:
1. Check if config.js is loaded: Open browser console and type `window.AGENT_CONFIG`
2. Clear browser cache (CloudFront caching)
3. Try the S3 URL directly (bypasses CloudFront cache)
4. Check Lambda logs: `/aws/lambda/txt2sql-frontend-proxy`
