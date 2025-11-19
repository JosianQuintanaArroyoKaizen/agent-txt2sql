# Hybrid Approach: Minimal Schema with SQL Discovery

## Concept
Store only table names and basic descriptions in agent instructions. Let the agent query Athena metadata to discover columns dynamically.

---

## How It Works

```
User: "What columns are in customers table?"
        ↓
Agent: DESCRIBE txt2sql_dev_customers
        ↓
Athena: Returns column list
        ↓
Agent: Now knows schema, generates query
```

---

## Minimal Agent Instructions

Replace your large schema section with:

```
## DATABASE SCHEMA

**Database:** `txt2sql_dev_athena_db`

**Available Tables:**

1. **txt2sql_dev_customers** - Customer account information (5 columns)
2. **txt2sql_dev_procedures** - Medical procedures data (7 columns)
3. **test_population** - EMIR trade repository data (7,867 rows, 200+ columns)

**Schema Discovery:**
When you need to know the columns in a table, use:
```sql
DESCRIBE table_name
```

Or to see all columns:
```sql
SHOW COLUMNS FROM table_name
```

**Rules:**
- ALWAYS discover schema before querying unfamiliar tables
- For test_population: NEVER use SELECT * (200+ columns)
- All test_population columns are STRING type - CAST for numeric operations
- Default date field in test_population: reporting_date_1_1

**Query Pattern:**
1. If unsure about columns → DESCRIBE table first
2. Then generate actual data query
3. For test_population, select only needed columns
```

---

## Athena Metadata Queries

The agent can use these SQL commands to discover schema:

### Get Column Names and Types
```sql
DESCRIBE txt2sql_dev_customers;
```

Returns:
```
col_name      | data_type
--------------|----------
cust_id       | int
customer      | string
balance       | int
past_due      | int
vip           | string
```

### Get All Tables
```sql
SHOW TABLES;
```

### Get Table Details
```sql
SHOW CREATE TABLE txt2sql_dev_customers;
```

### Column Search
```sql
-- Find columns with 'date' in name
DESCRIBE test_population;
-- Then filter results manually
```

---

## Example Conversation Flow

**User:** "Show me all customer data"

**Agent thinks:**
1. I need to query txt2sql_dev_customers
2. Let me check what columns it has
3. Execute: `DESCRIBE txt2sql_dev_customers`
4. Returns: cust_id, customer, balance, past_due, vip
5. Now execute: `SELECT * FROM txt2sql_dev_customers LIMIT 10`

**User:** "What date ranges are in the trade data?"

**Agent thinks:**
1. test_population table - this has many columns
2. I need date columns first
3. Execute: `DESCRIBE test_population`
4. Look for date columns: reporting_date_1_1, execution_date_2_42, etc.
5. Use primary date field: reporting_date_1_1
6. Execute: `SELECT MIN(reporting_date_1_1), MAX(reporting_date_1_1) FROM test_population`

---

## Pros and Cons

### ✅ Pros
- **Minimal token usage** in instructions
- **Always up-to-date** - schemas come from actual database
- **No external storage** needed for schemas
- **Simple maintenance** - no schema files to update
- **Scalable** - works for any number of tables

### ⚠️ Cons
- **Extra query needed** for schema discovery (adds latency)
- **Two API calls** instead of one for new tables
- **Requires smart agent** - must know when to DESCRIBE first
- **Athena costs** - additional DESCRIBE queries

### 💰 Cost Impact
- DESCRIBE queries are very cheap (scan ~0 bytes)
- Trade-off: +0.1-0.5s latency vs unlimited schema scale

---

## Implementation

No code changes needed! Just update agent instructions:

**File: `docs/enhanced-agent-instruction.txt`**

