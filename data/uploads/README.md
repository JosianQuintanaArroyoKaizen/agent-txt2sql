# Upload Drop Zone

Place raw CSV files in this directory when you want to ingest them into the
project's Amazon S3/Athena environment. The helper script
`scripts/ingest_uploads.py` will pick up any `.csv` files located here
(excluding the `processed/` subfolder), sanitize the headers, upload to S3,
create the Athena external table, and optionally generate a view preserving
the original column names.

Workflow:

1. Copy your CSV into this folder.
2. Adjust `config/ingestion-config.json` (create it from the
   `ingestion-config-example.json` template if it does not exist yet).
3. Run `./scripts/ingest_uploads.py`.
4. On success, the CSV is moved to `processed/` for traceability and the table
   will be ready for querying in Athena.

Files that fail ingestion remain in place so you can fix the input and retry.

