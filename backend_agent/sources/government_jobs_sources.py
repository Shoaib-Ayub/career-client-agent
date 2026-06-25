from __future__ import annotations

import re
from io import BytesIO
from datetime import date
from queue import Empty, Queue
from threading import Semaphore, Thread
from textwrap import dedent
from urllib.parse import urljoin, urlparse

from ..models import SearchTask
from .base_source import (
    BaseSource,
    SourceOpportunity,
    date_value,
    extract_deadline,
    infer_skills,
    parse_datetime,
    plain_text,
)

PUNJAB_JOBS_URL = "https://jobs.punjab.gov.pk/new_recruit/jobs"
NATIONAL_JOBS_URL = "https://www.njp.gov.pk/jobs/live"
PPSC_JOBS_URL = "https://www.ppsc.gop.pk/Jobs.aspx"
FPSC_JOBS_URL = "https://www.fpsc.gov.pk/Jobs?section=GR"
FPSC_JOBS_API_URL = "https://www.fpsc.gov.pk/api/jobs"
PPSC_APPLY_URL = "https://www.ppsc.gop.pk/Jobs.aspx"
FPSC_APPLY_URL = "https://online.fpsc.gov.pk/"
MAX_COMMISSION_PDFS = 3
MAX_PDF_BYTES = 8 * 1024 * 1024
MAX_PDF_PAGES = 80
MAX_GENERIC_DETAIL_LINKS = 20

EDUCATION_TERMS = (
    "bs ",
    "bs(",
    "bs hons",
    "bs honours",
    "b.s.",
    "bachelor",
    "bachelor's degree",
    "bachelors degree",
    "bachelor degree",
    "graduation",
    "graduate degree",
    "16 years education",
    "16 years of education",
    "bsc",
    "b.sc",
    "b.a.",
    "ba ",
    "b.com",
    "bcom",
    "bba",
    "equivalent qualification",
    "or equivalent",
)

DEGREE_EVIDENCE_TERMS = EDUCATION_TERMS

LOW_EDUCATION_ONLY = (
    "matric only",
    "matriculation only",
    "intermediate only",
    "fa/fsc only",
    "middle pass",
    "primary pass",
    "literate",
)

OUTSIDE_PUNJAB_ONLY = (
    "sindh domicile only",
    "domicile of sindh only",
    "balochistan domicile only",
    "domicile of balochistan only",
    "khyber pakhtunkhwa domicile only",
    "kpk domicile only",
    "gilgit baltistan domicile only",
    "azad jammu and kashmir domicile only",
    "ajk domicile only",
)

PUNJAB_ELIGIBLE_TERMS = (
    "punjab domicile",
    "domicile punjab",
    "punjab, pakistan",
    "all pakistan",
    "all provinces",
    "any province",
    "anywhere in pakistan",
    "pakistan nationals",
    "citizens of pakistan",
    "pakistani citizens",
    "pakistan",
    "anywhere",
    "open merit",
    "merit quota",
    "merit based",
    "federal",
)

PRIVATE_TERMS = (
    "private limited",
    "pvt ltd",
    "pvt. ltd",
    "private company",
    "private sector",
    "non-government",
    "nongovernment",
)

TRUSTED_GOVERNMENT_SOURCES = {
    "Punjab Jobs Portal",
    "National Job Portal Pakistan",
    "PPSC",
    "FPSC",
    "FIA Careers",
    "Punjab Police",
    "ASF Careers",
    "National Highways & Motorway Police",
    "Pakistan Rangers",
    "Frontier Corps",
    "Pakistan Army",
    "Pakistan Navy",
    "Pakistan Air Force",
    "Pakistan Coast Guards",
    "NAB Careers",
    "NADRA Careers",
    "FBR Careers",
    "WAPDA Careers",
    "Pakistan Railways",
    "Punjab Health Department",
    "Punjab Education Department",
    "Higher Education Commission",
    "University of the Punjab",
    "Government College University Lahore",
    "UET Lahore",
    "PITB Careers",
    "NTS",
    "OTS",
    "PTS",
    "STS",
    "Pakistan Jobs Bank",
    "Ministry of IT & Telecom",
}

JOB_LINK_TERMS = (
    "job",
    "jobs",
    "career",
    "careers",
    "vacancy",
    "vacancies",
    "recruitment",
    "advertisement",
    "apply",
    "post",
)

NON_JOB_NAVIGATION_TITLES = {
    "menu",
    "home",
    "jobs",
    "jobs/ vacancy announcements",
    "jobs / vacancy announcements",
    "information desk",
    "syllabus",
    "job description",
    "eligibility / scrutiny criteria",
    "ppsc regulations / ordinance / pd manual",
    "summary of disqualified / debarred candidates",
    "jobs archive",
    "highlights archive",
    "written results archive",
    "final recommendations archive",
    "final recommendations complete merit lists archive",
    "step by step procedure",
    "view more jobs by publication date",
    "search more jobs by keywords",
}


class PunjabJobsPortalSource(BaseSource):
    def __init__(self) -> None:
        super().__init__(
            "Punjab Jobs Portal",
            timeout_seconds=15,
            request_attempts=2,
        )

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        html = self.fetch_text(PUNJAB_JOBS_URL)
        rows = re.findall(r"<tr\b[^>]*>(.*?)</tr>", html, re.I | re.S)
        results: list[SourceOpportunity] = []
        candidates: list[SourceOpportunity] = []
        for row in rows:
            link_match = re.search(
                r"<a\b[^>]*href=[\"']([^\"']+/job_detail/[^\"']+)[\"']"
                r"[^>]*>(.*?)</a>",
                row,
                flags=re.IGNORECASE | re.DOTALL,
            )
            if not link_match:
                continue

            title = plain_text(link_match.group(2))
            department = _labeled_cell(row, "Department")
            project = _labeled_cell(row, "Project")
            province = _labeled_cell(row, "Province") or "Punjab, Pakistan"
            deadline = _last_date(row)
            result = SourceOpportunity(
                title=title,
                organization=department or "Government of Punjab",
                location=province,
                source_link=urljoin(PUNJAB_JOBS_URL, link_match.group(1)),
                deadline=deadline,
                required_skills=_government_skills(title, task),
                source_name=self.source_name,
                description=" ".join(
                    value for value in (plain_text(row), project) if value
                ),
                fresher_friendly=_fresher_friendly(title),
                required_education=_labeled_cell(
                    row,
                    "Qualification",
                ),
                eligibility_domicile=(
                    _labeled_cell(row, "Domicile")
                    or "Punjab domicile"
                ),
                punjab_candidate_eligible="Yes",
                post_count=_extract_post_count(plain_text(row)),
                job_scale=_extract_job_scale(
                    f"{title} {plain_text(row)}"
                ),
            )
            if is_expired_government_result(result):
                continue
            candidates.append(result)

        for result in _hydrate_candidates(
            self,
            candidates,
            _parse_punjab_detail,
            time_budget_seconds=60,
        ):
            finalize_government_result(result)
            results.append(result)
        if results:
            return results
        return self._fallback(
            task,
            "No structured Punjab vacancy details could be validated.",
        )

    def _fallback(
        self,
        task: SearchTask,
        reason: str,
    ) -> list[SourceOpportunity]:
        self.mark_degraded(reason, fallback_used=True)
        return [_source_review_link(
            task,
            self.source_name,
            PUNJAB_JOBS_URL,
            "Punjab Jobs Portal — review current vacancies",
            "Government of Punjab",
            "Punjab, Pakistan",
        )]


