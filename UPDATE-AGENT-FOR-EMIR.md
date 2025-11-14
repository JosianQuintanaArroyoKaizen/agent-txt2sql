# How to Update Bedrock Agent for EMIR Dataset

## Problem
Your Bedrock agent is currently configured to only query the sample dataset (`customers` and `procedures` tables). To query the EMIR dataset, you need to add the `test_population` table schema to the agent's orchestration prompt.

## Solution

### Step 1: Verify the Table Exists in Athena

First, check if the `test_population` table (or `test_population_view`) exists in your Athena database:

1. Go to **Amazon Athena** console
2. Select database: `txt2sql_dev_athena_db`
3. Run this query:
   ```sql
   SHOW TABLES LIKE 'test_population%';
   ```

You should see either:
- `test_population` (the base table with sanitized column names)
- `test_population_view` (the view with original column names mapped back)

**Note:** Based on your config (`create_view: true`), you likely have both. Use `test_population_view` for better readability.

### Step 2: Update Bedrock Agent Orchestration Prompt

1. Go to **Amazon Bedrock** console
2. Navigate to **Agents** → Select your agent (e.g., `AthenaAgent-...`)
3. Click **Edit**
4. Scroll down to **Advanced prompts** section
5. Click **Edit** next to **Orchestration**
6. Find the section with `<athena_schemas>` (around line 368-396)
7. Add the EMIR table schema **after** the procedures schema and **before** the closing `</athena_schemas>` tag

#### Option A: Using the Base Table (`test_population`)

Add this schema block:

