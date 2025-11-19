# How the Agent Selects Tables - Complete Example

## The Agent's Decision Process

When a user asks a question, the Bedrock Agent (Claude 3 Haiku) goes through this reasoning:

---

## Example 1: Simple Query

**User:** "How many VIP customers do we have?"

**Agent's Internal Reasoning:**
```
Step 1: Parse the question
- Keywords: "VIP", "customers"
- Intent: COUNT query
- Needs: Customer data with VIP status

Step 2: Review available tables
From my instructions, I know:
- txt2sql_dev_customers: Has customer data including Vip column ✓
- txt2sql_dev_procedures: Has procedure data ✗
- test_population: Has trade data ✗

Step 3: Select table
Match: txt2sql_dev_customers (has both "customer" and "Vip" column)

Step 4: Generate SQL
SELECT COUNT(*) as vip_count 
FROM txt2sql_dev_customers 
WHERE Vip = 'yes'

Step 5: Execute via Lambda
```

**Result:** Agent correctly queries `txt2sql_dev_customers`

---

## Example 2: Ambiguous Query

**User:** "Show me records from last month"

**Agent's Internal Reasoning:**
```
Step 1: Parse the question
- Keywords: "records", "last month"
- Intent: Date range query
- Ambiguous: Which table has date fields?

Step 2: Review tables with dates
- test_population: Has reporting_date_1_1 (trade reports) ✓
- txt2sql_dev_customers: No date fields ✗
- txt2sql_dev_procedures: No date fields ✗

Step 3: Make inference
"Records" is generic, but only test_population has dates
Default to the main data table: test_population

Step 4: Generate SQL
SELECT uti_2_1, reporting_date_1_1, asset_class_2_11, valuation_amount_2_21
FROM test_population 
WHERE reporting_date_1_1 >= date_format(date_add('month', -1, current_date), '%Y-%m-%d')
LIMIT 20
```

**Result:** Agent queries `test_population` (the only table with dates)

---

## Example 3: Multi-Table Query

**User:** "Show me all procedures for VIP customers"

**Agent's Internal Reasoning:**
```
Step 1: Parse the question
- Keywords: "procedures", "VIP customers"
- Intent: JOIN query (needs data from 2 tables)
- Needs: procedures + customer VIP status

Step 2: Identify required tables
- txt2sql_dev_procedures: Has procedure data ✓
- txt2sql_dev_customers: Has VIP status ✓
- Relationship: procedures.Customer_Id = customers.Cust_Id

Step 3: Plan JOIN
Need both tables with foreign key relationship

Step 4: Generate SQL
SELECT 
    p.Procedure_ID,
    p.Procedure,
    p.Category,
    p.Price,
    c.Customer,
    c.Vip
FROM txt2sql_dev_procedures p
JOIN txt2sql_dev_customers c ON p.Customer_Id = c.Cust_Id
WHERE c.Vip = 'yes'
```

**Result:** Agent queries BOTH tables with JOIN

---

## Example 4: Wrong Table Prevention

**User:** "What's the average trade valuation?"

**Agent's Internal Reasoning:**
```
Step 1: Parse the question
- Keywords: "trade", "valuation", "average"
- Intent: Aggregation on financial data

Step 2: Review tables
- txt2sql_dev_customers: Has Balance (not trades) ✗
- txt2sql_dev_procedures: Has Price (not trades) ✗
- test_population: Has trade valuation_amount_2_21 ✓

Step 3: Select correct table
"Trade valuation" matches test_population description

Step 4: Generate SQL
SELECT 
    AVG(CAST(valuation_amount_2_21 AS DOUBLE)) as avg_valuation,
    valuation_currency_2_22 as currency
FROM test_population 
WHERE valuation_amount_2_21 IS NOT NULL AND valuation_amount_2_21 != ''
GROUP BY valuation_currency_2_22
```

**Result:** Agent avoids querying customer balance, correctly uses trade data

---

## How to Improve Table Selection

### 1. **Clear Table Descriptions**

❌ Bad:
```
Table: data_table
Contains various data
```

✅ Good:
```
Table: txt2sql_dev_customers
Customer account information including names, balances, past due amounts, and VIP status.
Use this table for questions about: customers, accounts, VIP members, balances, past due amounts.
```

### 2. **Include Keywords/Tags**

Add searchable terms to help the agent:

```
### Table: txt2sql_dev_procedures
Medical procedures with pricing and insurance coverage.

**Common query terms:** 
- procedures, medical procedures, treatments
- categories: consultation, imaging, laboratory, dental, surgery
- pricing, cost, insurance
- customer procedures, patient history
```

### 3. **Specify Relationships**

Tell the agent how tables connect:

```
### Table: txt2sql_dev_procedures
...
**Relationships:**
- Customer_Id links to txt2sql_dev_customers.Cust_Id
- Use JOIN for queries about "customer procedures" or "procedures by VIP status"
```

### 4. **Add Use Case Examples**

Give the agent examples of when to use each table:

```
### Table: test_population
EMIR derivatives trade data

**Use this table for:**
- "Show me trades from last week"
- "How many cleared vs uncleared trades?"
- "What asset classes do we have?"
- "Find trades with valuation over X"
- "Show me all Interest Rate derivatives"
```

---

## What Happens When Agent Gets It Wrong?

If the agent selects the wrong table:

1. **SQL fails** (column doesn't exist)
2. **Agent sees error** from Athena
3. **Agent retries** with different table
4. **Eventually finds** correct table or reports it can't answer

**Example:**
```
User: "Show me all interest rate swaps"

Agent's first attempt:
SELECT * FROM txt2sql_dev_customers WHERE ... 
❌ Error: column "asset_class" doesn't exist

Agent's second attempt:
SELECT * FROM test_population WHERE asset_class_2_11 = 'Interest Rate'
✅ Success!
```

---

## Testing Table Selection

To verify your agent selects tables correctly, test with these queries:

```python
test_cases = [
    # Should query customers table
    ("How many customers do we have?", "txt2sql_dev_customers"),
    ("Show me VIP customers", "txt2sql_dev_customers"),
    ("Who has past due amounts?", "txt2sql_dev_customers"),
    
    # Should query procedures table
    ("List all dental procedures", "txt2sql_dev_procedures"),
    ("What's the average procedure price?", "txt2sql_dev_procedures"),
    ("Show me procedures covered by insurance", "txt2sql_dev_procedures"),
    
    # Should query trade data
    ("How many trades are there?", "test_population"),
    ("Show me cleared trades", "test_population"),
    ("What asset classes exist?", "test_population"),
    
    # Should use JOIN
    ("Show procedures for customer 3", "JOIN"),
    ("Which VIP customers have had surgery?", "JOIN"),
]
```

---

## Summary: How Agent Knows Which Table

1. **Reads table descriptions** in agent instructions
2. **Matches keywords** from user question to table descriptions
3. **Uses semantic understanding** (LLM intelligence)
4. **Remembers context** from conversation history
5. **Makes educated guesses** and retries if wrong
6. **Learns from errors** within the conversation

**The key:** Write **clear, descriptive table documentation** in your agent instructions!

---

## Your Current Setup

Looking at your `enhanced-agent-instruction.txt`:

✅ **You already have this!**
- Table descriptions
- Column lists
- Table purposes defined

✨ **You could improve by adding:**
- Explicit "Common query terms" sections
- "Use this table when..." guidance
- More examples of table-specific queries

Would you like me to enhance your current agent instructions with better table selection guidance?