class NationalJobPortalSource(BaseSource):
    def __init__(self) -> None:
        super().__init__(
            "National Job Portal Pakistan",
            timeout_seconds=10,
            request_attempts=2,
        )

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        html = self.fetch_text(NATIONAL_JOBS_URL)
        cards = _njp_cards(html)
        results: list[SourceOpportunity] = []
        candidates: list[SourceOpportunity] = []
        for card in cards:
            link_match = re.search(
                r"<a\b[^>]*href=[\"']((?:https://www\.njp\.gov\.pk)?"
                r"/jobs/\d+)[\"'][^>]*>(.*?)</a>",
                card,
                flags=re.IGNORECASE | re.DOTALL,
            )
            organization_match = re.search(
                r"(?:</svg>\s*)?by\s+(.*?)</p>",
                card,
                flags=re.IGNORECASE | re.DOTALL,
            )
            deadline_match = re.search(
                r"(?:Available Till|Expired On)\s+"
                r"([A-Za-z]{3,9}\s+\d{1,2},\s+\d{4})",
                card,
                flags=re.IGNORECASE,
            )
            if not link_match or not organization_match:
                continue
            title = plain_text(link_match.group(2))
            result = SourceOpportunity(
                title=title,
                organization=plain_text(organization_match.group(1)),
                location="Pakistan",
                source_link=urljoin(NATIONAL_JOBS_URL, link_match.group(1)),
                deadline=(
                    date_value(deadline_match.group(1))
                    if deadline_match
                    else ""
                ),
                required_skills=_government_skills(title, task),
                source_name=self.source_name,
                description=plain_text(card),
                fresher_friendly=_fresher_friendly(title),
                eligibility_domicile="All Pakistan",
                punjab_candidate_eligible="Yes",
                post_count=_extract_post_count(plain_text(card)),
                job_scale=_extract_job_scale(plain_text(card)),
            )
            if is_expired_government_result(result):
                continue
            candidates.append(result)

        for result in _hydrate_candidates(
            self,
            candidates,
            _parse_njp_detail,
        ):
            finalize_government_result(result)
            results.append(result)
        if results:
            return results
        self.mark_degraded(
            "No structured NJP job cards/details could be validated.",
            fallback_used=True,
        )
        return [_source_review_link(
            task,
            self.source_name,
            NATIONAL_JOBS_URL,
            "National Job Portal — review current vacancies",
            "Government of Pakistan",
            "Pakistan",
        )]


class PpscJobsSource(BaseSource):
    def __init__(self) -> None:
        super().__init__("PPSC", timeout_seconds=12, request_attempts=2)

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        html = self.fetch_text(PPSC_JOBS_URL)
        results = _parse_commission_rows(
            html=html,
            task=task,
            source_name=self.source_name,
            listing_url=PPSC_JOBS_URL,
            default_department="Punjab Public Service Commission",
            default_location="Punjab, Pakistan",
            default_domicile="Punjab domicile",
        )
        pdf_links = _discover_official_pdf_links(
            html,
            PPSC_JOBS_URL,
            allowed_domain="ppsc.gop.pk",
        )
        pdf_results, pdf_failures = _collect_commission_pdfs(
            source=self,
            task=task,
            pdf_links=pdf_links,
            source_name=self.source_name,
            default_department="Punjab Public Service Commission",
            default_location="Punjab, Pakistan",
            default_domicile="Punjab domicile",
            apply_url=PPSC_APPLY_URL,
        )
        results = government_deduplicate([*results, *pdf_results])
        if results:
            if pdf_failures:
                self.mark_degraded(
                    "; ".join(pdf_failures),
                    fallback_used=False,
                )
            return results
        reason = (
            "; ".join(pdf_failures)
            if pdf_failures
            else "PPSC exposed no individually verifiable bachelor-level vacancy."
        )
        self.mark_degraded(
            reason,
            fallback_used=True,
        )
        return [_source_review_link(
            task,
            self.source_name,
            PPSC_JOBS_URL,
            "PPSC — review current advertisements",
            "Punjab Public Service Commission",
            "Punjab, Pakistan",
        )]


class FpscJobsSource(BaseSource):
    def __init__(self) -> None:
        super().__init__("FPSC", timeout_seconds=10, request_attempts=2)

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        html = self.fetch_text(FPSC_JOBS_URL)
        results = _parse_commission_rows(
            html=html,
            task=task,
            source_name=self.source_name,
            listing_url=FPSC_JOBS_URL,
            default_department="Federal Public Service Commission",
            default_location="Pakistan",
            default_domicile="Open merit / All Pakistan",
        )
        pdf_links: list[tuple[str, str, str]] = []
        try:
            payload = self.fetch_json(
                f"{FPSC_JOBS_API_URL}?includeExpired=true"
            )
            pdf_links.extend(_fpsc_api_pdf_links(payload))
        except Exception:
            pass
        pdf_links.extend(
            _discover_official_pdf_links(
                html,
                FPSC_JOBS_URL,
                allowed_domain="fpsc.gov.pk",
            )
        )
        pdf_results, pdf_failures = _collect_commission_pdfs(
            source=self,
            task=task,
            pdf_links=_unique_pdf_links(pdf_links),
            source_name=self.source_name,
            default_department="Federal Public Service Commission",
            default_location="Pakistan",
            default_domicile="Open merit / All Pakistan",
            apply_url=FPSC_APPLY_URL,
        )
        results = government_deduplicate([*results, *pdf_results])
        if results:
            if pdf_failures:
                self.mark_degraded(
                    "; ".join(pdf_failures),
                    fallback_used=False,
                )
            return results
        reason = (
            "; ".join(pdf_failures)
            if pdf_failures
            else "FPSC exposed no individually verifiable bachelor-level vacancy."
        )
        self.mark_degraded(
            reason,
            fallback_used=True,
        )
        return [_source_review_link(
            task,
            self.source_name,
            FPSC_JOBS_URL,
            "FPSC — review current consolidated advertisements",
            "Federal Public Service Commission",
            "Pakistan",
        )]


class PublicGovernmentListingSource(BaseSource):
    """Collects public job/detail links without login or browser automation."""

    def __init__(
        self,
        source_name: str,
        listing_url: str,
        default_department: str,
        default_location: str = "Pakistan",
    ) -> None:
        super().__init__(
            source_name,
            timeout_seconds=4,
            request_attempts=1,
        )
        self.listing_url = listing_url
        self.default_department = default_department
        self.default_location = default_location

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        html = self.fetch_text(self.listing_url)
        candidates: list[SourceOpportunity] = []
        for match in re.finditer(
            r"<a\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
            html,
            flags=re.IGNORECASE | re.DOTALL,
        ):
            href = match.group(1).strip()
            title = plain_text(match.group(2))
            context = plain_text(
                html[max(0, match.start() - 300) : match.end() + 300]
            )
            candidate_text = f"{title} {context}"
            if not href or not _looks_like_job_link(title, href, candidate_text):
                continue
            apply_link = _stable_url(urljoin(self.listing_url, href))
            if not apply_link.startswith(("http://", "https://")):
                continue
            qualification = extract_qualification(candidate_text)
            result = SourceOpportunity(
                title=title or _target_title_from_text(candidate_text),
                organization=(
                    _department_from_title(title)
                    if self.source_name == "Pakistan Jobs Bank"
                    else _department_from_text(
                        candidate_text,
                        self.default_department,
                    )
                ),
                location=_location_from_text(
                    candidate_text,
                    self.default_location,
                ),
                source_link=apply_link,
                posted_date=_extract_posted_date(candidate_text),
                deadline=extract_deadline(candidate_text),
                required_skills=_government_skills(candidate_text, task),
                source_name=self.source_name,
                description=candidate_text,
                fresher_friendly=_fresher_friendly(candidate_text),
                required_education=qualification,
                eligibility_domicile=extract_domicile(candidate_text),
                age_limit=extract_age_limit(candidate_text),
                advertisement_link=(
                    apply_link if ".pdf" in apply_link.casefold() else ""
                ),
            )
            candidates.append(result)

        results: list[SourceOpportunity] = []
        hydrated = _hydrate_candidates(
            self,
            candidates[:MAX_GENERIC_DETAIL_LINKS],
            _parse_generic_government_detail,
            time_budget_seconds=24,
        )
        for result in [
            *hydrated,
            *candidates[MAX_GENERIC_DETAIL_LINKS:],
        ]:
            finalize_government_result(result)
            if is_eligible_government_result(result):
                results.append(result)
        return government_deduplicate(results)


