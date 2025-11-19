# Setting Up Bedrock Knowledge Base for Dynamic Schema Retrieval

## Problem
With CSV files containing 200+ columns and multiple datasets, including full schemas in agent instructions hits token limits and becomes unmanageable.

## Solution: Bedrock Knowledge Base with RAG

Use Amazon Bedrock Knowledge Base to dynamically retrieve only relevant schema information based on user queries.

---

## Architecture

```
User Query: "Show me customer balances"
        ↓
Bedrock Agent analyzes query
        ↓
Knowledge Base retrieves: customers table schema (only)
        ↓
Agent generates SQL with correct columns
        ↓
Lambda executes query
```

---

## Setup Steps

### Step 1: Prepare Schema Documents

Create individual schema files for each table in S3:

**File: `schemas/customers_schema.txt`**
```
Table: txt2sql_dev_customers
Description: Customer account information with balances and VIP status

Columns:
- Cust_Id (INTEGER): Unique customer identifier
- Customer (VARCHAR): Customer full name
- Balance (INTEGER): Current account balance in dollars
- Past_Due (INTEGER): Amount past due in dollars
- Vip (VARCHAR): VIP status (yes/no)

Common Queries:
- VIP customers with high balances
- Customers with past due amounts
- Total customer count and balance summaries
```

**File: `schemas/procedures_schema.txt`**
```
Table: txt2sql_dev_procedures
Description: Medical procedures with pricing and insurance coverage

Columns:
- Procedure_ID (VARCHAR): Unique procedure identifier
- Procedure (VARCHAR): Procedure name
- Category (VARCHAR): Category (consultation, imaging, laboratory, dental, surgery, rehabilitation, preventative)
- Price (INTEGER): Procedure price in dollars
- Duration (INTEGER): Duration in minutes
- Insurance (VARCHAR): Insurance coverage (yes/no)
- Customer_Id (INTEGER): Associated customer (FK to txt2sql_dev_customers.Cust_Id)

Common Queries:
- Procedures by category
- Average price by category
- Insurance-covered procedures
- Customer procedure history (JOIN with customers)
```

**File: `schemas/test_population_schema.txt`**
```
Table: test_population
Description: EMIR derivatives trade repository data (7,867 records)

KEY COLUMNS BY CATEGORY:

Identifiers:
- uti_2_1 (VARCHAR): Unique Transaction Identifier
- kr_record_key (VARCHAR): Korea record key
- isin_2_7 (VARCHAR): ISIN code

Counterparties:
- counterparty_1_reporting_counterparty_1_4 (VARCHAR): Reporting counterparty
- counterparty_2_1_9 (VARCHAR): Second counterparty
- nature_of_the_counterparty_1_1_5 (VARCHAR): Type of counterparty 1

Critical Date Fields (all STRING type):
- reporting_date_1_1 (STRING): PRIMARY - When trade was reported (format: YYYY-MM-DD)
- execution_date_2_42 (STRING): When trade was executed
- valuation_date_2_23 (STRING): Valuation date
- expiration_date_2_44 (STRING): Contract expiration date

Financial:
- valuation_amount_2_21 (STRING): Valuation amount (needs CAST to DOUBLE)
- valuation_currency_2_22 (VARCHAR): Currency code
- notional_amount_of_leg_1_2_55 (STRING): Notional amount leg 1
- price_2_48 (STRING): Trade price

Product Classification:
- asset_class_2_11 (VARCHAR): Asset class (Interest Rate, FX, Commodity, etc.)
- contract_type_2_10 (VARCHAR): Contract type
- product_classification_2_9 (VARCHAR): Product code

Trade Status:
- cleared_2_31 (VARCHAR): Cleared status (Y/N)
- confirmed_2_29 (VARCHAR): Confirmation status
- direction_1_17 (VARCHAR): Trade direction (Buy/Sell)

IMPORTANT NOTES:
- Table has 200+ total columns (only key columns listed above)
- ALL columns stored as STRING type - use CAST for numeric operations
- NEVER use SELECT * - always specify needed columns
- Filter NULLs: WHERE column IS NOT NULL AND column != ''
- For date queries, default to reporting_date_1_1

Common Query Patterns:
- Date range analysis: MIN/MAX on reporting_date_1_1
- Aggregations by asset_class_2_11 or contract_type_2_10
- Cleared vs uncleared: GROUP BY cleared_2_31
- Currency distributions: GROUP BY valuation_currency_2_22
```

