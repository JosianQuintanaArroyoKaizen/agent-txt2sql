# ✅ Simplified Frontend - Permanent URLs

## 🌐 Your Permanent Frontend URL

**Share this with your stakeholders - it never changes:**

```
http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com
```

Or with HTTPS (CloudFront):
```
https://d2i7avdpb8ou01.cloudfront.net
```

---

## 🎯 How It Works (Simplified)

1. **User opens the frontend URL** (always the same URL)
2. **User types a question** and clicks Send
3. **Frontend sends only the question** to API Gateway
4. **Lambda (backend) uses its environment variables** for Agent ID and Alias ID
5. **Lambda calls Bedrock Agent** with the question
6. **Response is returned** to the frontend
7. **User sees the answer**

---

## ✨ What You DON'T Need to Manage

- ❌ No manual agent ID configuration
- ❌ No manual alias ID configuration  
- ❌ No config.js file needed
- ❌ No environment-specific URLs

---

## ✅ What Happens Automatically

When GitHub Actions deploys:
1. ✅ CloudFormation creates/updates the Bedrock agent
2. ✅ New Agent ID and Alias ID are generated
3. ✅ Lambda environment variables are updated automatically
4. ✅ Frontend files stay the same (no agent IDs in frontend)
5. ✅ URL stays the same

---

## 🧪 Test It

### Via Frontend:
1. Open: http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com
2. Type: "How many records are in test_population?"
3. Click Send

### Via API (curl):
```bash
curl -X POST https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat \
  -H "Content-Type: application/json" \
  -d '{"question":"How many records?"}'
```

---

## 📊 Current Backend Configuration

The Lambda automatically uses these (from environment variables):

| Variable | Value |
|----------|-------|
| AGENT_ID | ZDBQB8IQCO |
| AGENT_ALIAS_ID | O7D1KC5YFO |
| BEDROCK_REGION | eu-central-1 |

**You never need to update these manually!**

---

## 🚀 For Your Stakeholder

Simply share this URL:
```
http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com
```

It will:
- ✅ Always work (permanent URL)
- ✅ Always connect to the latest deployed agent
- ✅ Require no configuration
- ✅ Be ready to use immediately

