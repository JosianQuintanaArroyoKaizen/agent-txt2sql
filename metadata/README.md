# Table Metadata Directory

This directory contains JSON metadata files that describe tables for automated onboarding.

## Metadata File Format

Each JSON file should contain:

```json
{
  "table_description": "Brief description of what this table contains",
  "common_queries": [
    "List of common search terms",
    "Keywords users might use",
    "Query patterns"
  ],
  "columns": {
    "column_name": "Human-readable description of the column",
    "another_column": "Description with data type and format info"
  }
}
```

## Creating Metadata Files

### Option 1: Manual Creation
Copy `example-table-metadata.json` and fill in your table details.

### Option 2: Auto-generate from CSV
Use the metadata generator script:
```bash
python scripts/generate-table-metadata.py your_data.csv > metadata/your_table.json
```

## Best Practices

1. **Table Description:**
   - 1-2 sentences
   - Mention primary use case
   - Include row count if known

2. **Common Queries:**
   - 3-5 search terms
   - Include synonyms
   - Think about user language

3. **Column Descriptions:**
   - Focus on top 20-30 most important columns
   - Mention data types if not obvious
   - Note foreign key relationships
   - Specify format for dates/numbers
   - Indicate if stored as string but represents numeric data

## Example

**Good column description:**
```json
"reporting_date_1_1": "PRIMARY date field - When trade was reported to repository (YYYY-MM-DD format, stored as STRING)"
```

**Bad column description:**
```json
"reporting_date_1_1": "Date"
```

## File Naming Convention

Use the same name as your intended table name:
- `sales_2024.json` → table name: `sales_2024`
- `customer_data.json` → table name: `customer_data`
