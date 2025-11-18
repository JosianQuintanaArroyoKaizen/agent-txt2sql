# 🌐 Permanent Frontend URLs - Quick Reference

## ✅ Your Permanent URLs (Never Change)

### 🔓 HTTP URL (S3 Direct)
```
http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com
```
**Use this for:** Quick access, testing, immediate updates

### 🔒 HTTPS URL (CloudFront) - **RECOMMENDED**
```
https://d2i7avdpb8ou01.cloudfront.net
```
**Use this for:** Production, secure access, best performance

### 🔌 API Endpoint
```
https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat
```

---

## 📊 Current Configuration

| Item | Value |
|------|-------|
| **Environment** | dev |
| **Agent ID** | ZDBQB8IQCO |
| **Agent Alias ID** | O7D1KC5YFO |
| **AWS Region** | eu-central-1 |
| **Last Updated** | 2025-11-17 14:28 UTC |

---

## ✨ What Changes vs What Stays

### ✅ PERMANENT (Never Changes):
- ✅ S3 URL: `http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com`
- ✅ CloudFront URL: `https://d2i7avdpb8ou01.cloudfront.net`
- ✅ API Gateway URL: `https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat`

### 🔄 Updates with Each Deployment:
- 🔄 Agent ID (when stack is recreated)
- 🔄 Agent Alias ID (when stack is recreated)
- 🔄 config.js content (automatically updated)

---

## 🧪 Quick Test Commands

### Test Frontend Config:
```bash
curl http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com/config.js
```

### Test API:
```bash
curl -X POST https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat \
  -H "Content-Type: application/json" \
  -d '{"agentId":"ZDBQB8IQCO","agentAliasId":"O7D1KC5YFO","question":"How many records?"}'
```

---

## 🚀 How to Use

1. **Open the HTTPS URL** in your browser: https://d2i7avdpb8ou01.cloudfront.net
2. The page will automatically load the agent configuration from `config.js`
3. Start asking questions!

**No manual configuration needed!** The frontend automatically:
- Loads Agent ID and Alias ID from config.js
- Connects to the correct API Gateway
- Maintains your session

---

## 🔧 When You Deploy Updates

The GitHub Actions pipeline automatically:
1. Creates/updates the Bedrock agent
2. Extracts new Agent ID and Alias ID
3. Generates new config.js with latest IDs
4. Uploads to S3 (immediate on HTTP URL)
5. CloudFront syncs within 5-10 minutes

**You never need to manually update these URLs!**

---

## 📱 Bookmark These

Save these URLs for easy access:
- **Production Use**: https://d2i7avdpb8ou01.cloudfront.net
- **Quick Testing**: http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com