def government_jobs_sources() -> list[BaseSource]:
    return [
        PunjabJobsPortalSource(),
        NationalJobPortalSource(),
        PpscJobsSource(),
        FpscJobsSource(),
        PublicGovernmentListingSource(
            "FIA Careers",
            "https://fia.gov.pk/careers",
            "Federal Investigation Agency",
        ),
        PublicGovernmentListingSource(
            "Punjab Police",
            "https://punjabpolice.gov.pk/police-jobs",
            "Punjab Police",
            "Punjab, Pakistan",
        ),
        PublicGovernmentListingSource(
            "ASF Careers",
            "https://joinasf.gov.pk/",
            "Airport Security Force",
        ),
        PublicGovernmentListingSource(
            "National Highways & Motorway Police",
            "https://nhmp.gov.pk/careers",
            "National Highways and Motorway Police",
        ),
        PublicGovernmentListingSource(
            "Pakistan Rangers",
            "https://pakistanrangerspunjab.com/",
            "Pakistan Rangers Punjab",
            "Punjab, Pakistan",
        ),
        PublicGovernmentListingSource(
            "Frontier Corps",
            "https://joinfcblnsouth.gov.pk/",
            "Frontier Corps",
        ),
        PublicGovernmentListingSource(
            "Pakistan Army",
            "https://www.joinpakarmy.gov.pk/",
            "Pakistan Army",
        ),
        PublicGovernmentListingSource(
            "Pakistan Navy",
            "https://www.joinpaknavy.gov.pk/",
            "Pakistan Navy",
        ),
        PublicGovernmentListingSource(
            "Pakistan Air Force",
            "https://joinpaf.gov.pk/",
            "Pakistan Air Force",
        ),
        PublicGovernmentListingSource(
            "Pakistan Coast Guards",
            "https://www.pakistancoastguards.gov.pk/",
            "Pakistan Coast Guards",
        ),
        PublicGovernmentListingSource(
            "NAB Careers",
            "https://nab.gov.pk/jobs.asp",
            "National Accountability Bureau",
        ),
        PublicGovernmentListingSource(
            "PITB Careers",
            "https://pitb.gov.pk/jobs",
            "Punjab Information Technology Board",
            "Punjab, Pakistan",
        ),
        PublicGovernmentListingSource(
            "NADRA Careers",
            "https://careers.nadra.gov.pk/",
            "National Database and Registration Authority",
        ),
        PublicGovernmentListingSource(
            "FBR Careers",
            "https://www.fbr.gov.pk/jobs-vacancy-announcements/142246",
            "Federal Board of Revenue",
        ),
        PublicGovernmentListingSource(
            "WAPDA Careers",
            "https://www.wapda.gov.pk/careers",
            "Water and Power Development Authority",
        ),
        PublicGovernmentListingSource(
            "Pakistan Railways",
            "https://www.railways.gov.pk/Jobs",
            "Pakistan Railways",
        ),
        PublicGovernmentListingSource(
            "Punjab Health Department",
            "https://pshealthpunjab.gov.pk/Home/Jobs",
            "Punjab Health Department",
            "Punjab, Pakistan",
        ),
        PublicGovernmentListingSource(
            "Punjab Education Department",
            "https://schools.punjab.gov.pk/jobs",
            "Punjab School Education Department",
            "Punjab, Pakistan",
        ),
        PublicGovernmentListingSource(
            "Higher Education Commission",
            "https://careers.hec.gov.pk/",
            "Higher Education Commission / Public Universities",
        ),
        PublicGovernmentListingSource(
            "University of the Punjab",
            "https://pu.edu.pk/careers/",
            "University of the Punjab",
            "Punjab, Pakistan",
        ),
        PublicGovernmentListingSource(
            "Government College University Lahore",
            "https://gcu.edu.pk/jobs.php",
            "Government College University Lahore",
            "Punjab, Pakistan",
        ),
        PublicGovernmentListingSource(
            "UET Lahore",
            "https://jobs.uet.edu.pk/",
            "University of Engineering and Technology Lahore",
            "Punjab, Pakistan",
        ),
        PublicGovernmentListingSource(
            "NTS",
            "https://www.nts.org.pk/new/projectsnew.php",
            "National Testing Service project",
        ),
        PublicGovernmentListingSource(
            "OTS",
            "https://ots.org.pk/projects.php",
            "Open Testing Service project",
        ),
        PublicGovernmentListingSource(
            "PTS",
            "https://www.pts.org.pk/Projects/",
            "Pakistan Testing Service project",
        ),
        PublicGovernmentListingSource(
            "STS",
            "https://apply.sts.net.pk/",
            "SIBA Testing Services project",
        ),
        PublicGovernmentListingSource(
            "Pakistan Jobs Bank",
            "https://www.pakistanjobsbank.com/Ind/Government/",
            "Government department",
        ),
        PublicGovernmentListingSource(
            "Ministry of IT & Telecom",
            "https://moitt.gov.pk/Jobs",
            "Ministry of Information Technology and Telecommunication",
        ),
    ]


def finalize_government_result(item: SourceOpportunity) -> None:
    if item.is_source_review_link:
        item.match_reason = (
            "Source review link only. Open the official board and verify an "
            "individual vacancy before applying."
        )
        return
    evidence = " ".join(
        [
            item.title,
            item.organization,
            item.location,
            item.description,
            item.required_education,
            item.eligibility_domicile,
        ]
    )
    if not item.required_education:
        item.required_education = extract_qualification(evidence)
    if not item.eligibility_domicile:
        item.eligibility_domicile = extract_domicile(evidence)
    if not item.age_limit:
        item.age_limit = extract_age_limit(evidence)
    # Do not infer education from the complete page: listing pages commonly
    # contain unrelated vacancies, menus, and recommended jobs.
    item.bs_software_engineering_eligible = bachelor_qualification_eligibility(
        item.required_education
    )
    domicile_evidence = item.eligibility_domicile
    if not domicile_evidence and item.source_name in {
        "Punjab Jobs Portal",
        "PPSC",
    }:
        domicile_evidence = "Punjab domicile"
    elif not domicile_evidence and item.source_name in {
        "National Job Portal Pakistan",
        "FPSC",
    }:
        domicile_evidence = "All Pakistan"
    item.punjab_candidate_eligible = punjab_candidate_eligibility(
        domicile_evidence
    )
    item.force_category = force_category(evidence)
    reasons = []
    if item.bs_software_engineering_eligible == "Yes":
        reasons.append(
            "Qualification accepts a BS, bachelor's degree, graduation, "
            "16 years education, or an equivalent bachelor-level credential."
        )
    if item.punjab_candidate_eligible == "Yes":
        reasons.append(
            "Punjab residents can apply through Punjab domicile, open merit, "
            "federal, or all-Pakistan eligibility."
        )
    if is_government_result(item):
        reasons.append("The vacancy is published by a government/public source.")
    if item.deadline and not is_expired_government_result(item):
        reasons.append("The application deadline is still open.")
    item.match_reason = " ".join(reasons)


