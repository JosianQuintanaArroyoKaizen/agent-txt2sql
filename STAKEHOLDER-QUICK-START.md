# Text2SQL Agent - Quick Start for Stakeholders

## 🚀 Access the Application

**URL:** http://txt2sql-frontend-194561596031.s3-website.eu-central-1.amazonaws.com

Just click the link and start chatting! Everything is pre-configured.

---

## 💬 How to Use

1. **Open the URL** above in your browser
2. **Type your question** in the chat box at the bottom
3. **Press Enter** or click **Send**
4. **Wait a few seconds** for the AI agent to query the database and respond

That's it! No configuration needed.

---

## 🧪 Example Questions to Try

### Basic Queries
- "Show me 10 records from test_population"
- "How many records are in the test_population table?"
- "What columns are available in test_population?"

### EMIR Data Queries
- "Show me incidents with code E_A_C_09"
- "What are the top 10 highest valuation amounts?"
- "Show me incidents where valuation amount is over 1 million"
- "List all unique incident codes"
- "Show me transactions from counterparty with specific ID"

### Analysis Queries
- "What is the average valuation amount?"
- "Count incidents by incident code"
- "Show me records from May 2024"
- "What currencies are being used in valuations?"

---

## 📊 About the Data

You're querying the **EMIR financial reporting dataset** with 7,867 records containing:

- **Incident codes and descriptions**
- **Unique Transaction Identifiers (UTI)**
- **Valuation amounts and currencies**
- **Counterparty information**
- **Trade dates and execution details**
- **Asset classifications**

The AI agent will automatically:
1. Understand your natural language question
2. Generate the appropriate SQL query
3. Execute it against Amazon Athena
4. Return the results in a readable format

---

## 🔧 Configuration (Already Set)

The application is pre-configured with:
- **Agent ID:** G1RWZFEZ4O
- **Agent Alias:** TSTALIASID
- **Region:** eu-central-1
- **API Endpoint:** https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat

You don't need to change anything!

---

## ⚠️ Troubleshooting

### If you see old demo data (customers table):
The browser may have cached old settings. Fix it by:

1. **Press F12** to open Developer Tools
2. Go to the **Console** tab
3. **Paste this code** and press Enter:
```javascript
localStorage.setItem('agentConfig', JSON.stringify({
    agentId: 'G1RWZFEZ4O',
    agentAliasId: 'TSTALIASID',
    awsRegion: 'eu-central-1'
}));
location.reload();
```

### If nothing happens when you click Send:
- Make sure you're connected to the internet
- Try refreshing the page (Ctrl+R or Cmd+R)
- Clear browser cache (Ctrl+Shift+R or Cmd+Shift+R)

### If you get an error message:
- Wait a few seconds and try again (the agent may be warming up)
- Try a simpler question first like "Count records in test_population"

---

## 📝 Notes

- First query may take 10-15 seconds (cold start)
- Subsequent queries are much faster (2-3 seconds)
- The agent will show you both the SQL query it generated and the results
- You can ask follow-up questions in the same conversation

---

## 🎯 Key Features

✅ Natural language to SQL translation  
✅ Direct database access via Amazon Athena  
✅ Real EMIR financial data (7,867 records)  
✅ No SQL knowledge required  
✅ Pre-configured and ready to use  

---

**Questions or issues?** The application is fully deployed and tested. Just start asking questions about your EMIR data!
