#!/usr/bin/env python3

"""Batch-ingest CSV files dropped into the repo's upload directory."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from ingest_csv_to_athena import ingest_csv, sanitize_identifier


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_UPLOAD_DIR = REPO_ROOT / "data" / "uploads"
DEFAULT_PROCESSED_DIR = DEFAULT_UPLOAD_DIR / "processed"
DEFAULT_CONFIG_PATH = REPO_ROOT / "config" / "ingestion-config.json"


def load_config(path: Path) -> Dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError as exc:
        raise SystemExit(
            f"Configuration file not found: {path}. Copy "
            "config/ingestion-config-example.json to ingestion-config.json "
            "and update it with your environment-specific values."
        ) from exc


def ensure_required_config(config: Dict[str, Any], required: List[str]) -> None:
    missing = [key for key in required if not config.get(key)]
    if missing:
        raise SystemExit(
            "Missing required configuration values: " + ", ".join(missing)
        )


def move_to_processed(src: Path, processed_dir: Path) -> Path:
    processed_dir.mkdir(parents=True, exist_ok=True)
    destination = processed_dir / src.name
    if destination.exists():
        stem = destination.stem
        suffix = destination.suffix
        counter = 1
        while True:
            candidate = processed_dir / f"{stem}-{counter}{suffix}"
            if not candidate.exists():
                destination = candidate
                break
            counter += 1
    shutil.move(str(src), destination)
    return destination


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        type=Path,
        default=DEFAULT_CONFIG_PATH,
        help="Path to ingestion configuration JSON file",
    )
    parser.add_argument(
        "--upload-dir",
        type=Path,
        default=DEFAULT_UPLOAD_DIR,
        help="Directory to scan for CSV files",
    )
    parser.add_argument(
        "--processed-dir",
        type=Path,
        default=DEFAULT_PROCESSED_DIR,
        help="Directory to move successfully ingested files",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Maximum number of CSV files to process in one run",
    )
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Skip uploading the CSVs (assume they are already in S3)",
    )
    parser.add_argument(
        "--skip-ddl",
        action="store_true",
        help="Skip running Athena DDL statements",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    ensure_required_config(config, ["bucket", "athena_output"])

    upload_dir = args.upload_dir.expanduser().resolve()
    processed_dir = args.processed_dir.expanduser().resolve()

    upload_dir.mkdir(parents=True, exist_ok=True)

    csv_files = sorted(
        [p for p in upload_dir.glob("*.csv") if p.is_file() and processed_dir not in p.parents]
    )

    if args.limit is not None:
        csv_files = csv_files[: args.limit]

    if not csv_files:
        print(f"No CSV files found in {upload_dir}. Nothing to ingest.")
        return

    print(f"Found {len(csv_files)} CSV file(s) to ingest from {upload_dir}.")

    column_map_dir: Optional[Path] = None
    if config.get("column_map_dir"):
        column_map_dir = (REPO_ROOT / config["column_map_dir"]).expanduser().resolve()
        column_map_dir.mkdir(parents=True, exist_ok=True)

    table_prefix = config.get("table_name_prefix", "")

    failures: List[tuple[Path, str]] = []
    successes: List[Dict[str, Any]] = []

    for csv_file in csv_files:
        table_name_candidate = sanitize_identifier(csv_file.stem)
        if table_prefix:
            table_name = sanitize_identifier(f"{table_prefix}_{table_name_candidate}")
        else:
            table_name = table_name_candidate

        column_map_output = None
        if column_map_dir:
            column_map_output = column_map_dir / f"{table_name}.json"

        print(f"\n--- Processing {csv_file.name} ---")
        try:
            summary = ingest_csv(
                csv_path=csv_file,
                bucket=config["bucket"],
                prefix=config.get("prefix", "custom"),
                table_name=table_name,
                database=config.get("database", "athena_db"),
                athena_output=config["athena_output"],
                region=config.get("region"),
                delimiter=config.get("delimiter", ","),
                quote_char=config.get("quote_char", "\""),
                create_view=bool(config.get("create_view", False)),
                view_suffix=config.get("view_suffix", "view"),
                column_map_output=column_map_output,
                skip_upload=args.skip_upload,
                skip_ddl=args.skip_ddl,
            )
        except Exception as exc:  # noqa: BLE001
            failures.append((csv_file, str(exc)))
            print(f"ERROR: Failed to ingest {csv_file.name}: {exc}")
            continue

        successes.append({
            "file": csv_file,
            "summary": summary,
        })

        try:
            moved_to = move_to_processed(csv_file, processed_dir)
            print(f"Moved {csv_file.name} to {moved_to.relative_to(processed_dir.parent)}")
        except Exception as exc:  # noqa: BLE001
            failures.append((csv_file, f"Ingested but failed to archive: {exc}"))
            print(
                f"WARNING: Ingested {csv_file.name} but could not move to processed folder: {exc}"
            )

    print("\n================ Summary ================")
    if successes:
        for success in successes:
            summary = success["summary"]
            table = summary["table"]
            print(f"SUCCESS: {success['file'].name} -> {table}")
    else:
        print("No files ingested successfully.")

    if failures:
        print("\nIssues encountered:")
        for csv_file, reason in failures:
            print(f"  {csv_file.name}: {reason}")
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("Aborted by user")

