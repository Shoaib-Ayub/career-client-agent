from __future__ import annotations

import json
import re
from dataclasses import asdict, is_dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


class JsonStorage:
    def __init__(self, base_directory: Path) -> None:
        self.base_directory = base_directory

    def read_list(self, path: Path) -> list[dict[str, Any]]:
        if not path.exists():
            return []
        with path.open("r", encoding="utf-8") as file:
            payload = json.load(file)
        if not isinstance(payload, list):
            raise ValueError(f"Expected a JSON list in {path}")
        return payload

    def write_results(
        self,
        category: str,
        task_id: str,
        results: Iterable[Any],
        timestamp: str | None = None,
    ) -> Path:
        output_directory = self.base_directory / category
        output_directory.mkdir(parents=True, exist_ok=True)
        generation = timestamp or datetime.now(timezone.utc).strftime(
            "%Y%m%dT%H%M%SZ"
        )
        output_path = output_directory / f"{task_id}_{generation}.json"
        payload = [self._serialize(result) for result in results]
        self.write_json(output_path, payload)
        return output_path

    def write_json(self, path: Path, payload: Any) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = path.with_suffix(f"{path.suffix}.tmp")
        with temporary_path.open("w", encoding="utf-8") as file:
            json.dump(payload, file, indent=2, ensure_ascii=False)
            file.write("\n")
        temporary_path.replace(path)

    @staticmethod
    def _serialize(value: Any) -> Any:
        if hasattr(value, "to_dict"):
            return value.to_dict()
        if is_dataclass(value):
            return asdict(value)
        return value


