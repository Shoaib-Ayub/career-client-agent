from __future__ import annotations

import re
import socket
import time as time_module
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote_plus, urljoin
from urllib.request import Request, urlopen

from .base_source import (
    BaseSource,
    SourceCollectionError,
    SourceOpportunity,
    datetime_value,
    deduplicate,
    infer_skills,
    plain_text,
)
from .search_source import SearchSource
from ..models import SearchTask
from ..services.client_lead_quality_service import (
    ClientLeadCategory,
    ClientLeadQualityService,
)

LEAD_KEYWORDS = (
    "Flutter",
    "Flutter Firebase",
    "Flutter AI Integration",
    "Mobile AI App",
    "AI ML",
    "Computer Vision",
    "YOLO Object Detection",
    "TensorFlow Lite",
)

FALLBACK_KEYWORDS = LEAD_KEYWORDS

REMOTE_TERMS = ("remote", "worldwide", "anywhere", "online")
QUALITY_SERVICE = ClientLeadQualityService()


class FreelanceProjectSource(BaseSource):
    def __init__(
        self,
        source_name: str,
        base_url: str,
        search_template: str,
    ) -> None:
        super().__init__(source_name)
        self.base_url = base_url
        self.search_template = search_template

    def fetch_text(self, url: str) -> str:
        request = Request(
            url,
            headers={
                "Accept": "text/html,application/xhtml+xml",
                "User-Agent": "CareerClientAgent/1.0 (+public-client-leads)",
            },
        )
        try:
            with urlopen(request, timeout=4) as response:
                charset = response.headers.get_content_charset() or "utf-8"
                return response.read().decode(charset, errors="replace")
        except Exception as error:
            raise SourceCollectionError(
                f"{self.source_name} request failed: {error}"
            ) from error

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        results: list[SourceOpportunity] = []
        for keyword in _search_keywords(task):
            url = self.search_template.format(query=quote_plus(keyword))
            html = self.fetch_text(url)
            results.extend(self._parse_html(html, task, keyword, url))
        return _rank_leads(deduplicate(results))[
            : max(task.daily_limit * 3, task.daily_limit)
        ]

    def _parse_html(
        self,
        html: str,
        task: SearchTask,
        keyword: str,
        search_url: str,
    ) -> list[SourceOpportunity]:
        text = plain_text(html)
        results: list[SourceOpportunity] = []
        for href, title in _extract_project_links(html):
            normalized_title = QUALITY_SERVICE.normalize_title(
                title,
                urljoin(self.base_url, href),
                self.source_name,
            )
            if not self.is_real_project_url(href):
                continue
            source_link = urljoin(self.base_url, href)
            if not source_link.startswith("https://"):
                continue
            snippet = _nearby_html_text(html, href) or _nearby_text(
                text,
                plain_text(title),
            )
            skills = QUALITY_SERVICE.match_skills(
                f"{normalized_title} {source_link}"
            )
            budget, budget_type = _extract_budget(snippet)
            posted_date = _extract_posted_date(snippet)
            country = _extract_country(snippet)
            remote = _is_remote(f"{normalized_title} {snippet}")
            lead = SourceOpportunity(
                title=normalized_title,
                organization=f"{self.source_name} Client",
                location="Remote" if remote else country or task.location,
                source_link=source_link,
                posted_date=posted_date,
                deadline="",
                required_skills=skills,
                source_name=self.source_name,
                description=snippet,
                fresher_friendly=_is_beginner_friendly(snippet),
                remote_status="Yes" if remote else "Unknown",
                lead_category="",
                budget=budget,
                budget_type=budget_type,
                country=country,
                platform=self.source_name,
                proposal_url=source_link,
                platform_project_id=QUALITY_SERVICE.extract_project_id(
                    self.source_name,
                    source_link,
                ),
            )
            if QUALITY_SERVICE.is_relevant_lead(lead):
                results.append(QUALITY_SERVICE.score_lead(lead))

        relevant_results = [item for item in results if item.required_skills]
        if relevant_results:
            return relevant_results

        return [self._fallback_board_lead(task, keyword, search_url)]

    def is_real_project_url(self, href: str) -> bool:
        return True

    def _fallback_board_lead(
        self,
        task: SearchTask,
        keyword: str,
        search_url: str,
    ) -> SourceOpportunity:
        canonical_keyword = _canonical_fallback_keyword(keyword)
        if not canonical_keyword:
            raise ValueError(f"Unsupported fallback keyword: {keyword}")
        skills = QUALITY_SERVICE.match_skills(keyword) or infer_skills(keyword, task)
        manual_action = QUALITY_SERVICE.fallback_manual_action
        expected_type = QUALITY_SERVICE.expected_lead_type(
            SourceOpportunity(
                title=canonical_keyword,
                organization=f"{self.source_name} Project Board",
                location=task.location,
                source_link=search_url,
                platform=self.source_name,
                proposal_url=search_url,
            )
        )
        board_lead = SourceOpportunity(
            title=(
                f"Fallback Board Link - {self.source_name} - "
                f"{canonical_keyword}"
            ),
            organization=f"{self.source_name} Project Board",
            location=task.location,
            source_link=search_url,
            posted_date=datetime.now(timezone.utc).isoformat().replace(
                "+00:00",
                "Z",
            ),
            source_name=self.source_name,
            description=(
                f"Public {self.source_name} board for paid "
                f"{canonical_keyword} projects. This is a search board, not a "
                "verified individual client lead."
            ),
            remote_status="Unknown",
            lead_category="",
            budget_type="Unknown",
            platform=self.source_name,
            proposal_url=search_url,
            required_skills=skills or [keyword],
            search_keyword=canonical_keyword,
            manual_action=manual_action,
            expected_lead_type=expected_type,
        )
        return QUALITY_SERVICE.score_lead(board_lead)