def is_eligible_government_result(item: SourceOpportunity) -> bool:
    if item.is_source_review_link:
        return False
    finalize_government_result(item)
    evidence = " ".join(
        [
            item.title,
            item.organization,
            item.location,
            item.source_name,
            item.description,
            item.required_education,
            item.eligibility_domicile,
        ]
    ).casefold()
    if not is_government_result(item):
        return False
    if any(term in evidence for term in OUTSIDE_PUNJAB_ONLY):
        return False
    if any(term in evidence for term in LOW_EDUCATION_ONLY):
        return False
    if is_expired_government_result(item):
        return False
    return (
        item.bs_software_engineering_eligible == "Yes"
        and item.punjab_candidate_eligible == "Yes"
        and bool(item.required_education)
        and bool(item.source_link.startswith(("http://", "https://")))
    )


def government_deduplicate(
    results: list[SourceOpportunity],
) -> list[SourceOpportunity]:
    ordered_results = sorted(results, key=lambda item: item.is_cached)
    unique: list[SourceOpportunity] = []
    seen_urls: set[str] = set()
    seen_advertisements: set[tuple[str, str, str]] = set()
    seen_identity: set[tuple[str, str, str]] = set()
    for item in ordered_results:
        normalized_url = _normalize_government_url(item.source_link)
        advertisement = re.sub(
            r"\s+",
            "",
            item.advertisement_number.casefold(),
        )
        source = item.source_name.casefold().strip()
        identity = (
            _normalize_text(item.title),
            _normalize_text(item.organization),
            item.deadline,
        )
        if normalized_url and normalized_url in seen_urls:
            continue
        advertisement_identity = (
            source,
            advertisement,
            _normalize_text(item.title),
        )
        if advertisement and advertisement_identity in seen_advertisements:
            continue
        if all(identity) and identity in seen_identity:
            continue
        if normalized_url:
            seen_urls.add(normalized_url)
        if advertisement:
            seen_advertisements.add(advertisement_identity)
        if all(identity):
            seen_identity.add(identity)
        unique.append(item)
    return unique


def government_source_diversity(
    results: list[SourceOpportunity],
) -> dict[str, object]:
    by_source: dict[str, int] = {}
    by_department: dict[str, int] = {}
    it_development_count = 0
    for item in results:
        source = item.source_name or "Unknown"
        department = item.organization or "Unknown"
        by_source[source] = by_source.get(source, 0) + 1
        by_department[department] = by_department.get(department, 0) + 1
        if _is_it_development_title(item.title):
            it_development_count += 1
    return {
        "total_results": len(results),
        "source_count": len(by_source),
        "department_count": len(by_department),
        "results_by_source": dict(sorted(by_source.items())),
        "results_by_department": dict(sorted(by_department.items())),
        "it_development_count": it_development_count,
        "non_it_count": len(results) - it_development_count,
    }


def has_bs_or_equivalent_requirement(item: SourceOpportunity) -> bool:
    finalize_government_result(item)
    return item.bs_software_engineering_eligible == "Yes" and bool(
        item.required_education
    )


def is_target_title(value: str) -> bool:
    return bool(plain_text(value))


def extract_qualification(value: str) -> str:
    text = plain_text(value)
    focused_patterns = (
        r"(?:education|qualification)\s*[:\-]?\s*(.{0,650}?)(?="
        r"\b(?:experience|gender|age|last date|job description)\b|$)",
        r"(?:degree level|16 years of education)\s*(.{0,650}?)(?="
        r"\b(?:experience|gender|age|last date|job description)\b|$)",
    )
    for pattern in focused_patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match and _contains_bachelor_qualification(
            match.group(0).casefold()
        ):
            return plain_text(match.group(0))[:700]
    sentences = re.split(r"(?<=[.;])\s+|\s{2,}", text)
    matches = [
        sentence
        for sentence in sentences
        if len(sentence) <= 700
        and _contains_bachelor_qualification(sentence.casefold())
    ]
    return " ".join(matches)[:700]


def extract_domicile(value: str) -> str:
    text = plain_text(value)
    match = re.search(
        r"(?:domicile|quota|eligibility)[^.;]{0,260}",
        text,
        flags=re.IGNORECASE,
    )
    return plain_text(match.group(0))[:300] if match else ""


def extract_age_limit(value: str) -> str:
    text = plain_text(value)
    match = re.search(
        r"(?:age(?:\s+limit)?|maximum age|minimum age)\s*[:\-]?\s*"
        r"(\d{2}(?:\s*(?:to|-)\s*\d{2})?(?:\s*years?)?)",
        text,
        flags=re.IGNORECASE,
    )
    return plain_text(match.group(1)) if match else ""


def bs_software_eligibility(value: str) -> str:
    return bachelor_qualification_eligibility(value)


def bachelor_qualification_eligibility(value: str) -> str:
    normalized = value.casefold()
    if any(term in normalized for term in LOW_EDUCATION_ONLY):
        return "No"
    if _contains_bachelor_qualification(normalized):
        return "Yes"
    return "Unknown"


def punjab_candidate_eligibility(value: str) -> str:
    normalized = value.casefold()
    if any(term in normalized for term in OUTSIDE_PUNJAB_ONLY):
        return "No"
    if "punjab" in normalized or any(
        term in normalized for term in PUNJAB_ELIGIBLE_TERMS
    ):
        return "Yes"
    return "Unknown"


def is_government_result(item: SourceOpportunity) -> bool:
    evidence = " ".join(
        [
            item.title,
            item.organization,
            item.source_name,
            item.description,
        ]
    ).casefold()
    if any(term in evidence for term in PRIVATE_TERMS):
        return False
    if item.source_name in TRUSTED_GOVERNMENT_SOURCES:
        return True
    return any(
        term in evidence
        for term in (
            "government",
            "ministry",
            "department",
            "commission",
            "authority",
            "police",
            "army",
            "navy",
            "air force",
            "rangers",
            "public university",
            "federal",
            "provincial",
        )
    )


def is_expired_government_result(item: SourceOpportunity) -> bool:
    if "expired on" in item.description.casefold():
        return True
    deadline = parse_datetime(item.deadline)
    return bool(deadline and deadline.date() < date.today())


def force_category(value: str) -> str:
    normalized = value.casefold()
    categories = (
        ("Pakistan Army", ("army",)),
        ("Pakistan Navy", ("navy",)),
        ("Pakistan Air Force", ("air force", "paf")),
        ("Pakistan Rangers", ("rangers",)),
        ("Frontier Corps", ("frontier corps",)),
        ("Airport Security Force", ("airport security force", "asf")),
        ("Police", ("police", "motorway police", "nhmp")),
        ("Coast Guards", ("coast guard",)),
        ("Federal Investigation", ("fia", "federal investigation")),
    )
    for category, terms in categories:
        if any(term in normalized for term in terms):
            return category
    return ""


def _source_review_link(
    task: SearchTask,
    source_name: str,
    url: str,
    title: str,
    organization: str,
    location: str,
) -> SourceOpportunity:
    return SourceOpportunity(
        title=title,
        organization=organization,
        location=location,
        source_link=url,
        required_skills=_government_skills(title, task),
        source_name=source_name,
        description=(
            "Official source board. Structured individual vacancy parsing "
            "was unavailable; manually review current advertisements."
        ),
        is_source_review_link=True,
    )


