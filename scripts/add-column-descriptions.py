#!/usr/bin/env python3
"""
Add human-readable descriptions to AWS Glue Data Catalog columns.
This makes column metadata available to the Bedrock agent via DESCRIBE queries.
"""

import boto3
import json

glue_client = boto3.client('glue')

# Column metadata mappings
COLUMN_DESCRIPTIONS = {
    'txt2sql_dev_customers': {
        'cust_id': 'Unique customer identifier (primary key)',
        'customer': 'Customer full name',
        'balance': 'Current account balance in dollars',
        'past_due': 'Past due amount in dollars',
        'vip': 'VIP status (yes/no)'
    },
    'txt2sql_dev_procedures': {
        'procedure_id': 'Unique procedure identifier (primary key)',
        'procedure': 'Name/description of the medical procedure',
        'category': 'Procedure category (consultation, imaging, laboratory, dental, surgery, rehabilitation, preventative)',
        'price': 'Procedure price in dollars',
        'duration': 'Duration in minutes',
        'insurance_covered': 'Whether insurance covers this procedure (yes/no)',
        'customer_id': 'Associated customer ID (foreign key to customers table)'
    },
    'test_population': {
        # Critical columns for EMIR trade data
        'uti_2_1': 'UTI - Unique Transaction Identifier (primary key for trades)',
        'reporting_date_1_1': 'PRIMARY DATE FIELD - When the trade was reported to repository (YYYY-MM-DD format)',
        'execution_date_2_42': 'When the trade was executed/agreed upon',
        'valuation_date_2_23': 'Date of the trade valuation',
        'expiration_date_2_44': 'Contract expiration/maturity date',
        
        # Counterparties
        'counterparty_1_reporting_counterparty_1_4': 'Identifier of the reporting counterparty (LEI code typically)',
        'counterparty_2_1_9': 'Identifier of the second counterparty',
        'nature_of_the_counterparty_1_1_5': 'Type/nature of counterparty 1 (e.g., Financial, Non-Financial)',
        
        # Financial data
        'valuation_amount_2_21': 'Valuation amount (stored as STRING - CAST to DOUBLE for calculations)',
        'valuation_currency_2_22': 'Currency code for valuation (e.g., USD, EUR, GBP)',
        'notional_amount_of_leg_1_2_55': 'Notional amount for leg 1 of the trade',
        'price_2_48': 'Trade price',
        
        # Product classification
        'asset_class_2_11': 'Asset class (e.g., Interest Rate, FX, Commodity, Equity, Credit)',
        'contract_type_2_10': 'Type of derivative contract',
        'product_classification_2_9': 'Detailed product classification code',
        'isin_2_7': 'ISIN code identifying the instrument',
        
        # Trade status
        'cleared_2_31': 'Whether trade was cleared through CCP (Y/N)',
        'confirmed_2_29': 'Whether trade is confirmed (Y/N)',
        'direction_1_17': 'Trade direction from reporting party perspective (Buy/Sell)',
        'venue_of_execution_2_41': 'Trading venue where trade was executed',
        
        # Add more as needed...
    }
}

def update_table_column_descriptions(database_name, table_name, column_descriptions):
    """
    Update column descriptions in AWS Glue Data Catalog
    """
    try:
        # Get current table definition
        response = glue_client.get_table(
            DatabaseName=database_name,
            Name=table_name
        )
        
        table_input = response['Table']
        
        # Remove read-only fields
        table_input.pop('DatabaseName', None)
        table_input.pop('CreateTime', None)
        table_input.pop('UpdateTime', None)
        table_input.pop('CreatedBy', None)
        table_input.pop('IsRegisteredWithLakeFormation', None)
        table_input.pop('CatalogId', None)
        table_input.pop('VersionId', None)
        
        # Update column descriptions
        updated_columns = []
        for column in table_input['StorageDescriptor']['Columns']:
            column_name_lower = column['Name'].lower()
            
            # Add description if we have one
            if column_name_lower in column_descriptions:
                column['Comment'] = column_descriptions[column_name_lower]
                print(f"  ✓ {column['Name']}: {column['Comment'][:60]}...")
            
            updated_columns.append(column)
        
        table_input['StorageDescriptor']['Columns'] = updated_columns
        
        # Update the table
        glue_client.update_table(
            DatabaseName=database_name,
            TableInput=table_input
        )
        
        print(f"✅ Updated {len(column_descriptions)} column descriptions for {table_name}\n")
        return True
        
    except Exception as e:
        print(f"❌ Error updating {table_name}: {str(e)}\n")
        return False

def main():
    """
    Main function to update all table column descriptions
    """
    database_name = 'txt2sql_dev_athena_db'  # Update this to your database name
    
    print(f"🔧 Updating column descriptions in database: {database_name}\n")
    print("=" * 70)
    
    success_count = 0
    total_tables = len(COLUMN_DESCRIPTIONS)
    
    for table_name, descriptions in COLUMN_DESCRIPTIONS.items():
        print(f"\n📊 Table: {table_name}")
        print("-" * 70)
        
        if update_table_column_descriptions(database_name, table_name, descriptions):
            success_count += 1
    
    print("=" * 70)
    print(f"\n✨ Complete! Updated {success_count}/{total_tables} tables")
    print("\n💡 Next steps:")
    print("   1. Run DESCRIBE table_name in Athena to see column comments")
    print("   2. Agent will now see descriptions when discovering schemas")
    print("   3. Add more column descriptions to COLUMN_DESCRIPTIONS dict as needed")

if __name__ == '__main__':
    main()
