# Column Metadata Solutions for Text-to-SQL

## The Problem

Your CSV columns have cryptic names:
```
reporting_date_1_1
counterparty_1_reporting_counterparty_1_4
valuation_amount_2_21
```

When the agent runs `DESCRIBE table_name`, it sees column names but doesn't understand what they mean.

**User asks:** "Show me recent trades"
**Agent thinks:** "What column is 'recent'? date? timestamp? I see reporting_date_1_1... is that it?"

---

## Solution Comparison

### Option A: AWS Glue Column Descriptions ⭐ **RECOMMENDED**

**How it works:**
1. Add descriptions to Glue Data Catalog columns (script provided)
2. When agent runs `DESCRIBE table_name`, Athena returns descriptions
3. Agent understands what each column means

**After running the script, `DESCRIBE` returns:**
```
Column Name                               | Type   | Comment
------------------------------------------|--------|------------------------------------------
reporting_date_1_1                        | string | PRIMARY DATE FIELD - When trade was reported
execution_date_2_42                       | string | When the trade was executed/agreed upon
valuation_amount_2_21                     | string | Valuation amount (CAST to DOUBLE for math)
asset_class_2_11                          | string | Asset class (Interest Rate, FX, etc.)
```

**Setup:**
```bash
# Install boto3 if needed
pip install boto3

# Run the script (updates all tables)
python scripts/add-column-descriptions.py
```

**Pros:**
- ✅ Native AWS solution (no external dependencies)
- ✅ Descriptions visible in Athena console
- ✅ Works with existing DESCRIBE queries
- ✅ One-time setup, persistent metadata
- ✅ Updates Glue Data Catalog directly

**Cons:**
- ⚠️ Requires running script after adding new tables
- ⚠️ Glue crawlers might overwrite descriptions (document them!)

---

### Option B: Column Mapping Dictionary

**How it works:**
Create a metadata file that maps columns to descriptions:

**File: `schema/column-maps/test_population_map.json`**
```json
{
  "table": "test_population",
  "description": "EMIR derivatives trade repository data",
  "column_mappings": {
    "reporting_date_1_1": {
      "friendly_name": "Reporting Date",
      "description": "PRIMARY DATE FIELD - When the trade was reported (YYYY-MM-DD)",
      "type": "date",
      "common_queries": ["recent trades", "last quarter", "date range"]
    },
    "valuation_amount_2_21": {
      "friendly_name": "Valuation Amount",
      "description": "Trade valuation amount in currency specified by valuation_currency_2_22",
      "type": "numeric_string",
      "note": "Stored as STRING - use CAST(valuation_amount_2_21 AS DOUBLE) for calculations",
      "common_queries": ["trade value", "valuation", "amount"]
    },
    "asset_class_2_11": {
      "friendly_name": "Asset Class",
      "description": "Type of asset (Interest Rate, FX, Commodity, Equity, Credit)",
      "type": "category",
      "common_queries": ["asset type", "product type"]
    }
  }
}
```

Then either:
- **Approach 1:** Include this in agent instructions (works for ~20-30 key columns)
- **Approach 2:** Add Lambda function to look up descriptions (see earlier Option 2)
- **Approach 3:** Store in Knowledge Base (see earlier Option 1)

**Pros:**
- ✅ Version controlled with your code
- ✅ Easy to update and maintain
- ✅ Can include rich metadata (common queries, synonyms)
- ✅ No AWS API calls needed

**Cons:**
- ⚠️ Separate from actual database catalog
- ⚠️ Need to sync with actual schema changes
- ⚠️ May require additional implementation

---

### Option C: CSV Scanning Agent (Your Suggestion)

**How it works:**
Create a separate agent that analyzes CSV files and generates column descriptions automatically.

```python
# Pseudo-code for CSV Scanner
def analyze_csv_column(column_name, sample_values):
    """
    Use LLM to understand what a column contains based on:
    - Column name
    - Sample values
    - Data patterns
    """
    prompt = f"""
    Analyze this database column:
    
    Column name: {column_name}
    Sample values: {sample_values[:10]}
    
    Provide:
    1. Human-readable name
    2. Description of what this column contains
    3. Data type and format
    4. Common search terms users might use
    """
    
    return bedrock_client.invoke_model(prompt)
```

