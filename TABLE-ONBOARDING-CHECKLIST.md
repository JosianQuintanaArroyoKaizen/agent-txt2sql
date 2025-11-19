# Table Onboarding Checklist

Use this checklist each time you add a new CSV dataset.

---

## Pre-Onboarding

- [ ] CSV file is clean (no corrupt rows, consistent delimiters)
- [ ] Column headers are present in first row
- [ ] File size is reasonable (<5GB for initial testing)
- [ ] Table name decided (lowercase, underscores only)

---

## Automated Onboarding Steps

### 1. Generate Metadata
```bash
python scripts/generate-table-metadata.py path/to/file.csv --table-name TABLE_NAME > metadata/TABLE_NAME.json
```
- [ ] Metadata file generated successfully
- [ ] File saved to `metadata/TABLE_NAME.json`

### 2. Review & Improve Metadata
```bash
nano metadata/TABLE_NAME.json
```
- [ ] Table description is accurate and detailed
- [ ] Common query terms added (5-10 terms)
- [ ] Top 20-30 columns have good descriptions
- [ ] Foreign keys documented
- [ ] Date formats specified
- [ ] Numeric types clarified (especially if stored as strings)

### 3. Run Onboarding Script
```bash
./scripts/onboard-new-table.sh path/to/file.csv TABLE_NAME metadata/TABLE_NAME.json
```
- [ ] CSV uploaded to S3 successfully
- [ ] Glue crawler ran without errors
- [ ] Column descriptions added to Glue catalog
- [ ] Agent snippet generated
- [ ] Test queries created

### 4. Verify in Athena
```sql
DESCRIBE TABLE_NAME;
SELECT * FROM TABLE_NAME LIMIT 10;
```
- [ ] Table shows up in Athena
- [ ] Column descriptions visible in DESCRIBE output
- [ ] Sample query returns data correctly
- [ ] No schema errors

### 5. Update Agent Instructions
```bash
cat schema/agent-snippets/TABLE_NAME_snippet.txt >> docs/enhanced-agent-instruction.txt
```
- [ ] Snippet added to agent instructions
- [ ] Placed in appropriate section (by domain/category)
- [ ] Instructions file syntax is valid

### 6. Test with Agent
- [ ] Test query: "How many records are in [table]?"
- [ ] Test query: "Show me sample data from [table]"
- [ ] Test query: "What columns are in [table]?"
- [ ] Agent selects correct table
- [ ] SQL generated is accurate
- [ ] Results are as expected

### 7. Documentation
- [ ] Add table to `table-inventory.md`
- [ ] Document any special considerations
- [ ] Note any known limitations
- [ ] Update user-facing documentation if needed

---

## Post-Onboarding

### Within 1 Week
- [ ] Monitor query success rate for this table
- [ ] Collect user feedback on descriptions
- [ ] Refine column descriptions based on failures
- [ ] Add more common query examples if needed

### Ongoing
- [ ] Update metadata when CSV schema changes
- [ ] Re-run crawler after major data updates
- [ ] Keep agent instructions synchronized

---

## Troubleshooting

If something fails:

**CSV Upload Failed**
- [ ] Check S3 bucket exists
- [ ] Verify AWS credentials
- [ ] Check file path is correct

**Crawler Failed**
- [ ] Verify Glue IAM role has permissions
- [ ] Check S3 path is accessible
- [ ] Review CloudWatch logs

**Description Update Failed**
- [ ] Table exists in Glue catalog
- [ ] Metadata JSON is valid
- [ ] Column names match (case-sensitive)

**Agent Not Using Table**
- [ ] Agent instructions updated and saved
- [ ] Bedrock agent redeployed with new version
- [ ] Table description has clear keywords
- [ ] Tested with explicit table name mention

---

## Quick Reference

**Environment Variables:**
```bash
export S3_DATA_BUCKET="txt2sql-dev-data-bucket"
export DATABASE_NAME="txt2sql_dev_athena_db"
export AWS_REGION="us-west-2"
```

**Common Commands:**
```bash
# Test Athena connection
aws athena list-databases --region us-west-2

# List tables in database
aws glue get-tables --database-name txt2sql_dev_athena_db

# View crawler status
aws glue get-crawler --name TABLE_NAME_crawler
```

---

## Success Criteria

Your table onboarding is complete when:

✅ Table queryable in Athena with descriptions  
✅ Agent successfully answers 8/10 test queries  
✅ Column descriptions help agent select correct columns  
✅ Users can discover data with natural language  
✅ Documentation updated  

---

## Template Test Queries

Copy and customize for each table:

```
1. "How many [records/rows] are in [table]?"
2. "Show me sample data from [table]"
3. "What columns are in [table]?"
4. "Show me [specific category/type] from [table]"
5. "What is the [date range/time period] in [table]?"
6. "Find [records] where [column] is [value]"
7. "Count [records] by [category column]"
8. "What's the average [numeric column] in [table]?"
9. "Show me recent [records] from [table]"
10. "Join [table1] and [table2] on [relationship]"
```