```xml
<athena_schema>
CREATE EXTERNAL TABLE txt2sql_dev_athena_db.test_population (
  `action_type_2_151` STRING,
  `asset_class_2_11` STRING,
  `base_product_2_116` STRING,
  `broker_id_1_15` STRING,
  `cds_index_attachment_point_2_149` STRING,
  `cds_index_detachment_point_2_150` STRING,
  `central_counterparty_2_33` STRING,
  `cleared_2_31` STRING,
  `clearing_date_2_32` STRING,
  `clearing_member_1_16` STRING,
  `clearing_obligation_2_30` STRING,
  `clearing_threshold_of_counterparty_1_1_7` STRING,
  `clearing_threshold_of_counterparty_2_1_13` STRING,
  `clearing_time_2_32` STRING,
  `clearing_time_time_zone_2_32` STRING,
  `clearing_timestamp_2_32` STRING,
  `collateral_portfolio_code_2_27` STRING,
  `collateral_portfolio_indicator_2_26` STRING,
  `confirmation_date_2_28` STRING,
  `confirmation_time_2_28` STRING,
  `confirmation_time_time_zone_2_28` STRING,
  `confirmation_timestamp_2_28` STRING,
  `confirmed_2_29` STRING,
  `contract_type_2_10` STRING,
  `corporate_sector_of_the_counterparty_1_1_6_fi` STRING,
  `corporate_sector_of_the_counterparty_1_1_6_nfi` STRING,
  `corporate_sector_of_the_counterparty_2_1_12_fi` STRING,
  `corporate_sector_of_the_counterparty_2_1_12_nfi` STRING,
  `counterparty_1_reporting_counterparty_1_4` STRING,
  `counterparty_2_1_9` STRING,
  `counterparty_2_identifier_type_1_8` STRING,
  `country_of_the_counterparty_2_1_10` STRING,
  `currency_of_the_price_time_interval_quantity_2_131` STRING,
  `custom_basket_code_2_17` STRING,
  `days_of_the_week_2_127` STRING,
  `delivery_capacity_2_128` STRING,
  `delivery_end_date_2_125` STRING,
  `delivery_interval_end_time_2_123` STRING,
  `delivery_interval_start_time_2_122` STRING,
  `delivery_point_or_zone_2_119` STRING,
  `delivery_start_date_2_124` STRING,
  `delivery_type_2_47` STRING,
  `delta_2_25` STRING,
  `derivative_based_on_crypto_assets_2_12` STRING,
  `direction_1_17` STRING,
  `direction_of_leg_1_1_18` STRING,
  `direction_of_leg_2_1_19` STRING,
  `directly_linked_to_commercial_activity_or_treasury_financing_1_20` STRING,
  `duration_2_126` STRING,
  `early_termination_date_2_45` STRING,
  `effective_date_2_43` STRING,
  `effective_date_of_the_notional_amount_of_leg_1_2_57` STRING,
  `effective_date_of_the_notional_amount_of_leg_2_2_66` STRING,
  `effective_date_of_the_notional_quantity_of_leg_1_2_61` STRING,
  `effective_date_of_the_notional_quantity_of_leg_2_2_70` STRING,
  `effective_date_of_the_strike_price_2_135` STRING,
  `end_date_of_the_notional_amount_of_leg_1_2_58` STRING,
  `end_date_of_the_notional_amount_of_leg_2_2_67` STRING,
  `end_date_of_the_notional_quantity_of_leg_1_2_62` STRING,
  `end_date_of_the_notional_quantity_of_leg_2_2_71` STRING,
  `end_date_of_the_strike_price_2_136` STRING,
  `end_relationship_party_1_21` STRING,
  `entity_responsible_for_reporting_1_3` STRING,
  `event_date_2_153` STRING,
  `event_type_2_152` STRING,
  `exchange_rate_1_2_113` STRING,
  `exchange_rate_basis_2_115` STRING,
  `exchange_traded_indicator_kr` STRING,
  `execution_agent_1_21` STRING,
  `execution_agent_id_other_counterparty_1_21` STRING,
  `execution_agent_id_reporting_counterparty_1_21` STRING,
  `execution_date_2_42` STRING,
  `execution_time_2_42` STRING,
  `execution_time_ms_2_42` STRING,
  `execution_time_time_zone_2_42` STRING,
  `execution_timestamp_2_42` STRING,
  `expiration_date_2_44` STRING,
  `final_contractual_settlement_date_2_46` STRING,
  `fixed_rate_day_count_convention_leg_2_2_96` STRING,
  `fixed_rate_of_leg_1_or_coupon_2_79` STRING,
  `fixed_rate_of_leg_2_2_95` STRING,
  `fixed_rate_or_coupon_day_count_convention_leg_1_2_80` STRING,
  `fixed_rate_or_coupon_payment_frequency_period_leg_1_2_81` STRING,
  `fixed_rate_or_coupon_payment_frequency_period_multiplier_leg_1_2_82` STRING,
  `fixed_rate_payment_frequency_period_leg_2_2_97` STRING,
  `fixed_rate_payment_frequency_period_multiplier_leg_2_2_98` STRING,
  `floating_rate_day_count_convention_of_leg_1_2_86` STRING,
  `floating_rate_day_count_convention_of_leg_2_2_102` STRING,
  `floating_rate_payment_frequency_period_multiplier_of_leg_1_2_88` STRING,
  `floating_rate_payment_frequency_period_multiplier_of_leg_2_2_104` STRING,
  `floating_rate_payment_frequency_period_of_leg_1_2_87` STRING,
  `floating_rate_payment_frequency_period_of_leg_2_2_103` STRING,
  `floating_rate_reference_period_of_leg_1_multiplier_2_90` STRING,
  `floating_rate_reference_period_of_leg_1_time_period_2_89` STRING,
  `floating_rate_reference_period_of_leg_2_multiplier_2_106` STRING,
  `floating_rate_reference_period_of_leg_2_time_period_2_105` STRING,
  `floating_rate_reset_frequency_multiplier_of_leg_1_2_92` STRING,
  `floating_rate_reset_frequency_multiplier_of_leg_2_2_108` STRING,
  `floating_rate_reset_frequency_period_of_leg_1_2_91` STRING,
  `floating_rate_reset_frequency_period_of_leg_2_2_107` STRING,
  `forward_exchange_rate_2_114` STRING,
  `further_sub_product_2_118` STRING,
  `identifier_of_the_basket_s_constituents_2_18` STRING,
  `identifier_of_the_floating_rate_of_leg_1_2_83` STRING,
  `identifier_of_the_floating_rate_of_leg_2_2_99` STRING,
  `incident_code` STRING,
  `incident_description` STRING,
  `index_factor_2_147` STRING,
  `indicator_of_the_floating_rate_of_leg_1_2_84` STRING,
  `indicator_of_the_floating_rate_of_leg_2_2_100` STRING,
  `indicator_of_the_underlying_index_2_15` STRING,
  `inter_connection_point_2_120` STRING,
  `intragroup_2_37` STRING,
  `isin_2_7` STRING,
  `kr_record_key` STRING,
  `level_2_154` STRING,
  `load_type_2_121` STRING,
  `master_agreement_type_2_34` STRING,
  `master_agreement_version_2_36` STRING,
  `maturity_date_of_the_underlying_2_142` STRING,
  `name_of_the_floating_rate_of_leg_1_2_85` STRING,
  `name_of_the_floating_rate_of_leg_2_2_101` STRING,
  `name_of_the_underlying_index_2_16` STRING,
  `nature_of_the_counterparty_1_1_5` STRING,
  `nature_of_the_counterparty_2_1_11` STRING,
  `notional_amount_in_effect_on_associated_effective_date_of_leg_1_2_59_mntry_amt` STRING,
  `notional_amount_in_effect_on_associated_effective_date_of_leg_1_2_59_mntry_ccy` STRING,
  `notional_amount_in_effect_on_associated_effective_date_of_leg_2_2_68_mntry_amt` STRING,
  `notional_amount_in_effect_on_associated_effective_date_of_leg_2_2_68_mntry_ccy` STRING,
  `notional_amount_of_leg_1_2_55` STRING,
  `notional_amount_of_leg_2_2_64` STRING,
  `notional_currency_1_2_56` STRING,
  `notional_currency_2_2_65` STRING,
  `notional_quantity_in_effect_on_associated_effective_date_of_leg_1_2_63` STRING,
  `notional_quantity_in_effect_on_associated_effective_date_of_leg_2_2_72` STRING,
  `number_of_execution_agents_1_21` STRING,
  `option_premium_amount_2_139` STRING,
  `option_premium_currency_2_140` STRING,
  `option_premium_payment_date_2_141` STRING,
  `option_style_2_133` STRING,
  `option_type_2_132` STRING,
  `other_master_agreement_type_2_35` STRING,
  `other_payment_amount_2_74` STRING,
  `other_payment_currency_2_75` STRING,
  `other_payment_date_2_76` STRING,
  `other_payment_payer_2_77_lgl` STRING,
  `other_payment_payer_2_77_ntrl` STRING,
  `other_payment_receiver_2_78_lgl` STRING,
  `other_payment_receiver_2_78_ntrl` STRING,
  `other_payment_type_2_73` STRING,
  `package_identifier_2_6` STRING,
  `package_transaction_price_2_53` STRING,
  `package_transaction_price_currency_2_54` STRING,
  `package_transaction_spread_2_111` STRING,
  `package_transaction_spread_currency_2_112` STRING,
  `price_2_48` STRING,
  `price_currency_2_49` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_dcml` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_mntry_amt` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_mntry_ccy` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_mntry_sgn` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_other_tp` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_other_val` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_pctg` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_pending_price` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_unit` STRING,
  `price_in_effect_between_the_unadjusted_effective_and_end_date_2_52_yld` STRING,
  `price_time_interval_quantity_2_130` STRING,
  `price_time_interval_quantity_2_130_sgn` STRING,
  `prior_uti_2_3` STRING,
  `product_classification_2_9` STRING,
  `ptrr_2_38` STRING,
  `ptrr_id_2_5` STRING,
  `ptrr_service_provider_2_40` STRING,
  `quantity_unit_2_129` STRING,
  `reference_entity_2_144` STRING,
  `report_submitting_entity_id_1_2` STRING,
  `report_tracking_number_2_2` STRING,
  `reporting_date_1_1` STRING,
  `reporting_obligation_of_the_counterparty_2_1_14` STRING,
  `reporting_time_1_1` STRING,
  `reporting_time_ms_1_1` STRING,
  `reporting_time_time_zone_1_1` STRING,
  `reporting_timestamp_1_1` STRING,
  `seniority_2_143` STRING,
  `series_2_145` STRING,
  `settlement_currency_1_2_19` STRING,
  `settlement_currency_2_2_20` STRING,
  `source_file_name` STRING,
  `spread_currency_of_leg_1_2_94` STRING,
  `spread_currency_of_leg_2_2_110` STRING,
  `spread_of_leg_1_2_93` STRING,
  `spread_of_leg_2_2_109` STRING,
  `start_relationship_party_1_21` STRING,
  `strike_price_2_134` STRING,
  `strike_price_currency_currency_pair_2_138` STRING,
  `strike_price_in_effect_on_associated_effective_date_2_137_mntry_amt` STRING,
  `strike_price_in_effect_on_associated_effective_date_2_137_mntry_ccy` STRING,
  `strike_price_in_effect_on_associated_effective_date_2_137_mntry_sgn` STRING,
  `strike_price_in_effect_on_associated_effective_date_2_137_pctg` STRING,
  `sub_product_2_117` STRING,
  `subsequent_position_uti_2_4` STRING,
  `total_notional_quantity_of_leg_1_2_60` STRING,
  `total_notional_quantity_of_leg_2_2_69` STRING,
  `trade_allege` STRING,
  `tranche_2_148` STRING,
  `type_of_ptrr_technique_2_39` STRING,
  `unadjusted_effective_date_of_the_price_2_50` STRING,
  `unadjusted_end_date_of_the_price_2_51` STRING,
  `underlying_identification_2_14` STRING,
  `underlying_identification_type_2_13` STRING,
  `unique_product_identifier_upi_2_8` STRING,
  `uti_2_1` STRING,
  `valuation_amount_2_21` STRING,
  `valuation_currency_2_22` STRING,
  `valuation_date_2_23` STRING,
  `valuation_method_2_24` STRING,
  `valuation_time_2_23` STRING,
  `valuation_time_ms_2_23` STRING,
  `valuation_time_time_zone_2_23` STRING,
  `valuation_timestamp_2_23` STRING,
  `venue_of_execution_2_41` STRING,
  `version_2_146` STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar' = '"'
)
STORED AS TEXTFILE
LOCATION 's3://sl-data-store-txt2sql-dev-194561596031-eu-central-1/custom/test_population/'
TBLPROPERTIES ('skip.header.line.count'='1');
</athena_schema>
```

#### Option B: Using the View (`test_population_view`) - Recommended

If you have a view, use `test_population_view` instead. The schema is the same, just change the table name.

### Step 3: Update the Guidelines Section

Find the line that says:
```
The Athena database name is ${AliasDb}_${AthenaDatabaseName} and the tables are ${AliasDb}_customers and ${AliasDb}_procedures:
```

Update it to include the EMIR table:
```
The Athena database name is txt2sql_dev_athena_db and the tables are customers, procedures, and test_population (or test_population_view):
```

### Step 4: Add Example Queries (Optional but Recommended)

Add some example queries for the EMIR table in the `<athena_examples>` section:

```xml
<athena_example>
SELECT incident_code, incident_description, uti_2_1, valuation_amount_2_21, valuation_currency_2_22 
FROM txt2sql_dev_athena_db.test_population 
WHERE valuation_amount_2_21 IS NOT NULL 
LIMIT 10;
</athena_example>