**Pros:**
- ✅ Automated - no manual documentation
- ✅ Can analyze data patterns
- ✅ Learns from actual data
- ✅ Could detect data quality issues

**Cons:**
- ⚠️ Complex to build and maintain
- ⚠️ LLM costs for analysis
- ⚠️ May misinterpret cryptic column names
- ⚠️ Needs validation/human oversight
- ⚠️ Overkill for most use cases

---

## My Recommendation

### Start with **Option A (Glue Column Descriptions)** because:

1. **It's the simplest and most effective**
2. **Native AWS integration** - no extra infrastructure
3. **Visible everywhere** - Athena console, agent queries, etc.
4. **One-time setup** - run script once per table
5. **Works immediately** with dynamic discovery approach

### Implementation Steps

**Step 1:** Review and customize the column descriptions in the script:
```python
# Edit scripts/add-column-descriptions.py
COLUMN_DESCRIPTIONS = {
    'your_table_name': {
        'cryptic_column_123': 'Human readable description of what this is',
        # Add all important columns
    }
}
```

**Step 2:** Run the script:
```bash
cd /home/jquintana-arroyo/git/agent-txt2sql
python scripts/add-column-descriptions.py
```

**Step 3:** Test in Athena console:
```sql
DESCRIBE test_population;
```

You should now see descriptions in the "Comment" column!

**Step 4:** Update agent instructions to mention descriptions:
```
When you run DESCRIBE table_name, pay attention to the Comment column 
which contains human-readable descriptions of what each column means.
Use these descriptions to select the right columns for the user's query.
```

---

## Handling Future CSV Files

When you add new CSV files:

1. **Upload CSV to S3**
2. **Run Glue Crawler** to catalog it
3. **Create column descriptions** (add to script or manually in console)
4. **Run description script** (or update via console)
5. **Agent automatically discovers** the new table with descriptions

---

## Advanced: Semantic Column Matching

For truly cryptic columns, you could add semantic hints:

```python
SEMANTIC_MAPPINGS = {
    'test_population': {
        'date_keywords': {
            'reporting_date_1_1': ['recent', 'last', 'latest', 'when reported'],
            'execution_date_2_42': ['executed', 'trade date', 'when happened'],
            'valuation_date_2_23': ['valued', 'valuation date']
        },
        'amount_keywords': {
            'valuation_amount_2_21': ['value', 'amount', 'valuation', 'worth'],
            'price_2_48': ['price', 'cost']
        }
    }
}
```

Include this in agent instructions so it knows:
- "Show me recent trades" → use `reporting_date_1_1`
- "What's the valuation?" → use `valuation_amount_2_21`

---

## Which Should You Use?

| Your Situation | Recommended Approach |
|----------------|---------------------|
| Have 5-10 tables with cryptic names | **Option A (Glue Descriptions)** |
| Need rich metadata & version control | **Option A + B (Glue + JSON docs)** |
| Have 50+ tables, changing frequently | **Option C (Scanning Agent)** |
| Want cheapest solution | **Option B (JSON mappings only)** |
| Want most powerful solution | **Option A + Knowledge Base (RAG)** |

---

## Example: Complete Workflow

**Before:**
```
User: "Show me trades from last month"
Agent runs: DESCRIBE test_population
Agent sees: reporting_date_1_1 | string | 
Agent thinks: "Is reporting_date_1_1 the date field? Maybe? I'll try it..."
```

**After (with descriptions):**
```
User: "Show me trades from last month"
Agent runs: DESCRIBE test_population
Agent sees: reporting_date_1_1 | string | PRIMARY DATE FIELD - When trade was reported
Agent thinks: "Perfect! reporting_date_1_1 is the primary date field"
Agent generates: 
  SELECT * FROM test_population 
  WHERE reporting_date_1_1 >= date_format(date_add('month', -1, current_date), '%Y-%m-%d')
  LIMIT 100;
```

---

## Next Steps

1. **Review the script** I created: `scripts/add-column-descriptions.py`
2. **Add descriptions** for your important columns
3. **Run the script** to update Glue Data Catalog
4. **Test** by running `DESCRIBE` in Athena
5. **Update agent instructions** to use descriptions

Would you like me to:
- Add more column descriptions to the script?
- Show you how to add descriptions manually in AWS Console?
- Create the semantic mapping file for your tables?