def _njp_cards(html: str) -> list[str]:
    comment_cards = html.split("<!-- Job Card -->")[1:]
    if comment_cards:
        return comment_cards
    starts = list(
        re.finditer(
            r"<a\b[^>]*href=[\"'](?:https://www\.njp\.gov\.pk)?"
            r"/jobs/\d+[\"']",
            html,
            flags=re.IGNORECASE,
        )
    )
    return [
        html[match.start() : starts[index + 1].start()]
        if index + 1 < len(starts)
        else html[match.start() : match.start() + 2500]
        for index, match in enumerate(starts)
    ]


def _labeled_cell(html: str, label: str) -> str:
    match = re.search(
        rf"<td\b[^>]*data-label=[\"']{re.escape(label)}[\"'][^>]*>"
        r"(.*?)</td>",
        html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    return plain_text(match.group(1)) if match else ""


def _last_date(value: str) -> str:
    dates = re.findall(
        r"\b(\d{1,2}[-/\s](?:[A-Za-z]{3,9}|\d{1,2})[-/\s]\d{4})\b",
        plain_text(value),
        flags=re.IGNORECASE,
    )
    return date_value(dates[-1]) if dates else ""


def _extract_post_count(value: str) -> int | None:
    match = re.search(
        r"\b(?:total\s+positions?|no\.?\s+of\s+posts?|"
        r"vacanc(?:y|ies)|posts?)\s*[:\-]?\s*(\d+)"
        r"|(?<![-/])\b(\d+)\s+(?:vacanc(?:y|ies)|posts?|positions?)\b",
        plain_text(value),
        flags=re.IGNORECASE,
    )
    if not match:
        return None
    return int(match.group(1) or match.group(2))


def _extract_job_scale(value: str) -> str:
    text = plain_text(value)
    match = re.search(
        r"\b(?:BPS|BS|PPS|SPPS|SPPP|SPS|MP)"
        r"[\s\-:]*(?:\d{1,2}|[IVX]{1,5})\b",
        text,
        flags=re.IGNORECASE,
    )
    if not match:
        match = re.search(
            r"\b(?:Grade|Scale)\s*[:\-]?\s*[A-Z0-9IVX()]+\b",
            text,
            flags=re.IGNORECASE,
        )
    return plain_text(match.group(0)).upper() if match else ""


def _extract_advertisement_number(value: str) -> str:
    text = plain_text(value)
    match = re.search(
        r"\b(?:advertisement|advert|ad)\b\.?\s*"
        r"(?:no\.?|number)?\s*"
        r"[:\-]?\s*([A-Z0-9/-]{3,30})",
        text,
        flags=re.IGNORECASE,
    )
    return plain_text(match.group(1)) if match else ""


def _hydrate_candidates(
    source: BaseSource,
    candidates: list[SourceOpportunity],
    detail_parser: object,
    time_budget_seconds: float = 18,
    max_concurrency: int = 6,
) -> list[SourceOpportunity]:
    if not candidates:
        return []
    output: dict[int, SourceOpportunity] = {}
    queue: Queue[tuple[int, SourceOpportunity]] = Queue()
    detail_slots = Semaphore(max_concurrency)

    def worker(index: int, item: SourceOpportunity) -> None:
        with detail_slots:
            try:
                detail = source.fetch_text(item.source_link)
                parser = detail_parser
                if callable(parser):
                    parser(item, detail)
            except Exception:
                pass
        queue.put((index, item))

    for index, item in enumerate(candidates):
        Thread(
            target=worker,
            args=(index, item),
            name=f"{source.source_name}-detail-{index}",
            daemon=True,
        ).start()

    from time import monotonic

    deadline = monotonic() + time_budget_seconds
    pending = len(candidates)
    while pending and monotonic() < deadline:
        try:
            index, item = queue.get(
                timeout=max(0.01, min(0.2, deadline - monotonic()))
            )
        except Empty:
            continue
        output[index] = item
        pending -= 1
    return [output.get(index, item) for index, item in enumerate(candidates)]


def _parse_njp_detail(item: SourceOpportunity, html: str) -> None:
    text = plain_text(html)
    item.description = text[:12000]
    item.required_education = (
        _section_text(text, "Qualifications", "Experience", 2200)
        or extract_qualification(text)
    )
    item.eligibility_domicile = (
        _label_text(text, "Domicile Quota", 300)
        or item.eligibility_domicile
    )
    item.deadline = (
        date_value(_label_text(text, "Application Deadline", 80))
        or date_value(_label_text(text, "Deadline", 80))
        or item.deadline
    )
    item.posted_date = (
        date_value(_label_text(text, "Posted", 80)) or item.posted_date
    )
    item.age_limit = extract_age_limit(text) or item.age_limit
    item.post_count = _extract_post_count(text) or item.post_count
    item.job_scale = (
        _extract_job_scale(text)
        or _clean_job_scale(_label_text(text, "Grade", 80))
        or item.job_scale
    )


def _parse_punjab_detail(item: SourceOpportunity, html: str) -> None:
    text = plain_text(html)
    item.description = text[:12000]
    item.required_education = (
        _section_text(text, "Qualification and Experience", "Competencies", 1600)
        or _section_text(text, "Degree Level", "Degree Area", 1200)
        or extract_qualification(text)
        or item.required_education
    )
    item.eligibility_domicile = (
        _label_text(text, "Domicile Only", 500)
        or "Punjab domicile"
    )
    item.deadline = (
        date_value(_label_text(text, "Last Date to Apply", 80))
        or item.deadline
    )
    item.posted_date = (
        date_value(_label_text(text, "Job Posted", 80)) or item.posted_date
    )
    item.post_count = _extract_post_count(text) or item.post_count
    item.job_scale = (
        _extract_job_scale(text)
        or _clean_job_scale(_label_text(text, "Level", 80))
        or item.job_scale
    )
    item.advertisement_link = (
        _link_by_text(html, "View Advertisement", item.source_link)
        or item.advertisement_link
    )


def _parse_generic_government_detail(
    item: SourceOpportunity,
    html: str,
) -> None:
    if item.source_link.casefold().endswith(".pdf"):
        return
    text = plain_text(html)
    focused_text = _focused_detail_text(text, item.title)
    item.description = f"{item.description} {focused_text}"[:12000]
    item.required_education = (
        extract_qualification(focused_text) or item.required_education
    )
    item.eligibility_domicile = (
        extract_domicile(focused_text) or item.eligibility_domicile
    )
    item.age_limit = extract_age_limit(focused_text) or item.age_limit
    item.deadline = item.deadline or extract_deadline(focused_text)
    item.posted_date = (
        _extract_posted_date(focused_text) or item.posted_date
    )
    item.post_count = _extract_post_count(focused_text) or item.post_count
    item.job_scale = _extract_job_scale(focused_text) or item.job_scale
    item.advertisement_number = (
        _extract_advertisement_number(focused_text)
        or item.advertisement_number
    )
    item.advertisement_link = (
        _link_by_text(html, "advertisement", item.source_link)
        or item.advertisement_link
    )


def _discover_official_pdf_links(
    html: str,
    base_url: str,
    *,
    allowed_domain: str,
) -> list[tuple[str, str, str]]:
    links: list[tuple[str, str, str]] = []
    for href, label in re.findall(
        r"<a\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
        html,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        url = urljoin(base_url, href)
        title = plain_text(label)
        evidence = f"{title} {url}".casefold()
        if (
            ".pdf" not in urlparse(url).path.casefold()
            or not _is_allowed_official_domain(url, allowed_domain)
            or not any(
                term in evidence
                for term in (
                    "advertisement",
                    "consolidated",
                    "vacancy",
                    "jobs",
                    "case",
                )
            )
            or any(
                term in evidence
                for term in (
                    "procedure",
                    "guideline",
                    "manual",
                    "photograph",
                    "fee payment",
                    "instructions",
                    "archive",
                )
            )
        ):
            continue
        links.append(
            (
                url,
                _extract_advertisement_number(evidence),
                "",
            )
        )
    return _unique_pdf_links(links)[:MAX_COMMISSION_PDFS]


def _fpsc_api_pdf_links(
    payload: object,
) -> list[tuple[str, str, str]]:
    if not isinstance(payload, dict):
        return []
    records = payload.get("data")
    if not isinstance(records, list):
        return []
    links: list[tuple[str, str, str]] = []
    for record in records:
        if not isinstance(record, dict):
            continue
        category = str(record.get("category", ""))
        if category.casefold() != "gr":
            continue
        expiry = date_value(record.get("expiryDate"))
        if expiry and parse_datetime(expiry):
            if parse_datetime(expiry).date() < date.today():
                continue
        title = str(record.get("title", ""))
        advertisement = _extract_advertisement_number(title)
        description = str(record.get("description", ""))
        candidates = [
            *re.findall(
                r"href=[\"']([^\"']+\.pdf(?:\?[^\"']*)?)[\"']",
                description,
                flags=re.IGNORECASE,
            ),
        ]
        pdfs = record.get("pdfs")
        if isinstance(pdfs, list):
            for attachment in pdfs:
                if not isinstance(attachment, dict):
                    continue
                candidate = attachment.get("url") or attachment.get("link")
                if candidate:
                    candidates.append(str(candidate))
        for candidate in candidates:
            url = urljoin("https://www.fpsc.gov.pk/", candidate)
            if not _is_allowed_official_domain(url, "fpsc.gov.pk"):
                continue
            evidence = f"{title} {candidate}".casefold()
            if any(
                term in evidence
                for term in (
                    "guideline",
                    "procedure",
                    "fee payment",
                    "instructions",
                )
            ):
                continue
            links.append((url, advertisement, expiry))
    return _unique_pdf_links(links)[:MAX_COMMISSION_PDFS]


def _unique_pdf_links(
    links: list[tuple[str, str, str]],
) -> list[tuple[str, str, str]]:
    unique: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for url, advertisement, deadline in links:
        normalized = _normalize_government_url(url)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        unique.append((url, advertisement, deadline))
    return unique


def _is_allowed_official_domain(url: str, domain: str) -> bool:
    hostname = (urlparse(url).hostname or "").casefold()
    allowed = domain.casefold()
    return hostname == allowed or hostname.endswith(f".{allowed}")


def _collect_commission_pdfs(
    *,
    source: BaseSource,
    task: SearchTask,
    pdf_links: list[tuple[str, str, str]],
    source_name: str,
    default_department: str,
    default_location: str,
    default_domicile: str,
    apply_url: str,
) -> tuple[list[SourceOpportunity], list[str]]:
    results: list[SourceOpportunity] = []
    failures: list[str] = []
    expected_domain = (
        "ppsc.gop.pk" if source_name == "PPSC" else "fpsc.gov.pk"
    )
    for pdf_url, advertisement, advertised_deadline in pdf_links[
        :MAX_COMMISSION_PDFS
    ]:
        if not _is_allowed_official_domain(pdf_url, expected_domain):
            failures.append(f"Skipped non-official PDF: {pdf_url}")
            continue
        try:
            payload = source.fetch_bytes(
                pdf_url,
                maximum_bytes=MAX_PDF_BYTES,
                accept="application/pdf",
            )
            text = _extract_pdf_text(payload)
            parsed = parse_commission_pdf_text(
                text=text,
                task=task,
                source_name=source_name,
                pdf_url=pdf_url,
                apply_url=apply_url,
                default_department=default_department,
                default_location=default_location,
                default_domicile=default_domicile,
                advertisement_number=advertisement,
                advertised_deadline=advertised_deadline,
            )
            if not parsed:
                failures.append(
                    f"No eligible posts parsed from {pdf_url}"
                )
            results.extend(parsed)
        except Exception as error:
            failures.append(f"PDF failed {pdf_url}: {error}")
    return government_deduplicate(results), failures


def _extract_pdf_text(payload: bytes) -> str:
    if not payload.startswith(b"%PDF"):
        raise ValueError("Malformed or unsupported PDF content.")
    try:
        from pypdf import PdfReader

        reader = PdfReader(BytesIO(payload), strict=False)
        if len(reader.pages) > MAX_PDF_PAGES:
            raise ValueError(
                f"PDF exceeds the {MAX_PDF_PAGES}-page safety limit."
            )
        pages = [
            page.extract_text() or ""
            for page in reader.pages
        ]
    except Exception as error:
        raise ValueError(f"PDF text extraction failed: {error}") from error
    text = "\n".join(pages)
    if not plain_text(text):
        raise ValueError("PDF contains no extractable text.")
    return text


def parse_commission_pdf_text(
    *,
    text: str,
    task: SearchTask,
    source_name: str,
    pdf_url: str,
    apply_url: str,
    default_department: str,
    default_location: str,
    default_domicile: str,
    advertisement_number: str = "",
    advertised_deadline: str = "",
) -> list[SourceOpportunity]:
    normalized = _normalize_pdf_text(text)
    global_advertisement = (
        advertisement_number
        or _extract_advertisement_number(normalized)
    )
    global_deadline = (
        advertised_deadline
        or _extract_pdf_deadline(normalized)
    )
    segments = _split_pdf_posts(normalized)
    results: list[SourceOpportunity] = []
    for segment in segments:
        title = _pdf_post_title(segment)
        qualification = extract_qualification(segment)
        if not title or not qualification:
            continue
        department = (
            _pdf_labeled_value(
                segment,
                ("department", "ministry", "organization"),
                240,
            )
            or _department_from_text(segment, default_department)
        )
        domicile = (
            extract_domicile(segment)
            or _pdf_labeled_value(
                segment,
                ("domicile", "quota"),
                300,
            )
            or default_domicile
        )
        deadline = _extract_pdf_deadline(segment) or global_deadline
        item_advertisement = (
            _extract_advertisement_number(segment)
            or global_advertisement
        )
        item = SourceOpportunity(
            title=title,
            organization=department,
            location=default_location,
            source_link=_commission_apply_url(
                apply_url,
                item_advertisement,
                title,
            ),
            deadline=deadline,
            required_skills=_government_skills(title, task),
            source_name=source_name,
            description=segment[:12000],
            required_education=qualification,
            eligibility_domicile=domicile,
            age_limit=extract_age_limit(segment),
            advertisement_link=pdf_url,
            advertisement_number=item_advertisement,
            post_count=_extract_post_count(segment),
            job_scale=_extract_job_scale(segment),
            force_category=force_category(
                f"{title} {department} {segment}"
            ),
        )
        finalize_government_result(item)
        if is_eligible_government_result(item):
            results.append(item)
    return government_deduplicate(results)


def _normalize_pdf_text(value: str) -> str:
    text = dedent(value).replace("\r", "\n").replace("\u00a0", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _commission_apply_url(
    base_url: str,
    advertisement: str,
    title: str,
) -> str:
    advertisement_key = re.sub(
        r"[^a-z0-9]+",
        "-",
        advertisement.casefold(),
    ).strip("-")
    title_key = re.sub(
        r"[^a-z0-9]+",
        "-",
        title.casefold(),
    ).strip("-")[:60]
    fragment = "-".join(
        value for value in (advertisement_key, title_key) if value
    )
    return f"{base_url.rstrip('/')}#{fragment}" if fragment else base_url


def _split_pdf_posts(text: str) -> list[str]:
    markers = list(
        re.finditer(
            r"(?im)^(?="
            r"(?:case\s+no\.?\s*)?"
            r"(?:f\.\s*\d+[-/]\d+|\d+\s*[.)])"
            r"|post\s+name\s*[:\-]"
            r")",
            text,
        )
    )
    if not markers:
        return [text]
    segments: list[str] = []
    for index, marker in enumerate(markers):
        end = (
            markers[index + 1].start()
            if index + 1 < len(markers)
            else len(text)
        )
        segment = text[marker.start() : end].strip()
        if len(segment) >= 40:
            segments.append(segment)
    return segments or [text]


def _pdf_post_title(segment: str) -> str:
    labeled = _pdf_labeled_value(
        segment,
        ("post name", "name of post", "title"),
        180,
    )
    if labeled:
        return _clean_pdf_title(labeled)
    patterns = (
        r"(?im)^(?:case\s+no\.?\s*)?f\.\s*\d+[-/]\d+"
        r"(?:[-/]\d+)?\s*[-:.)]*\s*"
        r"([A-Z][A-Z0-9 /,&'()\-]{3,180}?)"
        r"(?=\s*\((?:BS|BPS|PPS|SPS|SPPS|MP)[-\s]?\w+|\n)",
        r"(?im)^\d+\s*[.)]\s*"
        r"([A-Z][A-Z0-9 /,&'()\-]{3,180}?)"
        r"(?=\s*\((?:BS|BPS|PPS|SPS|SPPS|MP)[-\s]?\w+|\n)",
    )
    for pattern in patterns:
        match = re.search(pattern, segment)
        if match:
            return _clean_pdf_title(match.group(1))
    return ""


def _clean_pdf_title(value: str) -> str:
    title = plain_text(value)
    title = re.split(
        r"\b(?:department|ministry|qualification|education|domicile|quota)\b",
        title,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    return title.strip(" :-")[:180]


def _pdf_labeled_value(
    text: str,
    labels: tuple[str, ...],
    maximum: int,
) -> str:
    label_pattern = "|".join(re.escape(label) for label in labels)
    match = re.search(
        rf"(?im)^(?:{label_pattern})\s*[:\-]\s*(.{{1,{maximum}}})$",
        text,
    )
    return plain_text(match.group(1))[:maximum] if match else ""


def _extract_pdf_deadline(value: str) -> str:
    text = plain_text(value)
    match = re.search(
        r"(?:closing date|last date(?: to apply)?|application deadline)"
        r"\s*[:\-]?\s*"
        r"(\d{1,2}[-/\s](?:[A-Za-z]{3,9}|\d{1,2})[-/\s]\d{4}|"
        r"[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})",
        text,
        flags=re.IGNORECASE,
    )
    return date_value(match.group(1)) if match else ""


def _parse_commission_rows(
    *,
    html: str,
    task: SearchTask,
    source_name: str,
    listing_url: str,
    default_department: str,
    default_location: str,
    default_domicile: str,
) -> list[SourceOpportunity]:
    results: list[SourceOpportunity] = []
    advertisement_page_number = _extract_advertisement_number(plain_text(html))
    for row in re.findall(r"<tr\b[^>]*>(.*?)</tr>", html, re.I | re.S):
        cells = re.findall(
            r"<t[dh]\b[^>]*>(.*?)</t[dh]>",
            row,
            flags=re.IGNORECASE | re.DOTALL,
        )
        if len(cells) < 2:
            continue
        cell_text = [plain_text(cell) for cell in cells]
        row_text = " ".join(cell_text)
        qualification = (
            _labeled_cell(row, "Qualification")
            or _labeled_cell(row, "Education")
            or extract_qualification(row_text)
        )
        domicile = (
            _labeled_cell(row, "Domicile")
            or _labeled_cell(row, "Quota")
            or default_domicile
        )
        title = (
            _labeled_cell(row, "Post Name")
            or _labeled_cell(row, "Title")
            or _commission_title(cell_text)
        )
        department = (
            _labeled_cell(row, "Department")
            or _commission_department(cell_text, default_department)
        )
        link = _first_individual_link(row, listing_url)
        deadline = (
            date_value(_labeled_cell(row, "Closing Date"))
            or date_value(_labeled_cell(row, "Last Date"))
            or _last_date(row_text)
        )
        advertisement = (
            _labeled_cell(row, "Ad No")
            or _labeled_cell(row, "Advertisement No")
            or _extract_advertisement_number(row_text)
            or advertisement_page_number
        )
        if (
            not title
            or not qualification
            or not link
            or not _looks_like_job_link(title, link, row_text)
        ):
            continue
        item = SourceOpportunity(
            title=title,
            organization=department,
            location=default_location,
            source_link=link,
            deadline=deadline,
            required_skills=_government_skills(title, task),
            source_name=source_name,
            description=row_text,
            required_education=qualification,
            eligibility_domicile=domicile,
            post_count=_extract_post_count(row_text),
            job_scale=(
                _labeled_cell(row, "Scale")
                or _labeled_cell(row, "Grade")
                or _extract_job_scale(row_text)
            ),
            advertisement_number=advertisement,
            advertisement_link=(
                link if ".pdf" in link.casefold() else ""
            ),
        )
        finalize_government_result(item)
        if is_eligible_government_result(item):
            results.append(item)
    return government_deduplicate(results)


def _section_text(
    text: str,
    start_label: str,
    end_label: str,
    maximum: int,
) -> str:
    match = re.search(
        rf"{re.escape(start_label)}\s*[:\-]?\s*(.*?)"
        rf"(?=\s+{re.escape(end_label)}\b|$)",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    return plain_text(match.group(1))[:maximum] if match else ""


def _label_text(text: str, label: str, maximum: int) -> str:
    match = re.search(
        rf"{re.escape(label)}\s*[:\-]?\s*(.{{1,{maximum}}}?)"
        r"(?=\s+(?:[A-Z][A-Za-z /()]{2,30})\s*[:\-]|$)",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    return plain_text(match.group(1))[:maximum] if match else ""


def _link_by_text(html: str, label: str, base_url: str) -> str:
    match = re.search(
        rf"<a\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>"
        rf"[^<]*{re.escape(label)}[^<]*</a>",
        html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    return urljoin(base_url, match.group(1)) if match else ""


def _first_individual_link(row: str, listing_url: str) -> str:
    for href, label in re.findall(
        r"<a\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
        row,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        title = plain_text(label)
        candidate = urljoin(listing_url, href)
        if _looks_like_job_link(title, candidate, plain_text(row)):
            return _stable_url(candidate)
    return ""


def _commission_title(cells: list[str]) -> str:
    for value in cells:
        if (
            3 <= len(value) <= 180
            and not re.fullmatch(r"[\d/.-]+", value)
            and not re.fullmatch(r"\d+[A-Z]\d{4}", value, re.I)
            and not _contains_bachelor_qualification(value)
        ):
            normalized = value.casefold()
            if any(
                word in normalized
                for word in (
                    "assistant",
                    "director",
                    "officer",
                    "manager",
                    "inspector",
                    "lecturer",
                    "auditor",
                    "engineer",
                    "specialist",
                    "accountant",
                )
            ):
                return value
    return ""


def _commission_department(cells: list[str], fallback: str) -> str:
    for value in cells:
        if any(
            term in value.casefold()
            for term in (
                "department",
                "ministry",
                "commission",
                "authority",
                "division",
                "board",
            )
        ):
            return value
    return fallback


def _normalize_text(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.casefold()).strip()


def _is_it_development_title(value: str) -> bool:
    normalized = _normalize_text(value)
    return bool(
        re.search(
            r"\b(?:software|web developer|website developer|mobile "
            r"developer|flutter|information technology|\bit\b|it officer|"
            r"computer|network|cyber|data analyst|data scientist|"
            r"artificial intelligence|machine learning|ai engineer|"
            r"database|programmer|systems? administrator|gis)\b",
            normalized,
        )
    )


def _clean_job_scale(value: str) -> str:
    text = plain_text(value)
    text = re.split(
        r"\b(?:Last Date|Preferred Candidates|Job Posted|Vacancies|"
        r"Application Deadline)\b",
        text,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    return text.strip(" :-")[:50]


def _normalize_government_url(value: str) -> str:
    normalized = _stable_url(value.strip().casefold())
    return normalized.rstrip("/")


def _hydrate_detail(source: BaseSource, result: SourceOpportunity) -> None:
    if result.source_link.casefold().endswith(".pdf"):
        return
    try:
        detail = source.fetch_text(result.source_link)
    except Exception:
        return
    text = plain_text(detail)
    focused_text = _focused_detail_text(text, result.title)
    result.description = f"{result.description} {text}"[:12000]
    result.required_education = (
        extract_qualification(focused_text) or result.required_education
    )
    result.eligibility_domicile = (
        extract_domicile(focused_text) or result.eligibility_domicile
    )
    result.age_limit = extract_age_limit(focused_text) or result.age_limit
    result.deadline = result.deadline or extract_deadline(focused_text)
    posted = re.search(
        r"(?:job\s+posted|posted|published)(?:\s+on)?\s*[:\-]?\s*"
        r"(\d{1,2}[-\s][A-Za-z0-9]{1,9}[-\s]\d{4}|"
        r"[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})",
        text,
        flags=re.IGNORECASE,
    )
    if posted:
        result.posted_date = date_value(posted.group(1))
    pdf = re.search(
        r"<a\b[^>]*href=[\"']([^\"']+\.pdf(?:\?[^\"']*)?)[\"'][^>]*>"
        r"[^<]*(?:advertisement|job ad|vacancy notice)[^<]*</a>",
        detail,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if pdf:
        result.advertisement_link = urljoin(result.source_link, pdf.group(1))
    apply_link = re.search(
        r"<a\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>"
        r"[^<]*(?:apply|online application)[^<]*</a>",
        detail,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if apply_link:
        candidate = apply_link.group(1).strip()
        if not candidate.casefold().startswith(("javascript:", "#")):
            result.source_link = _stable_url(
                urljoin(result.source_link, candidate)
            )


def _government_skills(title: str, task: SearchTask) -> list[str]:
    skills = infer_skills(title, task)
    normalized = title.casefold()
    role_labels: list[str] = []
    if "software" in normalized:
        role_labels.append("Software Engineer")
    if "administr" in normalized:
        role_labels.append("Administration")
    if "finance" in normalized or "account" in normalized:
        role_labels.append("Finance")
    if "research" in normalized:
        role_labels.append("Research")
    title_words = [
        word.title()
        for word in re.findall(r"[A-Za-z]{3,}", plain_text(title))
        if word.casefold()
        not in {"government", "jobs", "job", "pakistan", "punjab", "apply"}
    ]
    return list(dict.fromkeys([*skills, *role_labels, *title_words]))[:8]


def _fresher_friendly(title: str) -> bool:
    normalized = title.casefold()
    return any(
        value in normalized
        for value in (
            "junior",
            "assistant",
            "graduate",
            "trainee",
            "intern",
            "officer",
            "computer operator",
        )
    )


def _target_title_from_text(value: str) -> str:
    text = plain_text(value)
    match = re.search(
        r"(?:post|position|vacancy|job title)\s*[:\-]\s*([^.;|]{3,120})",
        text,
        flags=re.IGNORECASE,
    )
    return plain_text(match.group(1)) if match else "Government Opportunity"


def _department_from_text(value: str, fallback: str) -> str:
    match = re.search(
        r"((?:ministry|department|authority|commission|board|corporation|"
        r"company|organization)[^.;|]{0,120})",
        value,
        flags=re.IGNORECASE,
    )
    return plain_text(match.group(1)) if match else fallback


def _department_from_title(value: str) -> str:
    department = re.split(r"\s+Jobs?\b", value, maxsplit=1, flags=re.IGNORECASE)[
        0
    ]
    department = re.sub(
        r"\s+(?:Islamabad|Lahore|Rawalpindi|Karachi|Multan|Punjab|Pakistan)$",
        "",
        department,
        flags=re.IGNORECASE,
    )
    return plain_text(department) or "Government department"


def _location_from_text(value: str, fallback: str) -> str:
    for location in (
        "Lahore",
        "Islamabad",
        "Rawalpindi",
        "Multan",
        "Faisalabad",
        "Gujranwala",
        "Punjab",
        "Pakistan",
    ):
        if location.casefold() in value.casefold():
            return f"{location}, Pakistan" if location != "Pakistan" else location
    return fallback


def _extract_posted_date(value: str) -> str:
    match = re.search(
        r"(?:job\s+posted|published|posted)(?:\s+on)?\s*[:\-]?\s*"
        r"(\d{1,2}[-\s][A-Za-z0-9]{1,9}[-\s]\d{4}|"
        r"[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})",
        value,
        flags=re.IGNORECASE,
    )
    return date_value(match.group(1)) if match else ""


def _stable_url(value: str) -> str:
    return re.sub(r"/\(S\([^)]+\)\)", "", value)


def _focused_detail_text(text: str, title: str) -> str:
    normalized_title = plain_text(title)
    position = text.casefold().find(normalized_title.casefold())
    if position < 0:
        return text[:2500]
    return text[position : position + 2500]


def _contains_bachelor_qualification(value: str) -> bool:
    normalized = re.sub(r"\s+", " ", value.casefold())
    if any(term in normalized for term in EDUCATION_TERMS):
        return True
    return bool(
        re.search(
            r"(?<![a-z])(?:bs|bsc|b\.sc|ba|b\.a|bcom|b\.com|bba)"
            r"(?![a-z])",
            normalized,
        )
    )


def _looks_like_job_link(title: str, href: str, context: str) -> bool:
    clean_title = plain_text(title)
    normalized_title = re.sub(r"\s+", " ", clean_title.casefold()).strip()
    title_and_url = f"{normalized_title} {href.casefold()}"
    if len(clean_title) < 3 or normalized_title in NON_JOB_NAVIGATION_TITLES:
        return False
    if "pakistanjobsbank.com" in href.casefold() and not re.search(
        r"/jobs/\d+/", href, flags=re.IGNORECASE
    ):
        return False
    if re.search(
        r"^/(?:loc|search|pro|ind)/|^/jobs-in-",
        href,
        flags=re.IGNORECASE,
    ):
        return False
    if any(
        value in title_and_url
        for value in (
            "privacy",
            "contact us",
            "about us",
            "login",
            "sign in",
            "tender",
            "procurement",
            "press release",
            "news",
        )
    ):
        return False
    # Surrounding page text can contain qualification and vacancy words from
    # unrelated cards. A candidate link itself must look like a job/detail link.
    return any(term in title_and_url for term in JOB_LINK_TERMS)