<athena_example>
SELECT COUNT(*) as total_records, 
       COUNT(DISTINCT counterparty_1_reporting_counterparty_1_4) as unique_counterparties
FROM txt2sql_dev_athena_db.test_population;
</athena_example>
```

### Step 5: Save and Prepare

1. Click **Save and exit**
2. Click **Prepare** to prepare a new version
3. Wait for preparation to complete
4. Test with a query like: "Show me some records from the EMIR dataset" or "What counterparties are in the test_population table?"

## Quick Reference: Key EMIR Fields

The EMIR dataset has 224 columns. Here are some key fields that users might query:

- **Identifiers**: `uti_2_1`, `isin_2_7`, `kr_record_key`, `incident_code`
- **Counterparties**: `counterparty_1_reporting_counterparty_1_4`, `counterparty_2_1_9`
- **Valuation**: `valuation_amount_2_21`, `valuation_currency_2_22`, `valuation_date_2_23`
- **Clearing**: `cleared_2_31`, `clearing_obligation_2_30`, `central_counterparty_2_33`
- **Product Info**: `asset_class_2_11`, `product_classification_2_9`, `contract_type_2_10`
- **Dates**: `execution_date_2_42`, `effective_date_2_43`, `expiration_date_2_44`
- **Notional**: `notional_amount_of_leg_1_2_55`, `notional_amount_of_leg_2_2_64`

## Troubleshooting

### If queries still return sample data:

1. **Check the agent version**: Make sure you're testing with the newly prepared version
2. **Verify table exists**: Run `SHOW TABLES` in Athena to confirm `test_population` exists
3. **Check S3 location**: Verify the S3 path in the schema matches where your CSV was uploaded
4. **Test directly in Athena**: Try running a query directly in Athena first to ensure the table works

### If you get "table not found" errors:

- Verify the database name is correct: `txt2sql_dev_athena_db`
- Check if you should use `test_population_view` instead of `test_population`
- Run `DESCRIBE txt2sql_dev_athena_db.test_population;` in Athena to verify the table structure

## Alternative: Generate Schema Automatically

You can also run the helper script to regenerate the schema:

```bash
python3 scripts/generate_emir_schema.py
```

This will output the schema in the correct format for copy-pasting into the Bedrock agent.

