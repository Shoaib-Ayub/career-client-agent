from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .storage import JsonStorage

DATA_DIRECTORY = Path(__file__).resolve().parent / "data"
CATEGORY_BY_TASK_TYPE = {
    "job": "jobs",
    "scholarship": "scholarships",
    "governmentJob": "government_jobs",
    "clientLead": "client_leads",
}
TIMESTAMP_PATTERN = re.compile(r"_(\d{8}T\d{6}Z)\.json$")
CLIENT_LEAD_TARGET_TERMS = (
    "flutter",
    "firebase",
    "ai",
    "ml",
    "artificial intelligence",
    "machine learning",
    "computer vision",
    "yolo",
    "object detection",
    "tensorflow",
    "tflite",
    "mobile ai",
)
CLIENT_LEAD_FORBIDDEN_SKILLS = (
    "hr",
    "human resources",
    "virtual assistant",
    "customer support",
    "marketing",
    "wordpress",
    "shopify",
    "seo",
    "data entry",
    "translation",
)


def publish_latest(data_directory: Path = DATA_DIRECTORY) -> list[Path]:
    storage = JsonStorage(data_directory)
    published: list[Path] = []
    tasks_by_category = _active_task_ids_by_category(data_directory)
    for category, task_ids in tasks_by_category.items():
        directory = data_directory / category
        candidates = _task_output_candidates(directory, task_ids)
        if not candidates:
            continue
        latest_timestamp = max(timestamp for _, timestamp in candidates)
        records: list[object] = []
        for path, timestamp in sorted(candidates):
            if timestamp != latest_timestamp:
                continue
            payload = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(payload, list):
                raise ValueError(f"Expected a JSON list in {path}")
            records.extend(payload)
        if category == "client_leads":
            _validate_client_leads(records)
        output_path = directory / "latest.json"
        storage.write_json(output_path, records)
        published.append(output_path)
    return published


def _active_task_ids_by_category(
    data_directory: Path,
) -> dict[str, set[str]]:
    tasks_path = data_directory / "search_tasks.json"
    payload = json.loads(tasks_path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError(f"Expected a JSON list in {tasks_path}")
    task_ids = {
        category: set() for category in CATEGORY_BY_TASK_TYPE.values()
    }
    for task in payload:
        if not isinstance(task, dict) or not task.get("is_active", True):
            continue
        category = CATEGORY_BY_TASK_TYPE.get(str(task.get("task_type")))
        task_id = str(task.get("id") or "").strip()
        if category and task_id:
            task_ids[category].add(task_id)
    return task_ids


def _task_output_candidates(
    directory: Path,
    task_ids: set[str],
) -> list[tuple[Path, str]]:
    candidates: list[tuple[Path, str]] = []
    for path in directory.glob("*.json"):
        match = TIMESTAMP_PATTERN.search(path.name)
        if match is None:
            continue
        task_id = path.name[: match.start()]
        if task_id in task_ids:
            candidates.append((path, match.group(1)))
    return candidates


def _validate_client_leads(records: list[object]) -> None:
    for index, value in enumerate(records):
        if not isinstance(value, dict):
            raise ValueError(
                f"Client Lead record {index} is not a JSON object."
            )
        record: dict[str, Any] = value
        category = str(record.get("lead_category") or "")
        if category == "Fallback Board Link":
            search_keyword = str(record.get("search_keyword") or "")
            expected_type = str(record.get("expected_lead_type") or "")
            relevance_text = f"{search_keyword} {expected_type}".casefold()
        else:
            title = str(record.get("title") or "")
            source_link = str(
                record.get("proposal_url")
                or record.get("source_link")
                or ""
            )
            relevance_text = f"{title} {source_link}".casefold()
        if not any(
            _contains_term(relevance_text, term)
            for term in CLIENT_LEAD_TARGET_TERMS
        ):
            raise ValueError(
                "Refusing to publish unrelated Client Lead: "
                f"{record.get('title', '<untitled>')}"
            )
        skills = record.get("skills") or record.get("required_skills") or []
        if isinstance(skills, list):
            normalized_skills = {
                str(skill).strip().casefold() for skill in skills
            }
            forbidden = sorted(
                skill
                for skill in normalized_skills
                if any(
                    _contains_term(skill, term)
                    for term in CLIENT_LEAD_FORBIDDEN_SKILLS
                )
            )
            if forbidden:
                raise ValueError(
                    "Refusing to publish Client Lead with unrelated skills "
                    f"{forbidden}: {record.get('title', '<untitled>')}"
                )


def _contains_term(text: str, term: str) -> bool:
    return (
        re.search(
            rf"(?<![a-z0-9]){re.escape(term)}(?![a-z0-9])",
            text,
        )
        is not None
    )


def main() -> int:
    for path in publish_latest():
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
