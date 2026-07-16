from __future__ import annotations

import json
import re
from datetime import date, datetime, timezone
from pathlib import Path
from queue import Empty, Queue
from threading import Semaphore, Thread
from time import monotonic

from .agent_base import BaseOpportunityAgent
from .models import GovernmentJob, SearchTask
from .profile_match_engine import Profile
from .storage import GovernmentJobsSnapshotStorage
from .sources.base_source import (
    FreshnessWindow,
    SourceOpportunity,
    parse_datetime,
    sort_newest,
)
from .sources.government_jobs_sources import (
    finalize_government_result,
    government_deduplicate,
    government_source_diversity,
    government_jobs_sources,
    is_eligible_government_result,
)


class GovernmentJobsAgent(BaseOpportunityAgent[GovernmentJob]):
    STALE_CACHE_WARNING = "Snapshot older than 48 hours"
    source_time_budget_seconds = 120
    max_concurrent_sources = 6
    _templates = (
        {
            "title": "Assistant Director Administration",
            "organization": "Government of Punjab",
            "location": "Punjab, Pakistan",
            "skills": ["Administration", "Management", "Reporting"],
            "fresher_friendly": True,
        },
        {
            "title": "Research Officer",
            "organization": "Federal Government Department",
            "location": "Islamabad, Pakistan",
            "skills": ["Research", "Analysis", "Report Writing"],
            "fresher_friendly": False,
        },
    )

    def __init__(
        self,
        freshness: str = FreshnessWindow.LAST_7_DAYS,
        cache_directory: Path | None = None,
        snapshot_directory: Path | None = None,
    ) -> None:
        super().__init__(government_jobs_sources(), freshness)
        self.cache_directory = cache_directory
        self.snapshot_storage = (
            GovernmentJobsSnapshotStorage(snapshot_directory)
            if snapshot_directory is not None
            else None
        )
        self.diversity_report: dict[str, object] = {}
        self.snapshot_health_report: dict[str, dict[str, object]] = {}
        self.health_summary: dict[str, object] = {}

    def execute(
        self,
        task: SearchTask,
        profile: Profile | None = None,
    ) -> list[GovernmentJob]:
        source_items = self._collect_government_results(task)
        source_items = [
            item
            for item in source_items
            if is_eligible_government_result(item)
        ]
        source_items = self.personalization_service.rank_items(
            source_items,
            task,
            profile,
            preserve_all=True,
        )
        self._write_verified_snapshots(source_items)
        self.snapshot_health_report = self._snapshot_health_report()
        self.health_summary = GovernmentJobsSnapshotStorage.aggregate_health(
            self.snapshot_health_report
        )
        self.diversity_report = government_source_diversity(source_items)
        real_results = [
            GovernmentJob(**self.source_fields(item))
            for item in source_items
        ]
        if real_results:
            return real_results
        if not self.successful_sources:
            return self._mock_results(task)
        return []

    def _collect_government_results(
        self,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        collected: list[SourceOpportunity] = []
        self.failed_sources = []
        self.successful_sources = []
        self.source_reports = []
        indexed_results: dict[int, list[SourceOpportunity]] = {}
        result_queue: Queue[
            tuple[int, list[SourceOpportunity] | None, Exception | None]
        ] = Queue()
        pending = set(range(len(self.sources)))
        source_slots = Semaphore(self.max_concurrent_sources)

        def collect_source(index: int) -> None:
            source = self.sources[index]
            with source_slots:
                try:
                    result_queue.put((index, list(source.collect(task)), None))
                except Exception as error:
                    result_queue.put((index, None, error))

        for index, source in enumerate(self.sources):
            source.reset_status()
            Thread(
                target=collect_source,
                args=(index,),
                name=f"government-source-{index}",
                daemon=True,
            ).start()

        deadline = monotonic() + self.source_time_budget_seconds
        while pending and monotonic() < deadline:
            try:
                index, results, error = result_queue.get(
                    timeout=max(0.01, min(0.25, deadline - monotonic()))
                )
            except Empty:
                continue
            if index not in pending:
                continue
            pending.remove(index)
            source = self.sources[index]
            if error is None:
                indexed_results[index] = results or []
            else:
                source.mark_degraded(str(error), fallback_used=False)
                indexed_results[index] = []
                print(f"Warning: {source.source_name} failed: {error}")

        for index in pending:
            source = self.sources[index]
            source.mark_degraded(
                f"Hard timeout after {self.source_time_budget_seconds} seconds.",
                fallback_used=False,
            )
            indexed_results[index] = []
            print(f"Warning: {source.source_name} timed out.")
        for index, source in enumerate(self.sources):
            live_results = indexed_results.get(index, [])
            collected.extend(live_results)
            if source.last_status == "ok":
                self.successful_sources.append(source.source_name)
            else:
                self.failed_sources.append(source.source_name)
                cached, snapshot_path, snapshot_health = (
                    self._cached_results_for_source(
                        source.source_name
                    )
                )
                if cached:
                    collected.extend(cached)
                    source.mark_cached_fallback(
                        len(cached),
                        snapshot_path=str(snapshot_path or ""),
                        stale=snapshot_health == "stale",
                    )
            report = source.status_report()
            report["cached_records_used"] = source.cached_records_used
            report["cache_snapshot_used"] = source.cache_snapshot_used
            report["cache_snapshot_path"] = source.cache_snapshot_path
            self.source_reports.append(report)
        for item in collected:
            finalize_government_result(item)
        return sort_newest(government_deduplicate(collected))

    def _cached_results_for_source(
        self,
        source_name: str,
    ) -> tuple[list[SourceOpportunity], Path | None, str]:
        snapshot = self._snapshot_cached_results_for_source(source_name)
        if snapshot is not None:
            return snapshot
        return (
            self._historical_cached_results_for_source(source_name),
            None,
            "missing",
        )

    def _snapshot_cached_results_for_source(
        self,
        source_name: str,
    ) -> tuple[list[SourceOpportunity], Path, str] | None:
        storage = self.snapshot_storage
        if storage is None:
            return None
        snapshot = storage.read_snapshot(source_name)
        if snapshot is None:
            return None
        path, payload = snapshot
        health = storage.snapshot_health(source_name)
        snapshot_health = str(health["snapshot_health"])
        generated_at = str(payload.get("generated_at") or path.stem)
        records = payload.get("records")
        if not isinstance(records, list):
            return [], path, snapshot_health
        verified = [
            item
            for record in records
            if isinstance(record, dict)
            and (
                item := self._verified_cached_item(
                    record,
                    generated_at,
                )
            )
            is not None
        ]
        if snapshot_health == "stale":
            for item in verified:
                item.source_status = "stale_cached_fallback"
                item.cache_warning = self.STALE_CACHE_WARNING
        return verified, path, snapshot_health

    def _historical_cached_results_for_source(
        self,
        source_name: str,
    ) -> list[SourceOpportunity]:
        directory = self.cache_directory
        if directory is None or not directory.exists():
            return []
        files = sorted(
            directory.glob("*.json"),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
        for path in files:
            try:
                payload = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if not isinstance(payload, list):
                continue
            matching = [
                record
                for record in payload
                if isinstance(record, dict)
                and str(
                    record.get("source")
                    or record.get("source_name")
                    or ""
                )
                == source_name
            ]
            if not matching:
                continue
            cached_from_run = self._cached_run_timestamp(path)
            return [
                item
                for record in matching
                if (
                    item := self._verified_cached_item(
                        record,
                        cached_from_run,
                    )
                )
                is not None
            ]
        return []

    def _write_verified_snapshots(
        self,
        source_items: list[SourceOpportunity],
    ) -> None:
        storage = self.snapshot_storage
        if storage is None:
            return
        generated_at = datetime.now(timezone.utc).isoformat().replace(
            "+00:00",
            "Z",
        )
        records_by_source: dict[str, list[GovernmentJob]] = {
            source_name: [] for source_name in self.successful_sources
        }
        for item in source_items:
            if (
                item.is_cached
                or item.is_mock
                or item.is_source_review_link
                or item.source_name not in records_by_source
                or not is_eligible_government_result(item)
            ):
                continue
            records_by_source[item.source_name].append(
                GovernmentJob(**self.source_fields(item))
            )
        for source_name, records in records_by_source.items():
            try:
                storage.write_snapshot(
                    source_name,
                    generated_at,
                    records,
                )
            except OSError as error:
                print(
                    "Warning: could not write Government Jobs snapshot "
                    f"for {source_name}: {error}"
                )

    def _snapshot_health_report(
        self,
    ) -> dict[str, dict[str, object]]:
        storage = self.snapshot_storage
        if storage is None:
            return {}
        source_names = sorted(
            {source.source_name for source in self.sources}
        )
        return {
            source_name: storage.snapshot_health(source_name)
            for source_name in source_names
        }

    @staticmethod
    def _cached_run_timestamp(path: Path) -> str:
        match = re.search(
            r"_(\d{8}T\d{6}Z)\.json$",
            path.name,
        )
        return match.group(1) if match else path.stem

    @staticmethod
    def _verified_cached_item(
        record: dict[str, object],
        cached_from_run: str,
    ) -> SourceOpportunity | None:
        source_link = str(
            record.get("apply_url")
            or record.get("source_link")
            or record.get("apply_link")
            or ""
        ).strip()
        if (
            not source_link.startswith(("http://", "https://"))
            or bool(record.get("is_mock"))
            or bool(record.get("is_source_review_link"))
            or str(
                record.get("bs_software_engineering_eligible") or ""
            )
            != "Yes"
            or str(record.get("punjab_candidate_eligible") or "")
            != "Yes"
        ):
            return None
        deadline = str(
            record.get("application_deadline")
            or record.get("deadline")
            or ""
        )
        parsed_deadline = parse_datetime(deadline)
        if (
            parsed_deadline is None
            or parsed_deadline.date() < date.today()
        ):
            return None
        item = SourceOpportunity(
            title=str(record.get("title") or ""),
            organization=str(
                record.get("department")
                or record.get("organization")
                or ""
            ),
            location=str(
                record.get("province_city")
                or record.get("location")
                or ""
            ),
            source_link=source_link,
            posted_date=str(record.get("posted_date") or ""),
            deadline=deadline,
            required_skills=[
                str(value)
                for value in (
                    record.get("required_skills")
                    or record.get("skills")
                    or []
                )
            ],
            source_name=str(
                record.get("source")
                or record.get("source_name")
                or ""
            ),
            description=str(record.get("description") or ""),
            required_education=str(
                record.get("qualification_required")
                or record.get("required_education")
                or record.get("qualification")
                or ""
            ),
            eligibility_domicile=str(
                record.get("domicile_required")
                or record.get("eligibility_domicile")
                or ""
            ),
            age_limit=str(record.get("age_limit") or ""),
            advertisement_link=str(
                record.get("advertisement_link") or ""
            ),
            advertisement_number=str(
                record.get("advertisement_number") or ""
            ),
            post_count=_optional_int(record.get("post_count")),
            job_scale=str(record.get("job_scale") or ""),
            force_category=str(record.get("force_category") or ""),
            is_cached=True,
            cache_reason="source_unavailable",
            cached_from_run=str(
                record.get("cached_from_run") or cached_from_run
            ),
            source_status="cached_fallback",
        )
        finalize_government_result(item)
        return item if is_eligible_government_result(item) else None

    def _mock_results(self, task: SearchTask) -> list[GovernmentJob]:
        posted_date, deadline = self.dates(deadline_days=21)
        results: list[GovernmentJob] = []
        for index, template in enumerate(
            self._templates[: self.result_count(task, len(self._templates))]
        ):
            source = SourceOpportunity(
                    title=template["title"],
                    organization=template["organization"],
                    location=template["location"],
                    source_link=(
                        f"{self.source_base_url}/government-jobs/{task.id}/{index + 1}"
                    ),
                    posted_date=posted_date,
                    deadline=deadline,
                    required_skills=self.task_skills(task, template["skills"]),
                    visa_sponsorship=False,
                    fresher_friendly=template["fresher_friendly"],
                    training_provided=True,
                    source_name="Mock fallback",
                    required_education="BS or equivalent 16 years education",
                    eligibility_domicile="Punjab/Pakistan mock eligibility",
                    advertisement_link="",
                    is_mock=True,
                )
            finalize_government_result(source)
            results.append(
                GovernmentJob(**self.source_fields(source))
            )
        return results


def _optional_int(value: object) -> int | None:
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return round(value)
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return None