### Step 2: Create S3 Bucket for Knowledge Base

```bash
# Create KB bucket
aws s3 mb s3://txt2sql-kb-schemas-${AWS_ACCOUNT_ID} --region us-west-2

# Upload schema documents
aws s3 cp schemas/ s3://txt2sql-kb-schemas-${AWS_ACCOUNT_ID}/schemas/ --recursive
```

### Step 3: Create Knowledge Base in Bedrock Console

1. **Navigate to Amazon Bedrock Console** → Knowledge bases → Create knowledge base

2. **Knowledge base details:**
   - Name: `txt2sql-schema-kb`
   - Description: `Dynamic schema retrieval for text-to-SQL agent`
   - IAM role: Create new service role

3. **Data source:**
   - S3 URI: `s3://txt2sql-kb-schemas-${AWS_ACCOUNT_ID}/schemas/`
   - Chunking: Fixed size (default 300 tokens)
   - Embeddings model: **Titan Embeddings G1 - Text**

4. **Vector database:**
   - Use managed vector store (OpenSearch Serverless)

5. **Review and create** → Wait for indexing to complete

### Step 4: Update Agent Instructions

Replace your lengthy schema section with:

```
## DATABASE SCHEMA

You have access to a Knowledge Base that contains detailed schema information for all tables.

**Available Tables:**
- `test_population` - EMIR derivatives trade data (7,867 rows, 200+ columns)
- `txt2sql_dev_customers` - Customer account information
- `txt2sql_dev_procedures` - Medical procedures data

**How to use:**
1. When user asks a question, the Knowledge Base will automatically retrieve relevant schema info
2. Use the retrieved column names and types to generate SQL
3. For test_population, NEVER use SELECT * - always specify columns
4. All test_population columns are STRING type - CAST for numeric operations
5. Default date field: reporting_date_1_1

The Knowledge Base will provide you with:
- Exact column names and types
- Column descriptions and usage
- Common query patterns
- Data type handling notes
```

### Step 5: Associate Knowledge Base with Agent

1. **Bedrock Console** → Agents → Select your agent
2. Go to **Knowledge bases** section
3. Click **Associate knowledge base**
4. Select `txt2sql-schema-kb`
5. **Instruction for knowledge base:**
   ```
   Use this knowledge base to retrieve database schema information including table names, 
   column names, data types, and query guidance. Query it whenever you need to understand 
   available tables or columns for SQL generation.
   ```
6. **Save and prepare** new agent version

### Step 6: Test the Setup

Test queries that require different schemas:

```
"How many customers do we have?"
→ KB retrieves customers schema → Generates correct SQL

"Show me trade data by asset class"
→ KB retrieves test_population schema → Uses asset_class_2_11

"What's the average procedure price by category?"
→ KB retrieves procedures schema → Correct columns and aggregation
```

---

## Benefits

✅ **Scalable**: Add unlimited tables/columns without token concerns
✅ **Dynamic**: Only retrieves relevant schemas for each query
✅ **Maintainable**: Update schemas in S3 without redeploying agent
✅ **Efficient**: Reduced token usage = faster responses + lower cost
✅ **Smart**: RAG finds related schemas even with fuzzy matching

---

## Cost Considerations

| Component | Cost |
|-----------|------|
| Knowledge Base (OpenSearch Serverless) | ~$45/month (0.5 OCU) |
| Titan Embeddings | ~$0.10 per 1M tokens (one-time indexing) |
| Knowledge Base queries | $0.10 per 1K queries |

**Trade-off:** ~$45/month for unlimited schema scalability vs. hitting token limits

---

## Alternative: Lighter Approach

If you want to avoid the $45/month KB cost, see **Option 2** below.
