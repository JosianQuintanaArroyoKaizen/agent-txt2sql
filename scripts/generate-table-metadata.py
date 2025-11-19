#!/usr/bin/env python3
"""
Auto-generate table metadata JSON from CSV file.
Uses LLM to suggest descriptions for columns based on names and sample data.

Usage:
    python generate-table-metadata.py input.csv > metadata/output.json
    python generate-table-metadata.py input.csv --table-name sales_2024 > metadata/sales_2024.json
"""

import csv
import json
import sys
import argparse
from collections import Counter

def analyze_csv(csv_path, sample_size=100):
    """Analyze CSV file to extract column info and sample data"""
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames
        
        # Collect sample rows
        rows = []
        for i, row in enumerate(reader):
            if i >= sample_size:
                break
            rows.append(row)
    
    total_rows = len(rows)
    
    # Analyze each column
    column_info = {}
    for col in headers:
        values = [row[col] for row in rows if row.get(col)]
        
        # Basic analysis
        non_null_count = len([v for v in values if v and v.strip()])
        unique_count = len(set(values))
        sample_values = list(set(values))[:5]
        
        # Detect data type
        data_type = detect_type(values)
        
        column_info[col] = {
            'sample_values': sample_values,
            'non_null_pct': round(non_null_count / total_rows * 100, 1) if total_rows > 0 else 0,
            'unique_count': unique_count,
            'detected_type': data_type
        }
    
    return {
        'headers': headers,
        'total_rows': total_rows,
        'column_info': column_info
    }

def detect_type(values):
    """Detect likely data type from sample values"""
    if not values:
        return "string"
    
    # Check if numeric
    try:
        [float(v) for v in values[:20] if v]
        return "numeric"
    except (ValueError, TypeError):
        pass
    
    # Check if date
    import re
    date_patterns = [
        r'\d{4}-\d{2}-\d{2}',  # YYYY-MM-DD
        r'\d{2}/\d{2}/\d{4}',  # MM/DD/YYYY
        r'\d{4}/\d{2}/\d{2}',  # YYYY/MM/DD
    ]
    
    sample_str = str(values[0]) if values else ""
    for pattern in date_patterns:
        if re.match(pattern, sample_str):
            return "date"
    
    # Check if boolean
    bool_values = {'true', 'false', 'yes', 'no', 'y', 'n', '0', '1'}
    if all(str(v).lower() in bool_values for v in values[:10] if v):
        return "boolean"
    
    return "string"

def generate_description(column_name, column_info):
    """Generate a basic description for a column"""
    col_type = column_info['detected_type']
    
    # Clean column name for description
    clean_name = column_name.replace('_', ' ').title()
    
    # Build description
    desc_parts = [clean_name]
    
    if col_type == "date":
        desc_parts.append("(date field)")
    elif col_type == "numeric":
        desc_parts.append("(numeric value)")
    elif col_type == "boolean":
        desc_parts.append("(yes/no flag)")
    
    # Add uniqueness info
    if column_info['unique_count'] == column_info['non_null_pct']:
        desc_parts.append("- likely unique identifier")
    
    # Add sample values if categorical
    if column_info['unique_count'] < 20 and column_info['sample_values']:
        samples = ', '.join(str(v) for v in column_info['sample_values'][:3])
        desc_parts.append(f"(e.g., {samples})")
    
    return ' '.join(desc_parts)

def generate_metadata_json(analysis, table_name=None):
    """Generate metadata JSON structure"""
    
    # Infer table name from column patterns if not provided
    if not table_name:
        table_name = "your_table_name"
    
    # Generate column descriptions
    columns = {}
    for col, info in analysis['column_info'].items():
        columns[col.lower()] = generate_description(col, info)
    
    # Build metadata structure
    metadata = {
        "table_description": f"Data table with {len(analysis['headers'])} columns and approximately {analysis['total_rows']} rows (update this description)",
        "common_queries": [
            "common search term 1",
            "common search term 2",
            "common search term 3"
        ],
        "columns": columns
    }
    
    return metadata

def main():
    parser = argparse.ArgumentParser(
        description='Generate table metadata JSON from CSV file'
    )
    parser.add_argument('csv_file', help='Path to CSV file')
    parser.add_argument('--table-name', help='Table name (optional)')
    parser.add_argument('--sample-size', type=int, default=100, 
                       help='Number of rows to analyze (default: 100)')
    
    args = parser.parse_args()
    
    try:
        # Analyze CSV
        print("# Analyzing CSV file...", file=sys.stderr)
        analysis = analyze_csv(args.csv_file, args.sample_size)
        
        print(f"# Found {len(analysis['headers'])} columns", file=sys.stderr)
        print(f"# Analyzed {analysis['total_rows']} rows", file=sys.stderr)
        print("", file=sys.stderr)
        
        # Generate metadata
        metadata = generate_metadata_json(analysis, args.table_name)
        
        # Output JSON
        print(json.dumps(metadata, indent=2))
        
        print("", file=sys.stderr)
        print("# ⚠️  Please review and improve the generated descriptions!", file=sys.stderr)
        print("# The auto-generated descriptions are basic. Add domain knowledge.", file=sys.stderr)
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
