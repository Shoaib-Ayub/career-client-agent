from __future__ import annotations

import json
import re
from pathlib import Path

from .storage import JsonStorage

DATA_DIRECTORY = Path(__file__).resolve().parent / "data"
CATEGORIES = (
    "jobs",
    "scholarships",
    "government_jobs",
    "client_leads",
)
TIMESTAMP_PATTERN = re.compile(r"_(\d{8}T\d{6}Z)\.json$")


def publish_latest(data_directory: Path = DATA_DIRECTORY) -> list[Path]:
    storage = JsonStorage(data_directory)
    published: list[Path] = []
    for category in CATEGORIES:
        directory = data_directory / category
        candidates = [
            path
            for path in directory.glob("*.json")
            if path.name != "latest.json"
            and TIMESTAMP_PATTERN.search(path.name)
        ]
        timestamps = [
            match.group(1)
            for path in candidates
            if (match := TIMESTAMP_PATTERN.search(path.name))
        ]
        if not timestamps:
            continue
        latest_timestamp = max(timestamps)
        records: list[object] = []
        for path in sorted(candidates):
            match = TIMESTAMP_PATTERN.search(path.name)
            if match is None or match.group(1) != latest_timestamp:
                continue
            payload = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(payload, list):
                raise ValueError(f"Expected a JSON list in {path}")
            records.extend(payload)
        output_path = directory / "latest.json"
        storage.write_json(output_path, records)
        published.append(output_path)
    return published


def main() -> int:
    for path in publish_latest():
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
