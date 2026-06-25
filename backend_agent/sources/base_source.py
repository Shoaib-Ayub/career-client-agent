from __future__ import annotations

import json
import re
import time as time_module
from http.client import IncompleteRead
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone
from email.utils import parsedate_to_datetime
from html import unescape
from typing import Any
from urllib.request import Request, urlopen

from ..models import SearchTask

USER_AGENT = "CareerClientAgent/1.0 (+public-source-collector)"
DEFAULT_TIMEOUT_SECONDS = 15
DEFAULT_REQUEST_ATTEMPTS = 3


class SourceCollectionError(RuntimeError):
    """Raised when a public source cannot be collected or parsed."""


class FreshnessWindow:
    TODAY = "today"
    LAST_24_HOURS = "24h"
    LAST_7_DAYS = "7d"
    ALL = "all"
    VALUES = (TODAY, LAST_24_HOURS, LAST_7_DAYS, ALL)


class FreshnessStatus:
    TODAY = "today"
    LAST_24_HOURS = "last_24_hours"
    LAST_7_DAYS = "last_7_days"
    OLDER = "older"
    UNKNOWN = "unknown"
    ORDER = {
        TODAY: 0,
        LAST_24_HOURS: 1,
        LAST_7_DAYS: 2,
        UNKNOWN: 3,
        OLDER: 4,
    }


@dataclass(slots=True)
class SourceOpportunity:
    title: str
    organization: str
    location: str
    source_link: str
    posted_date: str = ""
    deadline: str = ""
    required_skills: list[str] = field(default_factory=list)
    source_name: str = ""
    description: str = ""
    visa_sponsorship: bool = False
    fresher_friendly: bool = False
    training_provided: bool = False
    required_education: str = ""
    eligibility_domicile: str = ""
    age_limit: str = ""
    advertisement_link: str = ""
    match_reason: str = ""
    bs_software_engineering_eligible: str = "Unknown"
    punjab_candidate_eligible: str = "Unknown"
    is_mock: bool = False
    remote_status: str = "Unknown"
    salary: str = ""
    visa_sponsorship_status: str = "Unknown"
    relocation_support_status: str = "Unknown"
    fresher_friendly_status: str = "Unknown"
    training_provided_status: str = "Unknown"
    cv_changes_needed: list[str] = field(default_factory=list)
    force_category: str = ""
    post_count: int | None = None
    job_scale: str = ""
    advertisement_number: str = ""
    is_source_review_link: bool = False
    is_cached: bool = False
    cache_reason: str = ""
    cached_from_run: str = ""
    source_status: str = "live"
    cache_warning: str = ""
    lead_category: str = ""
    budget: str = ""
    budget_type: str = "Unknown"
    country: str = ""
    platform: str = ""
    proposal_url: str = ""
    lead_score: int = 0
    why_good_lead: list[str] = field(default_factory=list)
    suggested_message: str = ""
    short_message: str = ""
    search_keyword: str = ""
    manual_action: str = ""
    expected_lead_type: str = ""
    platform_project_id: str = ""
    normalized_title: str = ""
    normalized_proposal_url: str = ""
    dedupe_key: str = ""