class FreelancerProjectsSource(FreelanceProjectSource):
    def __init__(self) -> None:
        super().__init__(
            "Freelancer.com",
            "https://www.freelancer.com",
            "https://www.freelancer.com/jobs/?keyword={query}",
        )

    def is_real_project_url(self, href: str) -> bool:
        normalized = href.casefold()
        return (
            "/projects/" in normalized
            and "/users/" not in normalized
            and "/contest/" not in normalized
        )


class FreelancerPublicApiSource(FreelanceProjectSource):
    api_url = (
        "https://www.freelancer.com/api/projects/0.1/projects/active/"
        "?query={query}&compact=true&limit=50"
    )

    def __init__(self) -> None:
        super().__init__(
            "Freelancer Public API",
            "https://www.freelancer.com",
            self.api_url,
        )

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        results: list[SourceOpportunity] = []
        for keyword in _search_keywords(task):
            search_url = self.search_template.format(query=quote_plus(keyword))
            payload = self.fetch_json(search_url)
            keyword_results = self.parse_payload(payload, task)
            if keyword_results:
                results.extend(keyword_results)
                continue
            results.append(
                self._fallback_board_lead(
                    task,
                    keyword,
                    "https://www.freelancer.com/jobs/?keyword="
                    + quote_plus(keyword),
                )
            )
        return _rank_leads(deduplicate(results))[
            : max(task.daily_limit * 3, task.daily_limit)
        ]

    def parse_payload(
        self,
        payload: Any,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        projects = (
            payload.get("result", {}).get("projects", [])
            if isinstance(payload, dict)
            else []
        )
        results: list[SourceOpportunity] = []
        for project in projects:
            if not isinstance(project, dict):
                continue
            title = plain_text(project.get("title"))
            seo_url = str(project.get("seo_url", "")).strip("/")
            project_id = str(project.get("id", "")).strip()
            if not title or not seo_url or not project_id:
                continue
            source_link = (
                f"https://www.freelancer.com/projects/{seo_url}/{project_id}"
            )
            description = plain_text(project.get("preview_description"))
            budget, budget_type = _freelancer_api_budget(project)
            country = plain_text(
                project.get("location", {}).get("country", {}).get("name", "")
            )
            lead = SourceOpportunity(
                title=title,
                organization="Freelancer.com Client",
                location=country or task.location,
                source_link=source_link,
                posted_date=datetime_value(
                    project.get("submitdate") or project.get("time_submitted")
                ),
                required_skills=QUALITY_SERVICE.match_skills(
                    f"{title} {source_link}"
                ),
                source_name=self.source_name,
                description=description,
                remote_status="Yes" if not project.get("local") else "No",
                budget=budget,
                budget_type=budget_type,
                country=country,
                platform="Freelancer.com",
                proposal_url=source_link,
                platform_project_id=project_id,
            )
            if QUALITY_SERVICE.is_relevant_lead(lead):
                results.append(QUALITY_SERVICE.score_lead(lead))
        return results


class PeoplePerHourProjectsSource(FreelanceProjectSource):
    def __init__(self) -> None:
        super().__init__(
            "PeoplePerHour",
            "https://www.peopleperhour.com",
            "https://www.peopleperhour.com/freelance-jobs?keywords={query}",
        )

    def is_real_project_url(self, href: str) -> bool:
        normalized = href.casefold()
        return "/freelance-jobs/" in normalized and not normalized.rstrip(
            "/"
        ).endswith("/freelance-jobs")


class TruelancerProjectsSource(FreelanceProjectSource):
    source_timeout_seconds = 2
    max_attempts = 2

    def __init__(self) -> None:
        super().__init__(
            "Truelancer",
            "https://www.truelancer.com",
            "https://www.truelancer.com/freelance-jobs?searchTerm={query}",
        )
        self.timeout_seconds = self.source_timeout_seconds

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        keyword = _search_keywords(task)[0]
        search_url = self.search_template.format(query=quote_plus(keyword))
        try:
            html = self.fetch_text(search_url)
        except SourceCollectionError as error:
            if "timeout" not in str(error).casefold():
                raise
            reason = (
                f"Timeout after {self.max_attempts} attempts at "
                f"{self.timeout_seconds}s each."
            )
            self.mark_degraded(reason, fallback_used=True)
            return self._cached_fallback_boards(task)
        return self._parse_html(html, task, keyword, search_url)

    def fetch_text(self, url: str) -> str:
        request = Request(
            url,
            headers={
                "Accept": "text/html,application/xhtml+xml",
                "User-Agent": "CareerClientAgent/1.0 (+public-client-leads)",
            },
        )
        last_error: Exception | None = None
        for attempt in range(self.max_attempts):
            try:
                with urlopen(request, timeout=self.timeout_seconds) as response:
                    charset = response.headers.get_content_charset() or "utf-8"
                    return response.read().decode(charset, errors="replace")
            except HTTPError as error:
                raise SourceCollectionError(
                    f"{self.source_name} request failed: HTTP {error.code}"
                ) from error
            except (TimeoutError, socket.timeout, URLError) as error:
                last_error = error
                if attempt < self.max_attempts - 1:
                    time_module.sleep(0.1)
        raise SourceCollectionError(
            f"{self.source_name} timeout: {last_error}"
        ) from last_error

    def _cached_fallback_boards(
        self,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        return [
            self._fallback_board_lead(
                task,
                keyword,
                self.search_template.format(query=quote_plus(keyword)),
            )
            for keyword in FALLBACK_KEYWORDS
        ]

    def is_real_project_url(self, href: str) -> bool:
        normalized = href.casefold()
        return (
            "/freelance-project/" in normalized
            or "/freelance-job/" in normalized
        )


class WorkanaProjectsSource(FreelanceProjectSource):
    def __init__(self) -> None:
        super().__init__(
            "Workana",
            "https://www.workana.com",
            "https://www.workana.com/jobs?query={query}",
        )


class BusinessOutreachSource(BaseSource):
    def __init__(self) -> None:
        super().__init__("Business Outreach Planner")

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        service_ideas = [
            (
                "Flutter Firebase mobile app outreach",
                "Offer a Flutter app with Firebase authentication, storage, and notifications.",
                ["Flutter Development", "Firebase"],
            ),
            (
                "Flutter AI integration outreach",
                "Offer an AI-enabled Flutter app with a production-ready mobile workflow.",
                ["Flutter Development", "AI/ML"],
            ),
            (
                "Mobile AI application outreach",
                "Offer mobile inference, intelligent automation, or AI-assisted app features.",
                ["Mobile AI Apps", "AI/ML"],
            ),
            (
                "Computer Vision YOLO object detection outreach",
                "Offer YOLO object detection for counting, inspection, or monitoring.",
                ["Computer Vision", "YOLO / Object Detection"],
            ),
            (
                "TensorFlow Lite mobile inference outreach",
                "Offer an optimized TensorFlow Lite model integrated into a mobile app.",
                ["TensorFlow / TFLite", "Mobile AI Apps"],
            ),
        ]
        today = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        results: list[SourceOpportunity] = []
        for title, description, skills in service_ideas:
            if not _matches_any_keyword(f"{title} {description}", task.keywords):
                continue
            lead = SourceOpportunity(
                title=title,
                organization="Target local or online businesses",
                location=task.location or "Remote",
                source_link="https://www.google.com/search?q="
                + quote_plus(title),
                posted_date=today,
                required_skills=skills,
                source_name=self.source_name,
                description=description,
                remote_status="Yes",
                lead_category="",
                budget_type="Unknown",
                platform=self.source_name,
                proposal_url="https://www.google.com/search?q="
                + quote_plus(title),
                why_good_lead=[
                    "Targets businesses with clear commercial pain points.",
                    "Good fit for direct outreach when marketplace competition is high.",
                ],
            )
            results.append(QUALITY_SERVICE.score_lead(lead))
        return results[: task.daily_limit]


class GitHubIssuesSource(SearchSource):
    API_URL = "https://api.github.com/search/issues"

    def __init__(self) -> None:
        super().__init__("GitHub Issues")

    def build_url(self, task: SearchTask) -> str:
        primary_keyword = task.keywords[0] if task.keywords else task.title
        query = f'is:issue is:open "{primary_keyword}" label:"help wanted"'
        return self.url(
            self.API_URL,
            {
                "q": query,
                "sort": "created",
                "order": "desc",
                "per_page": min(50, max(task.daily_limit * 3, 10)),
            },
        )

    def parse_payload(
        self,
        payload: Any,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        results: list[SourceOpportunity] = []
        for item in payload.get("items", []):
            title = str(item.get("title", "")).strip()
            body = plain_text(item.get("body"))
            repository_url = str(item.get("repository_url", "")).rstrip("/")
            organization = repository_url.rsplit("/", maxsplit=1)[-1]
            labels = [
                str(label.get("name", ""))
                for label in item.get("labels", [])
                if isinstance(label, dict)
            ]
            lead = SourceOpportunity(
                title=title,
                organization=organization or "GitHub",
                location="Remote",
                source_link=str(item.get("html_url", "")).strip(),
                posted_date=datetime_value(item.get("created_at")),
                required_skills=labels or infer_skills(f"{title} {body}", task),
                source_name=self.source_name,
                description=body,
                fresher_friendly=True,
                remote_status="Yes",
                lead_category="",
                budget_type="Unpaid/Unknown",
                platform=self.source_name,
                proposal_url=str(item.get("html_url", "")).strip(),
                why_good_lead=[
                    "Useful for portfolio building, but not a verified paying client.",
                ],
                suggested_message=(
                    "Hello, I saw this issue and can help with an implementation. "
                    "If this is paid work, I would be glad to discuss scope and timeline."
                ),
            )
            results.append(QUALITY_SERVICE.score_lead(lead))
        return [
            item
            for item in results
            if item.title and item.source_link.startswith("https://")
        ]


def client_leads_sources(include_github: bool = False) -> list[BaseSource]:
    sources: list[BaseSource] = [
        FreelancerPublicApiSource(),
        PeoplePerHourProjectsSource(),
        TruelancerProjectsSource(),
        WorkanaProjectsSource(),
    ]
    if include_github:
        sources.append(GitHubIssuesSource())
    return sources


def _search_keywords(task: SearchTask) -> list[str]:
    keywords = [*task.keywords, *LEAD_KEYWORDS]
    unique: list[str] = []
    seen: set[str] = set()
    for keyword in keywords:
        canonical = _canonical_fallback_keyword(keyword)
        if not canonical:
            continue
        key = canonical.casefold()
        if key in seen:
            continue
        seen.add(key)
        unique.append(canonical)
    return unique


def _canonical_fallback_keyword(keyword: str) -> str:
    normalized = re.sub(r"\s+", " ", keyword.strip().casefold())
    aliases = {
        "flutter": "Flutter",
        "flutter development": "Flutter",
        "flutter developer": "Flutter",
        "flutter firebase": "Flutter Firebase",
        "flutter + firebase": "Flutter Firebase",
        "flutter ai integration": "Flutter AI Integration",
        "flutter + ai integration": "Flutter AI Integration",
        "mobile ai app": "Mobile AI App",
        "mobile ai apps": "Mobile AI App",
        "ai ml": "AI ML",
        "ai/ml": "AI ML",
        "machine learning": "AI ML",
        "computer vision": "Computer Vision",
        "yolo object detection": "YOLO Object Detection",
        "yolo / object detection": "YOLO Object Detection",
        "tensorflow lite": "TensorFlow Lite",
        "tensorflow tflite": "TensorFlow Lite",
        "tflite": "TensorFlow Lite",
        "tensorflow lite / tflite": "TensorFlow Lite",
    }
    return aliases.get(normalized, "")


def _freelancer_api_budget(project: dict[str, Any]) -> tuple[str, str]:
    budget = project.get("budget")
    if not isinstance(budget, dict):
        return "", "Unknown"
    minimum = budget.get("minimum")
    maximum = budget.get("maximum")
    if minimum is None and maximum is None:
        return "", "Unknown"
    currency = project.get("currency")
    if not isinstance(currency, dict):
        currency = {}
    symbol = str(currency.get("sign") or currency.get("code") or "").strip()
    values = [value for value in (minimum, maximum) if value is not None]
    formatted = " - ".join(f"{symbol}{float(value):g}" for value in values)
    budget_type = (
        "Hourly"
        if str(project.get("type", "")).casefold() == "hourly"
        else "Fixed"
    )
    return formatted, budget_type


def _extract_project_links(html: str) -> list[tuple[str, str]]:
    matches = re.findall(
        r"<a\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
        html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    links: list[tuple[str, str]] = []
    for href, title in matches:
        clean_title = plain_text(title)
        if len(clean_title) < 12 or len(clean_title) > 160:
            if not QUALITY_SERVICE.title_from_url(href):
                continue
        normalized_href = href.casefold()
        if any(
            value in normalized_href
            for value in (
                "login",
                "signup",
                "privacy",
                "/static/",
                "-freelancers",
                "translation-",
            )
        ):
            continue
        if QUALITY_SERVICE.is_noisy(clean_title):
            continue
        links.append((href, clean_title))
    return links


def _nearby_text(page_text: str, title: str) -> str:
    index = page_text.casefold().find(title.casefold())
    if index < 0:
        return title
    return page_text[index : index + 800]


def _nearby_html_text(html: str, href: str) -> str:
    index = html.casefold().find(href.casefold())
    if index < 0:
        return ""
    start = max(0, index - 900)
    end = min(len(html), index + 1200)
    return plain_text(html[start:end])


def _extract_budget(text: str) -> tuple[str, str]:
    budget_patterns = (
        r"((?:\$|USD|US\$|£|€|PKR|Rs\.?)\s?\d[\d,]*(?:\s?-\s?(?:\$|USD|US\$|£|€|PKR|Rs\.?)?\s?\d[\d,]*)?)",
        r"(\d[\d,]*\s?(?:USD|GBP|EUR|PKR))",
    )
    for pattern in budget_patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            budget = match.group(1).strip()
            budget_type = "Hourly" if re.search(r"\b(hour|hr|hourly)\b", text, re.I) else "Fixed/Unknown"
            return budget, budget_type
    return "", "Unknown"


def _extract_posted_date(text: str) -> str:
    now = datetime.now(timezone.utc)
    lowered = text.casefold()
    if "today" in lowered or "just now" in lowered:
        return now.isoformat().replace("+00:00", "Z")
    if "yesterday" in lowered:
        return (now - timedelta(days=1)).isoformat().replace("+00:00", "Z")
    match = re.search(r"(\d+)\s+days?\s+ago", lowered)
    if match:
        return (now - timedelta(days=int(match.group(1)))).isoformat().replace(
            "+00:00",
            "Z",
        )
    return now.isoformat().replace("+00:00", "Z")


def _extract_country(text: str) -> str:
    countries = (
        "Pakistan",
        "United States",
        "United Kingdom",
        "Canada",
        "Australia",
        "Germany",
        "UAE",
        "Saudi Arabia",
        "Qatar",
        "India",
        "Remote",
    )
    for country in countries:
        if country.casefold() in text.casefold():
            return country
    return ""


def _is_remote(text: str) -> bool:
    lowered = text.casefold()
    return any(term in lowered for term in REMOTE_TERMS)


def _is_beginner_friendly(text: str) -> bool:
    lowered = text.casefold()
    return any(term in lowered for term in ("beginner", "simple", "small", "junior", "entry"))


def _matches_any_keyword(text: str, keywords: list[str]) -> bool:
    lowered = text.casefold()
    return not keywords or any(keyword.casefold() in lowered for keyword in keywords)


def _rank_leads(leads: list[SourceOpportunity]) -> list[SourceOpportunity]:
    return sorted(
        leads,
        key=lambda item: (item.lead_score, bool(item.budget), item.posted_date),
        reverse=True,
    )
