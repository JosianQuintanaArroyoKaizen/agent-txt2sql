#!/bin/bash

# Full Deployment Complete - Test Instructions

cat << 'EOF'
========================================
  DEPLOYMENT COMPLETE ✅
========================================

What was deployed:
  ✅ Lambda function updated with TSTALIASID
  ✅ IAM role has bedrock-runtime:InvokeAgent permission
  ✅ Frontend updated on S3
  ✅ API Gateway configured

Configuration:
  Agent ID: G1RWZFEZ4O
  Agent Alias: TSTALIASID (DRAFT version)
  Region: eu-central-1

========================================
  TEST NOW
========================================

1. Open in browser:
   http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com

2. Clear browser cache (Ctrl+Shift+R or Cmd+Shift+R)

3. Try these queries:

   Query 1: "How many records in test_population?"
   Expected: Should return 7867

   Query 2: "Show me 5 incidents with code E_A_C_09"
   Expected: Should show 5-10 columns (not 200+)
            Should include: incident_code, incident_description, uti_2_1, etc.

   Query 3: "Show me incidents where valuation currency is EUR"
   Expected: Should return filtered results with key columns

========================================
  TROUBLESHOOTING
========================================

If you still see "accessDeniedException":
  1. Wait another 30-60 seconds (IAM can take time)
  2. Clear browser cache completely
  3. Try in incognito/private window
  4. Check browser console (F12) for detailed errors

If you see all 200+ columns:
  1. Agent instruction takes 1-2 minutes to propagate
  2. Try a different query like "count records"
  3. The agent should learn to use SELECT with specific columns

========================================
  WHAT'S FIXED
========================================

✅ Lambda has bedrock-runtime:InvokeAgent permission
✅ Agent instruction updated to select only key columns
✅ Frontend using TSTALIASID (DRAFT with test_population)
✅ Deploy script fixed for future deployments

========================================

EOF

echo "Run this test now:"
echo "  1. Open: http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com"
echo "  2. Query: 'Show me 5 incidents with code E_A_C_09'"