class BaseSource(ABC):
    def __init__(
        self,
        source_name: str,
        timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
        request_attempts: int = DEFAULT_REQUEST_ATTEMPTS,
    ) -> None:
        self.source_name = source_name
        self.timeout_seconds = timeout_seconds
        self.request_attempts = max(1, request_attempts)
        self.last_status = "ok"
        self.failure_reason = ""
        self.fallback_used = False
        self.cached_records_used = 0
        self.cache_snapshot_used = False
        self.cache_snapshot_path = ""

    def reset_status(self) -> None:
        self.last_status = "ok"
        self.failure_reason = ""
        self.fallback_used = False
        self.cached_records_used = 0
        self.cache_snapshot_used = False
        self.cache_snapshot_path = ""

    def mark_degraded(self, reason: str, fallback_used: bool) -> None:
        self.last_status = "timeout" if "timeout" in reason.casefold() else "failed"
        self.failure_reason = reason
        self.fallback_used = fallback_used

    def mark_cached_fallback(
        self,
        records_used: int,
        snapshot_path: str = "",
        stale: bool = False,
    ) -> None:
        self.last_status = (
            "stale_cached_fallback" if stale else "cached_fallback"
        )
        self.fallback_used = records_used > 0
        self.cached_records_used = records_used
        self.cache_snapshot_used = bool(snapshot_path)
        self.cache_snapshot_path = snapshot_path

    def status_report(self) -> dict[str, object]:
        return {
            "source_name": self.source_name,
            "status": self.last_status,
            "failure_reason": self.failure_reason,
            "fallback_used": self.fallback_used,
        }

    @abstractmethod
    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        """Collect normalized opportunities from a public source."""

    def fetch_text(self, url: str) -> str:
        request = Request(
            url,
            headers={
                "Accept": (
                    "text/html, application/json, application/rss+xml, "
                    "application/xml, text/xml"
                ),
                "User-Agent": USER_AGENT,
            },
        )
        last_error: Exception | None = None
        for attempt in range(self.request_attempts):
            try:
                with urlopen(request, timeout=self.timeout_seconds) as response:
                    charset = response.headers.get_content_charset() or "utf-8"
                    try:
                        payload = response.read()
                    except IncompleteRead as error:
                        payload = error.partial
                        if not payload:
                            raise
                    return payload.decode(charset, errors="replace")
            except Exception as error:
                last_error = error
                if attempt < self.request_attempts - 1:
                    time_module.sleep(attempt + 1)
        raise SourceCollectionError(
            f"{self.source_name} request failed: {last_error}"
        ) from last_error

    def fetch_json(self, url: str) -> Any:
        try:
            return json.loads(self.fetch_text(url))
        except (TypeError, json.JSONDecodeError) as error:
            raise SourceCollectionError(
                f"{self.source_name} returned invalid JSON."
            ) from error

    def fetch_bytes(
        self,
        url: str,
        *,
        maximum_bytes: int,
        accept: str = "application/octet-stream",
    ) -> bytes:
        request = Request(
            url,
            headers={
                "Accept": accept,
                "User-Agent": USER_AGENT,
            },
        )
        try:
            with urlopen(request, timeout=self.timeout_seconds) as response:
                content_length = response.headers.get("Content-Length")
                if (
                    content_length
                    and int(content_length) > maximum_bytes
                ):
                    raise SourceCollectionError(
                        f"{self.source_name} skipped a file larger than "
                        f"{maximum_bytes} bytes."
                    )
                payload = response.read(maximum_bytes + 1)
                if len(payload) > maximum_bytes:
                    raise SourceCollectionError(
                        f"{self.source_name} skipped a file larger than "
                        f"{maximum_bytes} bytes."
                    )
                return payload
        except SourceCollectionError:
            raise
        except Exception as error:
            raise SourceCollectionError(
                f"{self.source_name} file request failed: {error}"
            ) from error


def parse_datetime(value: object) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value, tz=timezone.utc)

    text = str(value).strip()
    if not text:
        return None

    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        try:
            parsed = parsedate_to_datetime(text)
        except (TypeError, ValueError, OverflowError):
            parsed = None
            for date_format in (
                "%d-%b-%Y",
                "%d-%m-%Y",
                "%d %b %Y",
                "%b %d, %Y",
                "%B %d, %Y",
            ):
                try:
                    parsed = datetime.strptime(text, date_format)
                    break
                except ValueError:
                    continue
            if parsed is None:
                try:
                    parsed_date = date.fromisoformat(text)
                except ValueError:
                    return None
                parsed = datetime.combine(parsed_date, time.min)

    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def date_value(value: object) -> str:
    parsed = parse_datetime(value)
    return parsed.date().isoformat() if parsed else ""


def datetime_value(value: object) -> str:
    parsed = parse_datetime(value)
    return parsed.isoformat().replace("+00:00", "Z") if parsed else ""