class GovernmentJobsSnapshotStorage:
    FRESH_HOURS = 48
    CRITICAL_SOURCES = (
        "National Job Portal Pakistan",
        "Punjab Jobs Portal",
        "PPSC",
        "FPSC",
    )
    PRIMARY_SOURCES = (
        "National Job Portal Pakistan",
        "Punjab Jobs Portal",
    )
    _FILE_NAMES = {
        "National Job Portal Pakistan": "njp_verified.json",
        "Punjab Jobs Portal": "punjab_jobs_portal_verified.json",
        "PPSC": "ppsc_verified.json",
        "FPSC": "fpsc_verified.json",
    }

    def __init__(self, directory: Path) -> None:
        self.directory = directory
        self.storage = JsonStorage(directory)

    def path_for_source(self, source_name: str) -> Path:
        file_name = self._FILE_NAMES.get(source_name)
        if file_name is None:
            slug = re.sub(
                r"[^a-z0-9]+",
                "_",
                source_name.casefold(),
            ).strip("_")
            file_name = f"{slug or 'other_source'}_verified.json"
        return self.directory / file_name

    def write_snapshot(
        self,
        source_name: str,
        generated_at: str,
        records: Iterable[Any],
    ) -> Path:
        serialized_records = [
            self.storage._serialize(record) for record in records
        ]
        path = self.path_for_source(source_name)
        self.storage.write_json(
            path,
            {
                "source_name": source_name,
                "generated_at": generated_at,
                "record_count": len(serialized_records),
                "records": serialized_records,
            },
        )
        return path

    def read_snapshot(
        self,
        source_name: str,
    ) -> tuple[Path, dict[str, Any]] | None:
        path = self.path_for_source(source_name)
        if not path.exists():
            return None
        try:
            with path.open("r", encoding="utf-8") as file:
                payload = json.load(file)
        except (OSError, json.JSONDecodeError):
            return None
        if not isinstance(payload, dict):
            return None
        records = payload.get("records")
        if (
            payload.get("source_name") != source_name
            or not isinstance(records, list)
        ):
            return None
        return path, payload

    def snapshot_health(
        self,
        source_name: str,
        now: datetime | None = None,
    ) -> dict[str, Any]:
        path = self.path_for_source(source_name)
        snapshot = self.read_snapshot(source_name)
        if snapshot is None:
            return {
                "snapshot_exists": False,
                "snapshot_generated_at": "",
                "snapshot_age_hours": None,
                "snapshot_record_count": 0,
                "snapshot_health": "missing",
                "snapshot_path": str(path),
            }
        _, payload = snapshot
        generated_at = str(payload.get("generated_at") or "")
        records = payload.get("records")
        record_count = (
            len(records) if isinstance(records, list) else 0
        )
        age_hours = self._age_hours(generated_at, now=now)
        if record_count == 0:
            health = "empty"
        elif age_hours is None or age_hours > self.FRESH_HOURS:
            health = "stale"
        else:
            health = "fresh"
        return {
            "snapshot_exists": True,
            "snapshot_generated_at": generated_at,
            "snapshot_age_hours": age_hours,
            "snapshot_record_count": record_count,
            "snapshot_health": health,
            "snapshot_path": str(path),
        }

    @classmethod
    def aggregate_health(
        cls,
        source_health: dict[str, dict[str, Any]],
    ) -> dict[str, Any]:
        counts = {
            status: sum(
                1
                for health in source_health.values()
                if health.get("snapshot_health") == status
            )
            for status in ("fresh", "stale", "empty", "missing")
        }
        total_sources = len(source_health)
        usable_sources = counts["fresh"] + counts["stale"]
        usable_percentage = (
            round((usable_sources / total_sources) * 100, 2)
            if total_sources
            else 0.0
        )
        critical_missing = [
            source_name
            for source_name in cls.CRITICAL_SOURCES
            if source_health.get(source_name, {}).get(
                "snapshot_health",
                "missing",
            )
            == "missing"
        ]
        critical_stale = [
            source_name
            for source_name in cls.CRITICAL_SOURCES
            if source_health.get(source_name, {}).get(
                "snapshot_health"
            )
            == "stale"
        ]
        primary_unavailable = [
            source_name
            for source_name in cls.PRIMARY_SOURCES
            if source_health.get(source_name, {}).get(
                "snapshot_health",
                "missing",
            )
            in {"missing", "stale"}
        ]
        if usable_sources == 0 or len(primary_unavailable) == 2:
            overall_health = "critical"
        elif (
            critical_missing
            or critical_stale
            or usable_percentage < 50
        ):
            overall_health = "warning"
        else:
            overall_health = "healthy"

        warnings: list[str] = []
        for source_name in cls.CRITICAL_SOURCES:
            status = source_health.get(source_name, {}).get(
                "snapshot_health",
                "missing",
            )
            if status in {"missing", "stale", "empty"}:
                warnings.append(
                    f"{source_name} snapshot is {status}"
                )
        if usable_percentage < 50:
            percentage = f"{usable_percentage:g}"
            warnings.append(
                f"Only {percentage}% of sources have usable snapshots"
            )
        return {
            "total_sources": total_sources,
            "fresh_sources": counts["fresh"],
            "stale_sources": counts["stale"],
            "empty_sources": counts["empty"],
            "missing_sources": counts["missing"],
            "usable_snapshot_sources": usable_sources,
            "usable_snapshot_percentage": usable_percentage,
            "critical_sources_missing": critical_missing,
            "critical_sources_stale": critical_stale,
            "overall_health": overall_health,
            "warnings": warnings,
        }

    @staticmethod
    def _age_hours(
        generated_at: str,
        now: datetime | None = None,
    ) -> float | None:
        if not generated_at:
            return None
        try:
            normalized = generated_at.replace("Z", "+00:00")
            generated = datetime.fromisoformat(normalized)
        except ValueError:
            return None
        if generated.tzinfo is None:
            generated = generated.replace(tzinfo=timezone.utc)
        current = now or datetime.now(timezone.utc)
        if current.tzinfo is None:
            current = current.replace(tzinfo=timezone.utc)
        hours = (current - generated.astimezone(timezone.utc)).total_seconds()
        return round(max(0.0, hours / 3600), 2)
