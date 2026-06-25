from __future__ import annotations

import json
import re
from typing import Any
from urllib.parse import quote_plus, urljoin

from ..models import SearchTask, TaskType
from .base_source import (
    BaseSource,
    SourceCollectionError,
    SourceOpportunity,
    FreshnessStatus,
    datetime_value,
    extract_deadline,
    infer_skills,
    plain_text,
    freshness_status,
)
from .rss_source import RssSource
from .search_source import SearchSource

TARGET_ROLES = (
    "ai engineer",
    "artificial intelligence engineer",
    "machine learning engineer",
    "computer vision engineer",
    "data scientist",
    "data analyst",
    "ai/ml intern",
    "ai engineer intern",
    "computer vision intern",
    "flutter developer",
    "flutter + ai developer",
    "junior software engineer",
    "software engineer trainee",
    "associate software engineer",
    "junior ai engineer",
    "associate ai engineer",
    "associate ml engineer",
    "trainee ai engineer",
    "trainee ai/ml engineer",
    "junior data science engineer",
)

FRESHER_TERMS = (
    "fresher",
    "fresh graduate",
    "entry level",
    "entry-level",
    "junior",
    "associate",
    "trainee",
    "graduate program",
    "graduate programme",
    "paid internship",
    "internship",
    "intern",
    "management trainee",
    "0-2 years",
    "0 to 2 years",
    "1-2 years",
    "1 to 2 years",
)

SENIOR_TERMS = (
    "senior",
    "sr.",
    "lead ",
    "principal",
    "staff engineer",
    "manager",
    "director",
    "head of",
)

EDUCATION_TERMS = (
    "bs software engineering",
    "bs computer science",
    "bs information technology",
    "bs it",
    "bs artificial intelligence",
    "bs ai",
    "bachelor's degree in computer science",
    "bachelors degree in computer science",
    "bachelor degree in computer science",
    "computer science or related field",
    "16 years education",
    "fresh graduate",
)

TIER_1 = ("pakistan", "germany", "united arab emirates", "uae", "saudi arabia", "qatar")
TIER_2 = (
    "united kingdom",
    "uk",
    "canada",
    "australia",
    "singapore",
    "malaysia",
)