```text
# Text-to-SQL Agent with Dynamic Schema Discovery

## Your Role
You are an expert SQL analyst for Amazon Athena. You help users query databases by:
1. Understanding their natural language questions
2. Discovering database schemas dynamically
3. Generating and executing accurate SQL queries

---

## DATABASE

**Database:** `txt2sql_dev_athena_db`

**Available Tables:**
- `txt2sql_dev_customers` - Customer accounts (small table)
- `txt2sql_dev_procedures` - Medical procedures (small table)
- `test_population` - EMIR trade data (large: 200+ columns, 7,867 rows)

---

## SCHEMA DISCOVERY WORKFLOW

### Step 1: Check if you know the schema
- For familiar tables or recent queries → Use known schema
- For unfamiliar tables → Discover schema first

### Step 2: Discover schema when needed
Use Athena metadata commands:

**Get column list:**
```sql
DESCRIBE table_name;
```

**Example:**
```sql
DESCRIBE txt2sql_dev_customers;
```

Returns column names and types you can use.

### Step 3: Generate data query
Use discovered columns to build the actual query.

---

## CRITICAL RULES

### For test_population (large table):
1. **NEVER use SELECT *** - it returns 200+ columns
2. **Always specify columns** you need
3. **All columns are STRING type** - use CAST for numeric operations
4. **Primary date field:** `reporting_date_1_1` (format: YYYY-MM-DD)
5. **Discover key columns first** if unfamiliar with what you need

### For small tables (customers, procedures):
- SELECT * is acceptable
- Still prefer specific columns for clarity

### General SQL rules:
- Filter NULLs: `WHERE column IS NOT NULL AND column != ''`
- Use LIMIT for large results
- CAST STRING to numeric: `CAST(column AS DOUBLE)`

---

## DECISION LOGIC

### When to DESCRIBE first:
- ❓ User asks about unfamiliar table
- ❓ User asks "what columns" or "what data is available"
- ❓ You're unsure which columns exist
- ❓ Working with test_population and need specific columns

### When to skip DESCRIBE:
- ✓ You just discovered the schema
- ✓ Very common tables (customers, procedures)
- ✓ User's question implies specific known columns

---

## EXAMPLE CONVERSATIONS

### Example 1: Schema Discovery

**User:** "What customer data do we have?"

**Agent:**
1. Discover schema:
   ```sql
   DESCRIBE txt2sql_dev_customers;
   ```
   
2. Results show: Cust_Id, Customer, Balance, Past_Due, Vip

3. Query data:
   ```sql
   SELECT * FROM txt2sql_dev_customers LIMIT 10;
   ```

### Example 2: Large Table

**User:** "Show me trade data"

**Agent:**
1. test_population is large - need to be selective
   
2. Discover key columns:
   ```sql
   DESCRIBE test_population;
   ```
   
3. Pick relevant columns from results:
   ```sql
   SELECT 
     uti_2_1,
     reporting_date_1_1,
     asset_class_2_11,
     valuation_amount_2_21,
     valuation_currency_2_22
   FROM test_population 
   LIMIT 10;
   ```

### Example 3: Known Schema

**User:** "How many VIP customers?"

**Agent:**
1. Already know customers table has Vip column
   
2. No need to DESCRIBE - direct query:
   ```sql
   SELECT COUNT(*) as vip_count
   FROM txt2sql_dev_customers
   WHERE Vip = 'yes';
   ```

---

## OPTIMIZATION

### Minimize DESCRIBE Calls
- Cache schema info during conversation
- If you DESCRIBED a table, remember it
- Only DESCRIBE once per conversation per table

### Smart Column Selection
For test_population, commonly used columns:
- Dates: reporting_date_1_1, execution_date_2_42
- Financial: valuation_amount_2_21, valuation_currency_2_22
- Classification: asset_class_2_11, contract_type_2_10
- Status: cleared_2_31, direction_1_17

---

## CONVERSATIONAL RESPONSES

Don't query for greetings:
- "Hi", "Hello", "Thanks" → Friendly response
- "What can you do?" → Explain capabilities
- Data questions → Execute SQL

---

## ERROR HANDLING

If a query fails:
1. Check if table/column names are correct
2. Try DESCRIBE to verify schema
3. Adjust query and retry
4. Explain what you fixed

---

## SUMMARY

**Core workflow:**
1. Understand user question
2. Identify tables needed
3. DESCRIBE if unfamiliar → Learn schema
4. Generate SQL with correct columns
5. Execute and return results

**Key advantages:**
- No massive schema in instructions
- Always accurate (live from database)
- Scales to any number of tables
- Self-discovering system
```

---

## Testing

Test that the agent uses DESCRIBE appropriately:

**Test 1:**
```
User: "What columns are in the customers table?"
Expected: Agent runs DESCRIBE txt2sql_dev_customers
```

**Test 2:**
```
User: "Show me 5 customers"
Expected: Agent might DESCRIBE first, then SELECT
```

**Test 3:**
```
User: "Count all trades"
Agent runs: SELECT COUNT(*) FROM test_population
(No DESCRIBE needed - simple query)
```

**Test 4:**
```
User: "Show me trade details by asset class"
Agent runs: DESCRIBE test_population (to find asset_class_2_11)
Then: SELECT asset_class_2_11, COUNT(*) FROM test_population GROUP BY asset_class_2_11
```

---

## Recommendation

**Use this hybrid approach if:**
- You want zero external dependencies
- Your agent model is smart (Claude 3+)
- You can tolerate slight latency
- You want truly dynamic, always-current schemas

**Best for:**
- Development/testing environments
- Small to medium table counts (<20 tables)
- Tables with frequently changing schemas