def is_fresh(
    posted_date: str,
    freshness: str,
    now: datetime | None = None,
) -> bool:
    parsed = parse_datetime(posted_date)
    if parsed is None:
        return True

    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if freshness == FreshnessWindow.ALL:
        return True
    if freshness == FreshnessWindow.TODAY:
        return parsed.date() == current.date()
    if freshness == FreshnessWindow.LAST_24_HOURS:
        return parsed >= current - timedelta(hours=24)
    return parsed >= current - timedelta(days=7)


def freshness_status(
    posted_date: str,
    now: datetime | None = None,
) -> str:
    parsed = parse_datetime(posted_date)
    if parsed is None:
        return FreshnessStatus.UNKNOWN

    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if parsed.date() == current.date():
        return FreshnessStatus.TODAY
    if parsed >= current - timedelta(hours=24):
        return FreshnessStatus.LAST_24_HOURS
    if parsed >= current - timedelta(days=7):
        return FreshnessStatus.LAST_7_DAYS
    return FreshnessStatus.OLDER


def filter_fresh(
    results: list[SourceOpportunity],
    freshness: str,
) -> list[SourceOpportunity]:
    return [item for item in results if is_fresh(item.posted_date, freshness)]


def sort_newest(
    results: list[SourceOpportunity],
) -> list[SourceOpportunity]:
    minimum = datetime.min.replace(tzinfo=timezone.utc)
    return sorted(
        results,
        key=lambda item: (
            -FreshnessStatus.ORDER[freshness_status(item.posted_date)],
            parse_datetime(item.posted_date) or minimum,
        ),
        reverse=True,
    )


def deduplicate(
    results: list[SourceOpportunity],
) -> list[SourceOpportunity]:
    unique: list[SourceOpportunity] = []
    seen: set[tuple[str, str, str]] = set()
    for item in results:
        key = (
            _normalize(item.title),
            _normalize(item.organization),
            item.source_link.strip().casefold(),
        )
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)
    return unique


def matches_task(item: SourceOpportunity, task: SearchTask) -> bool:
    searchable = _normalize(
        " ".join(
            [
                item.title,
                item.organization,
                item.location,
                item.description,
                *item.required_skills,
            ]
        )
    )
    keywords = [_normalize(value) for value in task.keywords if value.strip()]
    return not keywords or any(
        _contains_phrase(searchable, keyword) for keyword in keywords
    )


def infer_skills(text: str, task: SearchTask) -> list[str]:
    normalized = _normalize(text)
    candidates = [
        *task.keywords,
        "Python",
        "Flutter",
        "Dart",
        "Machine Learning",
        "Artificial Intelligence",
        "Computer Vision",
        "YOLO",
        "Roboflow",
        "JavaScript",
        "TypeScript",
        "React",
        "SQL",
        "Git",
        "Research",
        "WordPress",
        "Website Redesign",
        "Mobile App Development",
        "Full Stack Development",
        "Web Development",
    ]
    skills: list[str] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = _normalize(candidate)
        if key and _contains_phrase(normalized, key) and key not in seen:
            seen.add(key)
            skills.append(candidate)
    return skills[:8]


def plain_text(value: object) -> str:
    text = re.sub(r"<[^>]+>", " ", str(value or ""))
    return re.sub(r"\s+", " ", unescape(text)).strip()


def extract_deadline(text: str) -> str:
    patterns = (
        r"\b(20\d{2}-\d{2}-\d{2})\b",
        r"\b(\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+20\d{2})\b",
        r"\b((?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2},?\s+20\d{2})\b",
    )
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if not match:
            continue
        parsed = parse_datetime(match.group(1))
        if parsed:
            return parsed.date().isoformat()
    return ""


def _normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().casefold())


def _contains_phrase(text: str, phrase: str) -> bool:
    return bool(
        re.search(
            rf"(?<!\w){re.escape(phrase)}(?!\w)",
            text,
            flags=re.IGNORECASE,
        )
    )