class ArbeitnowJobsSource(SearchSource):
    API_URL = "https://www.arbeitnow.com/api/job-board-api"

    def __init__(self) -> None:
        super().__init__("Arbeitnow")

    def build_url(self, task: SearchTask) -> str:
        return self.API_URL

    def parse_payload(
        self,
        payload: Any,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        return [
            _from_mapping(
                item,
                task,
                source_name=self.source_name,
                company_key="company_name",
                link_key="url",
                location_key="location",
                posted_key="created_at",
                description_key="description",
                skills=[str(value) for value in item.get("tags", [])],
            )
            for item in payload.get("data", [])
            if isinstance(item, dict)
        ]


class RemotiveJobsSource(SearchSource):
    API_URL = "https://remotive.com/api/remote-jobs"

    def __init__(self) -> None:
        super().__init__("Remotive")

    def build_url(self, task: SearchTask) -> str:
        return self.url(
            self.API_URL,
            {"search": _search_phrase(task), "limit": 100},
        )

    def parse_payload(
        self,
        payload: Any,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        return [
            _from_mapping(
                item,
                task,
                source_name=self.source_name,
                company_key="company_name",
                link_key="url",
                location_key="candidate_required_location",
                posted_key="publication_date",
                description_key="description",
                skills=[str(value) for value in item.get("tags", [])],
                default_location="Remote Worldwide",
            )
            for item in payload.get("jobs", [])
            if isinstance(item, dict)
        ]


class RemoteOkJobsSource(SearchSource):
    API_URL = "https://remoteok.com/api"

    def __init__(self) -> None:
        super().__init__("RemoteOK")

    def build_url(self, task: SearchTask) -> str:
        return self.API_URL

    def parse_payload(
        self,
        payload: Any,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        if not isinstance(payload, list):
            return []
        results = []
        for item in payload:
            if not isinstance(item, dict) or not item.get("position"):
                continue
            normalized = {
                "title": item.get("position"),
                "company": item.get("company"),
                "location": item.get("location") or "Remote Worldwide",
                "url": item.get("url"),
                "date": item.get("date") or item.get("epoch"),
                "description": item.get("description"),
            }
            results.append(
                _from_mapping(
                    normalized,
                    task,
                    source_name=self.source_name,
                    company_key="company",
                    link_key="url",
                    location_key="location",
                    posted_key="date",
                    description_key="description",
                    skills=[str(value) for value in item.get("tags", [])],
                    default_location="Remote Worldwide",
                )
            )
        return results


class LinkedInPublicJobsSource(BaseSource):
    def __init__(self) -> None:
        super().__init__("LinkedIn Jobs Public Search")

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        location = "Germany" if _visa_task(task) else "Pakistan"
        url = (
            "https://www.linkedin.com/jobs/search/"
            f"?keywords={quote_plus(_search_phrase(task))}"
            f"&location={quote_plus(location)}&f_TPR=r604800"
        )
        html = self.fetch_text(url)
        cards = re.findall(
            r"<li>(.*?base-search-card.*?</li>)",
            html,
            flags=re.IGNORECASE | re.DOTALL,
        )
        results = []
        for card in cards:
            link = _match(
                r"<a\b[^>]*class=\"[^\"]*base-card__full-link[^\"]*\""
                r"[^>]*href=\"([^\"]+)\"",
                card,
            )
            title = _match(
                r"class=\"base-search-card__title\"[^>]*>(.*?)</h3>",
                card,
            )
            company = _match(
                r"class=\"base-search-card__subtitle\"[^>]*>(.*?)</h4>",
                card,
            )
            job_location = _match(
                r"class=\"job-search-card__location\"[^>]*>(.*?)</span>",
                card,
            )
            posted = _match(r"<time[^>]*datetime=\"([^\"]+)\"", card)
            if not link or not title:
                continue
            item = SourceOpportunity(
                title=plain_text(title),
                organization=plain_text(company) or "Employer",
                location=plain_text(job_location) or location,
                source_link=_clean_link(link),
                posted_date=datetime_value(posted),
                required_skills=infer_skills(title, task),
                source_name=self.source_name,
                description=plain_text(card),
            )
            finalize_private_job(item)
            results.append(item)
        return _valid(results)


class RozeePublicJobsSource(BaseSource):
    def __init__(self) -> None:
        super().__init__("Rozee.pk")

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        url = (
            "https://www.rozee.pk/job/jsearch/q/"
            f"{quote_plus(_search_phrase(task))}"
        )
        html = self.fetch_text(url)
        marker = '"jobs":{"sponsored":'
        start = html.find(marker)
        basic = html.find('"basic":', start)
        if start < 0 or basic < 0:
            raise SourceCollectionError(
                "Rozee.pk did not expose its public listing payload."
            )
        payload, _ = json.JSONDecoder().raw_decode(
            html[basic + len('"basic":') :]
        )
        results = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            description = plain_text(
                item.get("description_raw") or item.get("description")
            )
            salary = _rozee_salary(item)
            source = SourceOpportunity(
                title=str(item.get("title", "")).strip(),
                organization=str(
                    item.get("company_name") or item.get("company") or ""
                ).strip(),
                location=", ".join(
                    value
                    for value in [
                        str(item.get("city", "")).strip(),
                        str(item.get("country", "Pakistan")).strip(),
                    ]
                    if value
                ),
                source_link=(
                    "https://www.rozee.pk/"
                    f"{str(item.get('rozeePermaLink') or item.get('permaLink') or '').strip()}"
                ),
                posted_date=datetime_value(
                    item.get("created_at") or item.get("displayDate")
                ),
                deadline=datetime_value(item.get("applyBy"))[:10],
                required_skills=[
                    str(value) for value in item.get("skills", [])
                ],
                source_name=self.source_name,
                description=description,
                salary=salary,
            )
            finalize_private_job(source)
            results.append(source)
        return _valid(results)


class PublicJobLinksSource(BaseSource):
    def __init__(
        self,
        source_name: str,
        listing_url: str,
        link_pattern: str,
        default_location: str,
    ) -> None:
        super().__init__(source_name)
        self.listing_url = listing_url
        self.link_pattern = link_pattern
        self.default_location = default_location

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        html = self.fetch_text(self.listing_url)
        results = []
        for match in re.finditer(
            self.link_pattern,
            html,
            flags=re.IGNORECASE | re.DOTALL,
        ):
            link = urljoin(self.listing_url, match.group(1))
            title = plain_text(match.group(2))
            if not is_target_private_role(title):
                continue
            context = plain_text(
                html[max(0, match.start() - 500) : match.end() + 1000]
            )
            item = SourceOpportunity(
                title=title,
                organization=_company_from_context(context, self.source_name),
                location=_location_from_context(
                    context,
                    self.default_location,
                ),
                source_link=link,
                posted_date=_posted_from_context(context),
                deadline=extract_deadline(context),
                required_skills=infer_skills(context, task),
                source_name=self.source_name,
                description=context,
                salary=_extract_salary(context),
            )
            finalize_private_job(item)
            results.append(item)
        return _valid(results)


class GreenhouseCompanyJobsSource(BaseSource):
    BOARDS = ("deepmind", "scaleai", "careem")

    def __init__(self) -> None:
        super().__init__("Company Career Pages (Greenhouse)")

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        results = []
        for board in self.BOARDS:
            payload = self.fetch_json(
                "https://boards-api.greenhouse.io/v1/boards/"
                f"{board}/jobs?content=true"
            )
            for job in payload.get("jobs", []):
                title = str(job.get("title", "")).strip()
                if not is_target_private_role(title):
                    continue
                description = plain_text(job.get("content"))
                item = SourceOpportunity(
                    title=title,
                    organization=board.replace("-", " ").title(),
                    location=str(
                        (job.get("location") or {}).get("name")
                        or "Unknown"
                    ),
                    source_link=str(job.get("absolute_url", "")).strip(),
                    posted_date=datetime_value(job.get("updated_at")),
                    deadline=extract_deadline(description),
                    required_skills=infer_skills(
                        f"{title} {description}",
                        task,
                    ),
                    source_name=self.source_name,
                    description=description,
                    salary=_extract_salary(description),
                )
                finalize_private_job(item)
                results.append(item)
        return _valid(results)


class UnavailablePublicSource(BaseSource):
    def __init__(self, source_name: str, reason: str) -> None:
        super().__init__(source_name)
        self.reason = reason

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        raise SourceCollectionError(self.reason)


class PublicAvailabilitySource(BaseSource):
    """Checks a public page but returns no unstable/unstructured cards."""

    def __init__(self, source_name: str, url: str) -> None:
        super().__init__(source_name)
        self.url = url

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        self.fetch_text(self.url)
        return []


def job_sources() -> list[BaseSource]:
    return [
        LinkedInPublicJobsSource(),
        RozeePublicJobsSource(),
        PublicJobLinksSource(
            "Mustakbil",
            "https://www.mustakbil.com/jobs/pakistan/information-technology",
            r"class=\"job-title__link\"[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>",
            "Pakistan",
        ),
        PublicJobLinksSource(
            "BrightSpyre",
            "https://resume.brightspyre.com/jobs",
            r"class=\"text-decoration-none title-job\"[^>]*"
            r"href=\"([^\"]+)\"[^>]*>(.*?)</a>",
            "Pakistan",
        ),
        RemoteOkJobsSource(),
        RssSource(
            source_name="We Work Remotely",
            query_template=(
                "https://weworkremotely.com/categories/"
                "remote-programming-jobs.rss?query={query}"
            ),
            default_location="Remote Worldwide",
        ),
        ArbeitnowJobsSource(),
        RemotiveJobsSource(),
        GreenhouseCompanyJobsSource(),
        PublicAvailabilitySource(
            "National Job Portal",
            "https://www.njp.gov.pk/jobs/live",
        ),
        PublicAvailabilitySource(
            "Google Jobs Public Search",
            "https://www.google.com/search?q=AI+Engineer+jobs+Pakistan",
        ),
        PublicAvailabilitySource(
            "TechJuice Jobs",
            "https://www.techjuice.pk/",
        ),
        UnavailablePublicSource(
            "Indeed",
            "Public job search returned HTTP 403; no bypass attempted.",
        ),
        UnavailablePublicSource(
            "Wellfound",
            "Public job search returned HTTP 403; no bypass attempted.",
        ),
        UnavailablePublicSource(
            "Glassdoor",
            "Public job search returned HTTP 403; no bypass attempted.",
        ),
    ]


def finalize_private_job(item: SourceOpportunity) -> None:
    evidence = " ".join(
        [
            item.title,
            item.organization,
            item.location,
            item.description,
        ]
    )
    item.remote_status = _remote_status(evidence)
    item.visa_sponsorship_status = _status(
        evidence,
        positive=(
            "visa sponsorship",
            "sponsor visa",
            "work visa provided",
            "visa support",
        ),
        negative=("no visa sponsorship", "unable to sponsor", "without sponsorship"),
    )
    item.relocation_support_status = _status(
        evidence,
        positive=(
            "relocation support",
            "relocation assistance",
            "relocation package",
            "relocation provided",
        ),
        negative=("no relocation",),
    )
    item.fresher_friendly_status = _fresher_status(evidence)
    item.training_provided_status = _status(
        evidence,
        positive=(
            "training provided",
            "training program",
            "training programme",
            "mentorship",
            "graduate program",
            "trainee program",
            "learning budget",
        ),
        negative=("no training",),
    )
    item.visa_sponsorship = item.visa_sponsorship_status == "Yes"
    item.fresher_friendly = item.fresher_friendly_status == "Yes"
    item.training_provided = item.training_provided_status == "Yes"
    item.required_education = _education(evidence)
    item.salary = item.salary or _extract_salary(evidence)
    if not item.required_skills:
        item.required_skills = infer_skills(evidence, _fallback_task())
    item.required_skills = _unique(
        [*item.required_skills, *_canonical_skills(evidence)]
    )[:10]
    reasons = []
    if is_target_private_role(item.title):
        reasons.append("The role matches the requested AI, data, computer vision, Flutter, or junior software track.")
    if item.fresher_friendly_status == "Yes":
        reasons.append("The listing is suitable for a fresher, intern, trainee, associate, or 0–2 year candidate.")
    if item.visa_sponsorship_status == "Yes" or item.relocation_support_status == "Yes":
        reasons.append("The listing mentions visa sponsorship or relocation support.")
    elif "pakistan" in item.location.casefold():
        reasons.append("The Pakistan location can help build relevant early-career experience.")
    item.match_reason = " ".join(reasons)
    item.cv_changes_needed = _cv_suggestions(item)


def is_suitable_private_job(item: SourceOpportunity) -> bool:
    evidence = f"{item.title} {item.description}".casefold()
    if not is_target_private_role(item.title):
        return False
    if any(term in item.title.casefold() for term in SENIOR_TERMS):
        return False
    if item.fresher_friendly_status == "No":
        return False
    if any(
        value in evidence
        for value in (
            "phd required",
            "doctorate required",
            "master's degree required",
            "masters degree required",
        )
    ):
        return False
    experience = [
        int(value)
        for value in re.findall(r"\b(\d+)\+?\s*years?", evidence)
    ]
    if experience and min(experience) > 2:
        return False
    if item.required_education and not any(
        term in item.required_education.casefold() for term in EDUCATION_TERMS
    ):
        return False
    return True


def private_job_rank(
    item: SourceOpportunity,
) -> tuple[int, int, int, int, str]:
    visa_priority = (
        0
        if item.visa_sponsorship_status == "Yes"
        or item.relocation_support_status == "Yes"
        else 1
    )
    location = item.location.casefold()
    if "pakistan" in location:
        country_priority = 0
    elif any(value in location for value in TIER_1):
        country_priority = 1
    elif any(value in location for value in TIER_2):
        country_priority = 2
    elif item.remote_status == "Yes":
        country_priority = 3
    else:
        country_priority = 4
    fresher_priority = 0 if item.fresher_friendly_status == "Yes" else 1
    freshness_priority = FreshnessStatus.ORDER[
        freshness_status(item.posted_date)
    ]
    return (
        visa_priority,
        country_priority,
        fresher_priority,
        freshness_priority,
        item.title.casefold(),
    )


def is_target_private_role(value: str) -> bool:
    normalized = value.casefold()
    return any(role in normalized for role in TARGET_ROLES)


def _from_mapping(
    item: dict[str, Any],
    task: SearchTask,
    *,
    source_name: str,
    company_key: str,
    link_key: str,
    location_key: str,
    posted_key: str,
    description_key: str,
    skills: list[str],
    default_location: str = "Remote",
) -> SourceOpportunity:
    description = plain_text(item.get(description_key))
    title = str(item.get("title", "")).strip()
    result = SourceOpportunity(
        title=title,
        organization=str(item.get(company_key, "")).strip(),
        location=str(item.get(location_key) or default_location).strip(),
        source_link=str(item.get(link_key, "")).strip(),
        posted_date=datetime_value(item.get(posted_key)),
        deadline=extract_deadline(description),
        required_skills=_unique(
            skills or infer_skills(f"{title} {description}", task)
        ),
        source_name=source_name,
        description=description,
        salary=_extract_salary(description),
    )
    finalize_private_job(result)
    return result


def _valid(results: list[SourceOpportunity]) -> list[SourceOpportunity]:
    return [
        item
        for item in results
        if item.title
        and item.organization
        and item.source_link.startswith(("http://", "https://"))
    ]


def _search_phrase(task: SearchTask) -> str:
    if _visa_task(task):
        return "Junior Machine Learning Engineer"
    return "AI Engineer"


def _visa_task(task: SearchTask) -> bool:
    return any(
        value in " ".join(task.filters).casefold()
        for value in ("visa", "relocation")
    )


def _status(
    text: str,
    *,
    positive: tuple[str, ...],
    negative: tuple[str, ...],
) -> str:
    normalized = text.casefold()
    if any(value in normalized for value in negative):
        return "No"
    if any(value in normalized for value in positive):
        return "Yes"
    return "Unknown"


def _remote_status(text: str) -> str:
    normalized = text.casefold()
    if any(value in normalized for value in ("remote", "work from home", "worldwide")):
        return "Yes"
    if any(value in normalized for value in ("on-site", "onsite", "in office")):
        return "No"
    return "Unknown"


def _fresher_status(text: str) -> str:
    normalized = text.casefold()
    if any(value in normalized for value in SENIOR_TERMS):
        return "No"
    if any(value in normalized for value in FRESHER_TERMS):
        return "Yes"
    experience = [
        int(value)
        for value in re.findall(r"\b(\d+)\+?\s*years?", normalized)
    ]
    if experience:
        return "Yes" if min(experience) <= 2 else "No"
    return "Unknown"


def _education(text: str) -> str:
    plain = plain_text(text)
    sentences = re.split(r"(?<=[.;])\s+|\s{2,}", plain)
    for sentence in sentences:
        if len(sentence) <= 500 and any(
            value in sentence.casefold() for value in EDUCATION_TERMS
        ):
            return sentence[:500]
    return ""


def _extract_salary(text: str) -> str:
    patterns = (
        r"\b(?:PKR|Rs\.?|AED|SAR|QAR|EUR|GBP|USD|\$|€|£)\s*"
        r"[\d,]+(?:\s*(?:-|to)\s*(?:PKR|Rs\.?|AED|SAR|QAR|EUR|GBP|USD|\$|€|£)?\s*[\d,]+)?"
        r"(?:\s*(?:per|/)\s*(?:month|year|hour))?",
        r"\b[\d,]+\s*(?:-|to)\s*[\d,]+\s*(?:PKR|AED|SAR|QAR|EUR|GBP|USD)\b",
    )
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            return plain_text(match.group(0))
    return ""


def _rozee_salary(item: dict[str, Any]) -> str:
    value = item.get("salary") or item.get("salary_text")
    if value:
        return str(value).strip()
    minimum = item.get("salary_min")
    maximum = item.get("salary_max")
    currency = item.get("currency_unit") or "PKR"
    if minimum or maximum:
        return f"{currency} {minimum or ''}-{maximum or ''}".strip("-")
    return ""


def _cv_suggestions(item: SourceOpportunity) -> list[str]:
    skills = item.required_skills[:3]
    suggestions = [
        f"Add a project or measurable achievement demonstrating {skill}."
        for skill in skills
    ]
    if "computer vision" in f"{item.title} {item.description}".casefold():
        suggestions.append(
            "Highlight YOLO, Roboflow, model evaluation, and deployment results."
        )
    if "flutter" in item.title.casefold():
        suggestions.append(
            "Show Flutter architecture, state management, APIs, and released app evidence."
        )
    return suggestions[:4]


def _canonical_skills(text: str) -> list[str]:
    normalized = text.casefold()
    skills = []
    if any(value in normalized for value in ("ai engineer", "ai/ml", "machine learning")):
        skills.extend(["Python", "Machine Learning", "Artificial Intelligence"])
    if "computer vision" in normalized:
        skills.extend(["Python", "Computer Vision", "YOLO"])
    if "flutter" in normalized:
        skills.extend(["Flutter", "Dart"])
    if any(value in normalized for value in ("data scientist", "data analyst")):
        skills.extend(["Python", "SQL", "Data Analysis"])
    if "software engineer" in normalized:
        skills.extend(["Software Engineering", "Git"])
    return skills


def _company_from_context(text: str, fallback: str) -> str:
    match = re.search(
        r"(?:company|organization)\s*[:\-]?\s*([^|]{2,100})",
        text,
        flags=re.IGNORECASE,
    )
    return plain_text(match.group(1)) if match else fallback


def _location_from_context(text: str, fallback: str) -> str:
    for value in (
        "Lahore, Pakistan",
        "Islamabad, Pakistan",
        "Karachi, Pakistan",
        "Rawalpindi, Pakistan",
        "Pakistan",
        "Remote Worldwide",
    ):
        if value.casefold() in text.casefold():
            return value
    return fallback


def _posted_from_context(text: str) -> str:
    match = re.search(
        r"(?:posted|published)(?:\s+on)?\s*[:\-]?\s*"
        r"([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}|"
        r"\d{4}-\d{2}-\d{2})",
        text,
        flags=re.IGNORECASE,
    )
    return datetime_value(match.group(1)) if match else ""


def _match(pattern: str, text: str) -> str:
    match = re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL)
    return match.group(1).strip() if match else ""


def _clean_link(value: str) -> str:
    return value.replace("&amp;", "&").split("?", maxsplit=1)[0]


def _unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(value for value in values if value.strip()))


def _fallback_task() -> SearchTask:
    return SearchTask(
        id="private-job-normalizer",
        title="Private technology jobs",
        task_type=TaskType.JOB,
        keywords=[
            "Python",
            "Machine Learning",
            "Computer Vision",
            "Flutter",
            "Dart",
        ],
        location="Worldwide",
        level="Fresher",
        filters=[],
        daily_limit=10,
        is_active=True,
        created_at="",
    )
