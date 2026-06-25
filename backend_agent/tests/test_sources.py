from __future__ import annotations

import json
import time
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from datetime import datetime, timedelta, timezone

from backend_agent.jobs_agent import JobsAgent
from backend_agent.client_leads_agent import ClientLeadsAgent
from backend_agent.task_runner import TaskRunner
from backend_agent.government_jobs_agent import GovernmentJobsAgent
from backend_agent.models import SearchTask, TaskType
from backend_agent.sources.base_source import (
    BaseSource,
    FreshnessWindow,
    FreshnessStatus,
    SourceOpportunity,
    SourceCollectionError,
    deduplicate,
    filter_fresh,
    freshness_status,
    matches_task,
)
from backend_agent.storage import (
    GovernmentJobsSnapshotStorage,
    JsonStorage,
)
from backend_agent.sources.government_jobs_sources import (
    NationalJobPortalSource,
    FpscJobsSource,
    PpscJobsSource,
    PunjabJobsPortalSource,
    bachelor_qualification_eligibility,
    bs_software_eligibility,
    force_category,
    government_deduplicate,
    government_source_diversity,
    is_eligible_government_result,
    is_expired_government_result,
    parse_commission_pdf_text,
    punjab_candidate_eligibility,
    _looks_like_job_link,
)
from backend_agent.sources.jobs_sources import (
    RozeePublicJobsSource,
    finalize_private_job,
    is_suitable_private_job,
    private_job_rank,
)
from backend_agent.sources.client_leads_sources import (
    FreelancerProjectsSource,
    FreelancerPublicApiSource,
    TruelancerProjectsSource,
    client_leads_sources,
)
from backend_agent.services.client_lead_quality_service import (
    ClientLeadCategory,
    ClientLeadQualityService,
)


class StaticSource(BaseSource):
    def __init__(self, results: list[SourceOpportunity]) -> None:
        super().__init__("Static test source")
        self.results = results

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        return self.results


class FailingSource(BaseSource):
    def __init__(self) -> None:
        super().__init__("Failing source")

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        raise RuntimeError("Source unavailable")


class NamedFailingSource(BaseSource):
    def __init__(self, source_name: str) -> None:
        super().__init__(source_name)

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        raise RuntimeError("Source temporarily unavailable")


class DelayedSource(BaseSource):
    def __init__(
        self,
        source_name: str,
        delay_seconds: float,
        results: list[SourceOpportunity],
    ) -> None:
        super().__init__(source_name)
        self.delay_seconds = delay_seconds
        self.results = results

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        time.sleep(self.delay_seconds)
        return self.results


def _cached_government_record() -> dict[str, object]:
    return {
        "title": "Accounts Officer",
        "department": "Finance Department",
        "organization": "Finance Department",
        "location": "Pakistan",
        "province_city": "Pakistan",
        "source": "FPSC",
        "source_name": "FPSC",
        "source_link": "https://example.gov.pk/jobs/accounts-officer",
        "apply_url": "https://example.gov.pk/jobs/accounts-officer",
        "posted_date": "2026-06-20",
        "application_deadline": "2099-12-31",
        "deadline": "2099-12-31",
        "qualification_required": "Bachelor degree or equivalent",
        "required_education": "Bachelor degree or equivalent",
        "domicile_required": "All Pakistan / open merit",
        "province_eligibility": "All Pakistan",
        "bs_software_engineering_eligible": "Yes",
        "punjab_candidate_eligible": "Yes",
        "required_skills": [],
        "is_mock": False,
        "is_source_review_link": False,
    }


def _live_government_opportunity(
    source_name: str = "FPSC",
) -> SourceOpportunity:
    return SourceOpportunity(
        title="Accounts Officer",
        organization="Finance Department",
        location="Pakistan",
        source_link="https://example.gov.pk/jobs/accounts-officer",
        posted_date="2026-06-20",
        deadline="2099-12-31",
        source_name=source_name,
        required_education="Bachelor degree or equivalent",
        eligibility_domicile="All Pakistan / open merit",
    )


def _snapshot_health_entry(status: str) -> dict[str, object]:
    return {
        "snapshot_exists": status != "missing",
        "snapshot_generated_at": (
            "2026-06-24T08:00:00Z"
            if status != "missing"
            else ""
        ),
        "snapshot_age_hours": 1.0 if status == "fresh" else 72.0,
        "snapshot_record_count": (
            1 if status in {"fresh", "stale"} else 0
        ),
        "snapshot_health": status,
        "snapshot_path": "",
    }


def _snapshot_timestamp(*, hours_ago: float = 0) -> str:
    generated_at = datetime.now(timezone.utc) - timedelta(hours=hours_ago)
    return generated_at.replace(microsecond=0).isoformat().replace(
        "+00:00",
        "Z",
    )


class SourceCollectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.task = SearchTask(
            id="test",
            title="Flutter jobs",
            task_type=TaskType.JOB,
            keywords=["Flutter"],
            location="Remote",
            level="Any",
            filters=[],
            daily_limit=10,
            is_active=True,
            created_at="2026-06-23",
        )

    def test_deduplicates_by_title_organization_and_link(self) -> None:
        result = SourceOpportunity(
            title="Flutter Developer",
            organization="Example",
            location="Remote",
            source_link="https://example.org/jobs/1",
        )

        self.assertEqual(len(deduplicate([result, result])), 1)

    def test_filters_last_24_hours(self) -> None:
        now = datetime.now(timezone.utc)
        fresh = SourceOpportunity(
            title="Fresh Flutter role",
            organization="Example",
            location="Remote",
            source_link="https://example.org/jobs/fresh",
            posted_date=(now - timedelta(hours=2)).isoformat(),
        )
        old = SourceOpportunity(
            title="Old Flutter role",
            organization="Example",
            location="Remote",
            source_link="https://example.org/jobs/old",
            posted_date=(now - timedelta(days=2)).isoformat(),
        )

        self.assertEqual(
            filter_fresh(
                [fresh, old],
                FreshnessWindow.LAST_24_HOURS,
            ),
            [fresh],
        )
        self.assertEqual(
            filter_fresh([fresh, old], FreshnessWindow.ALL),
            [fresh, old],
        )

    def test_short_keyword_does_not_match_inside_another_word(self) -> None:
        unrelated = SourceOpportunity(
            title="Email Marketing Manager",
            organization="Example",
            location="Remote",
            source_link="https://example.org/jobs/email",
        )
        ai_task = SearchTask(
            id="ai",
            title="AI jobs",
            task_type=TaskType.JOB,
            keywords=["AI"],
            location="Remote",
            level="Any",
            filters=[],
            daily_limit=10,
            is_active=True,
            created_at="2026-06-23",
        )

        self.assertFalse(matches_task(unrelated, ai_task))

    def test_assigns_all_freshness_statuses(self) -> None:
        now = datetime(2026, 6, 23, 12, tzinfo=timezone.utc)

        self.assertEqual(
            freshness_status("2026-06-23T01:00:00Z", now),
            FreshnessStatus.TODAY,
        )
        self.assertEqual(
            freshness_status("2026-06-22T18:00:00Z", now),
            FreshnessStatus.LAST_24_HOURS,
        )
        self.assertEqual(
            freshness_status("2026-06-20T12:00:00Z", now),
            FreshnessStatus.LAST_7_DAYS,
        )
        self.assertEqual(
            freshness_status("2026-06-01T12:00:00Z", now),
            FreshnessStatus.OLDER,
        )
        self.assertEqual(
            freshness_status("", now),
            FreshnessStatus.UNKNOWN,
        )

    def test_agent_uses_real_source_and_serializes_required_fields(self) -> None:
        source_result = SourceOpportunity(
            title="Flutter Developer",
            organization="Open Source Org",
            location="Remote",
            source_link="https://example.org/issues/1",
            posted_date=datetime.now(timezone.utc).isoformat(),
            required_skills=["Flutter", "Dart"],
            source_name="Public source",
        )
        agent = JobsAgent()
        agent.sources = [StaticSource([source_result])]

        result = agent.execute(self.task)[0].to_dict()

        self.assertEqual(result["source_name"], "Public source")
        self.assertEqual(result["required_skills"], ["Flutter", "Dart"])
        self.assertNotEqual(result["source_name"], "Mock fallback")

    def test_agent_keeps_mock_fallback(self) -> None:
        agent = JobsAgent()
        agent.sources = [FailingSource()]

        results = agent.execute(self.task)

        self.assertTrue(results)
        self.assertTrue(
            all(item.source_name == "Mock fallback" for item in results)
        )
        self.assertTrue(all(item.is_mock for item in results))

    def test_job_agent_does_not_mock_when_public_source_returns_no_match(self) -> None:
        agent = JobsAgent()
        agent.sources = [StaticSource([])]

        self.assertEqual(agent.execute(self.task), [])

    def test_private_job_ranking_prioritizes_visa_then_pakistan(self) -> None:
        visa = SourceOpportunity(
            title="Junior AI Engineer",
            organization="Global AI",
            location="Germany",
            source_link="https://example.org/visa",
            description="Visa sponsorship and relocation support provided.",
        )
        pakistan = SourceOpportunity(
            title="Associate Software Engineer",
            organization="Pakistan Tech",
            location="Lahore, Pakistan",
            source_link="https://example.org/pakistan",
            description="Entry-level role for fresh graduates.",
        )
        for item in (visa, pakistan):
            finalize_private_job(item)

        ranked = sorted([pakistan, visa], key=private_job_rank)

        self.assertEqual(ranked[0], visa)
        self.assertEqual(visa.visa_sponsorship_status, "Yes")
        self.assertEqual(pakistan.fresher_friendly_status, "Yes")

    def test_private_job_filter_excludes_senior_roles(self) -> None:
        result = SourceOpportunity(
            title="Senior Machine Learning Engineer",
            organization="Example",
            location="Germany",
            source_link="https://example.org/senior",
        )
        finalize_private_job(result)

        self.assertFalse(is_suitable_private_job(result))

    def test_private_job_filter_excludes_phd_required_roles(self) -> None:
        result = SourceOpportunity(
            title="AI Engineer (PhD Required)",
            organization="Example",
            location="Pakistan",
            source_link="https://example.org/phd",
        )
        finalize_private_job(result)

        self.assertFalse(is_suitable_private_job(result))

    def test_parses_public_rozee_embedded_jobs(self) -> None:
        source = RozeePublicJobsSource()
        source.fetch_text = lambda url: (
            '<script>var data={"jobs":{"sponsored":[],"basic":['
            '{"title":"Trainee AI Engineer","company_name":"Example AI",'
            '"city":"Lahore","country":"Pakistan",'
            '"rozeePermaLink":"example-ai-trainee-ai-engineer-jobs-1",'
            '"created_at":"2026-06-23T10:00:00Z",'
            '"applyBy":"2026-07-01T00:00:00Z",'
            '"description_raw":"Fresh graduate role with training and mentorship.",'
            '"skills":["Python","Machine Learning"]}'
            ']}};</script>'
        )

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].organization, "Example AI")
        self.assertEqual(results[0].fresher_friendly_status, "Yes")
        self.assertEqual(results[0].training_provided_status, "Yes")

    def test_storage_accepts_a_shared_generation_timestamp(self) -> None:
        with TemporaryDirectory() as directory:
            storage = JsonStorage(Path(directory))

            first = storage.write_results(
                "jobs",
                "ai",
                [],
                timestamp="20260623T080000Z",
            )
            second = storage.write_results(
                "jobs",
                "visa",
                [],
                timestamp="20260623T080000Z",
            )

        self.assertTrue(first.name.endswith("20260623T080000Z.json"))
        self.assertTrue(second.name.endswith("20260623T080000Z.json"))

    def test_parses_official_punjab_job_rows(self) -> None:
        source = PunjabJobsPortalSource()
        source.fetch_text = lambda url: """
            <tr>
              <td data-label="Job Title"><strong>
                <a href="https://jobs.punjab.gov.pk/new_recruit/job_detail/junior-software-developer">
                  Junior Software Developer
                </a>
              </strong></td>
              <td data-label="Department">The Urban Unit</td>
              <td data-label="Project">The Urban Unit</td>
              <td data-label="Province">Punjab, Pakistan</td>
              <td>07-Jul-2026</td>
            </tr>
        """

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].organization, "The Urban Unit")
        self.assertEqual(results[0].deadline, "2026-07-07")
        self.assertIn("Software Engineer", results[0].required_skills)

    def test_parses_official_national_job_cards(self) -> None:
        source = NationalJobPortalSource()
        source.fetch_text = lambda url: """
          <!-- Job Card -->
          <div class="job-card">
            <a href="https://www.njp.gov.pk/jobs/9999">Website Developer</a>
            <p><svg></svg> by Ministry of Information Technology, Government of Pakistan</p>
            <span>Available Till Jul 08, 2026</span>
          </div>
        """

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].deadline, "2026-07-08")
        self.assertEqual(results[0].source_name, "National Job Portal Pakistan")

    def test_njp_structured_bs_job_is_accepted(self) -> None:
        source = NationalJobPortalSource()
        listing = """
          <!-- Job Card -->
          <div class="job-card">
            <a href="/jobs/9999">Assistant Director Administration</a>
            <p>by Cabinet Division, Government of Pakistan</p>
            <span>BPS-17 2 vacancies Available Till Jul 08, 2099</span>
          </div>
        """
        detail = """
          <h1>Assistant Director Administration</h1>
          <p>Cabinet Division, Government of Pakistan</p>
          <div>Grade BPS-17</div>
          <div>Vacancies 2 vacancies</div>
          <h4>Qualifications</h4>
          <p>Bachelor's Degree in any discipline from a recognized university</p>
          <h4>Experience</h4>
          <p>Domicile Quota: All Pakistan</p>
          <p>Application Deadline 08 Jul 2099</p>
          <p>Posted: 18 Jun 2026</p>
        """
        source.fetch_text = lambda url: (
            listing if url.endswith("/jobs/live") else detail
        )

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertTrue(is_eligible_government_result(results[0]))
        self.assertEqual(results[0].post_count, 2)
        self.assertIn("BPS-17", results[0].job_scale)

    def test_punjab_portal_structured_bachelor_job_is_accepted(self) -> None:
        source = PunjabJobsPortalSource()
        listing = """
          <table><tr>
            <td data-label="Job Title">
              <a href="/new_recruit/job_detail/research-officer-1">
                Research Officer
              </a>
            </td>
            <td data-label="Department">Planning Department</td>
            <td data-label="Province">Punjab, Pakistan</td>
            <td data-label="Closing Date">08-Jul-2099</td>
          </tr></table>
        """
        detail = """
          <h1>Research Officer</h1>
          <p>Industry Planning Department</p>
          <p>Total Positions 4</p>
          <p>Job Posted 18-06-2026</p>
          <p>Level PPS-7</p>
          <p>Last Date to Apply 08-07-2099</p>
          <h4>Qualification and Experience:</h4>
          <p>Graduation or equivalent qualification from a recognized university.</p>
          <h4>Competencies</h4>
          <p>Domicile Only Punjab</p>
        """
        source.fetch_text = lambda url: (
            listing if url.endswith("/new_recruit/jobs") else detail
        )

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertTrue(is_eligible_government_result(results[0]))
        self.assertEqual(results[0].post_count, 4)
        self.assertEqual(results[0].job_scale, "PPS-7")

    def test_ppsc_structured_bachelor_ad_is_accepted(self) -> None:
        source = PpscJobsSource()
        source.fetch_text = lambda url: """
          <table><tr>
            <td data-label="Ad No">08/2099</td>
            <td data-label="Post Name">Assistant Director Administration</td>
            <td data-label="Department">Services Department, Punjab</td>
            <td data-label="Qualification">Bachelor degree in any discipline</td>
            <td data-label="Domicile">Punjab domicile</td>
            <td data-label="Scale">BS-17</td>
            <td data-label="Closing Date">08-07-2099</td>
            <td><a href="/apply/assistant-director">Apply for this job</a></td>
          </tr></table>
        """

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertTrue(is_eligible_government_result(results[0]))
        self.assertEqual(results[0].advertisement_number, "08/2099")

    def test_fpsc_structured_bachelor_ad_is_accepted(self) -> None:
        source = FpscJobsSource()
        source.fetch_text = lambda url: """
          <table><tr>
            <td data-label="Advertisement No">12/2099</td>
            <td data-label="Title">Inspector</td>
            <td data-label="Department">Federal Investigation Agency</td>
            <td data-label="Education">Graduation or equivalent qualification</td>
            <td data-label="Quota">Open merit - citizens of Pakistan</td>
            <td data-label="Grade">BS-16</td>
            <td data-label="Last Date">08-07-2099</td>
            <td><a href="/jobs/inspector-12">View job details</a></td>
          </tr></table>
        """

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertTrue(is_eligible_government_result(results[0]))
        self.assertEqual(results[0].force_category, "Federal Investigation")

    def test_commission_fallback_is_not_a_normal_job(self) -> None:
        source = PpscJobsSource()
        source.fetch_text = lambda url: """
          <nav><a href="/JobsArchive.aspx">Jobs Archive</a></nav>
        """

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertTrue(results[0].is_source_review_link)
        self.assertTrue(source.fallback_used)
        self.assertFalse(is_eligible_government_result(results[0]))

    def test_ppsc_pdf_bachelor_post_is_accepted(self) -> None:
        results = parse_commission_pdf_text(
            text="""
                ADVERTISEMENT NO. 08/2099
                1. ASSISTANT DIRECTOR ADMINISTRATION (BS-17)
                Department: Services and General Administration Department
                Qualification: Bachelor's Degree in any discipline from a
                recognized university.
                Domicile: Punjab domicile
                No. of Posts: 2
                Closing Date: 08-07-2099
            """,
            task=self.task,
            source_name="PPSC",
            pdf_url="https://www.ppsc.gop.pk/ads/08-2099.pdf",
            apply_url="https://www.ppsc.gop.pk/Jobs.aspx",
            default_department="Punjab Public Service Commission",
            default_location="Punjab, Pakistan",
            default_domicile="Punjab domicile",
        )

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].advertisement_number, "08/2099")
        self.assertEqual(results[0].post_count, 2)
        self.assertEqual(results[0].job_scale, "BS-17")
        self.assertTrue(is_eligible_government_result(results[0]))

    def test_fpsc_pdf_bachelor_post_is_accepted(self) -> None:
        results = parse_commission_pdf_text(
            text="""
                CONSOLIDATED ADVERTISEMENT NO. 03/2099
                CASE NO. F.4-12/2099
                INSPECTOR (BS-16)
                Department: Federal Investigation Agency
                Qualification: Graduation or equivalent qualification from
                a recognized university.
                Quota: Open merit for citizens of Pakistan
                Vacancies: 4
                Closing Date: 10 July 2099
            """,
            task=self.task,
            source_name="FPSC",
            pdf_url="https://www.fpsc.gov.pk/uploads/03-2099.pdf",
            apply_url="https://online.fpsc.gov.pk/",
            default_department="Federal Public Service Commission",
            default_location="Pakistan",
            default_domicile="Open merit / All Pakistan",
        )

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].force_category, "Federal Investigation")
        self.assertEqual(results[0].post_count, 4)
        self.assertTrue(is_eligible_government_result(results[0]))

    def test_commission_pdf_rejects_intermediate_only_post(self) -> None:
        results = parse_commission_pdf_text(
            text="""
                ADVERTISEMENT NO. 04/2099
                1. JUNIOR CLERK (BS-11)
                Department: Revenue Department
                Qualification: Intermediate only
                Domicile: Punjab domicile
                Closing Date: 08-07-2099
            """,
            task=self.task,
            source_name="PPSC",
            pdf_url="https://www.ppsc.gop.pk/ads/04-2099.pdf",
            apply_url="https://www.ppsc.gop.pk/Jobs.aspx",
            default_department="Punjab Public Service Commission",
            default_location="Punjab, Pakistan",
            default_domicile="Punjab domicile",
        )

        self.assertEqual(results, [])

    def test_commission_pdf_rejects_expired_advertisement(self) -> None:
        results = parse_commission_pdf_text(
            text="""
                ADVERTISEMENT NO. 01/2020
                1. RESEARCH OFFICER (BS-17)
                Department: Planning Department
                Qualification: BS or equivalent qualification
                Domicile: Punjab domicile
                Closing Date: 08-07-2020
            """,
            task=self.task,
            source_name="PPSC",
            pdf_url="https://www.ppsc.gop.pk/ads/01-2020.pdf",
            apply_url="https://www.ppsc.gop.pk/Jobs.aspx",
            default_department="Punjab Public Service Commission",
            default_location="Punjab, Pakistan",
            default_domicile="Punjab domicile",
        )

        self.assertEqual(results, [])

    def test_malformed_commission_pdf_falls_back_safely(self) -> None:
        source = PpscJobsSource()
        source.fetch_text = lambda url: """
          <a href="/advertisements/08-2099.pdf">
            Advertisement No. 08/2099
          </a>
        """
        source.fetch_bytes = lambda *args, **kwargs: b"not a pdf"

        results = source.collect(self.task)

        self.assertEqual(len(results), 1)
        self.assertTrue(results[0].is_source_review_link)
        self.assertFalse(is_eligible_government_result(results[0]))
        self.assertTrue(source.fallback_used)
        self.assertIn("Malformed", source.failure_reason)

    def test_government_dedupes_url_identity_and_advertisement(self) -> None:
        first = SourceOpportunity(
            title="Assistant Director",
            organization="Finance Department",
            location="Punjab",
            source_link="https://example.gov.pk/jobs/42",
            deadline="2099-07-08",
            advertisement_number="08/2099",
            source_name="PPSC",
        )
        same_url = SourceOpportunity(
            title="Assistant Director Finance",
            organization="Finance Department",
            location="Punjab",
            source_link="https://example.gov.pk/jobs/42/",
            deadline="2099-07-08",
            source_name="PPSC",
        )
        same_advertisement = SourceOpportunity(
            title="Assistant Director",
            organization="Finance Department",
            location="Punjab",
            source_link="https://example.gov.pk/jobs/42/details",
            deadline="2099-07-08",
            advertisement_number="08 / 2099",
            source_name="PPSC",
        )
        same_identity = SourceOpportunity(
            title="Assistant Director",
            organization="Finance Department",
            location="Punjab",
            source_link="https://mirror.gov.pk/jobs/42",
            deadline="2099-07-08",
            source_name="PPSC",
        )

        results = government_deduplicate(
            [first, same_url, same_advertisement, same_identity]
        )

        self.assertEqual(len(results), 1)

    def test_government_agent_keeps_only_bs_or_equivalent_jobs(self) -> None:
        eligible = SourceOpportunity(
            title="Software Engineer",
            organization="Government Department",
            location="Pakistan",
            source_link="https://example.org/government/eligible",
            posted_date=datetime.now(timezone.utc).isoformat(),
            required_skills=["Software Engineer"],
            source_name="Official source",
            required_education="Minimum 16 years of education in Software Engineering",
            eligibility_domicile="All Pakistan candidates may apply",
        )
        ineligible = SourceOpportunity(
            title="IT Assistant",
            organization="Government Department",
            location="Pakistan",
            source_link="https://example.org/government/ineligible",
            posted_date=datetime.now(timezone.utc).isoformat(),
            required_skills=["IT Officer"],
            source_name="Official source",
        )
        agent = GovernmentJobsAgent()
        agent.sources = [StaticSource([eligible, ineligible])]
        government_task = SearchTask(
            id="government",
            title="Government technology jobs",
            task_type=TaskType.GOVERNMENT_JOB,
            keywords=["Software Engineer", "IT Officer", "Computer Science"],
            location="Pakistan",
            level="BS Software Engineering",
            filters=["Government"],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-23",
        )

        results = agent.execute(government_task)

        self.assertEqual(len(results), 1)
        self.assertEqual(
            results[0].required_education,
            eligible.required_education,
        )

    def test_government_filters_reject_outside_punjab_only_domicile(self) -> None:
        result = SourceOpportunity(
            title="Software Engineer",
            organization="Sindh Department",
            location="Karachi, Pakistan",
            source_link="https://example.org/sindh-only",
            required_education="BS Software Engineering",
            eligibility_domicile="Sindh domicile only",
        )

        self.assertFalse(is_eligible_government_result(result))
        self.assertEqual(
            punjab_candidate_eligibility(result.eligibility_domicile),
            "No",
        )

    def test_government_eligibility_recognizes_computing_degrees(self) -> None:
        self.assertEqual(
            bs_software_eligibility(
                "16 years education in Computer Science, IT, "
                "Software Engineering, AI or Data Science"
            ),
            "Yes",
        )

    def test_government_accepts_bachelor_equivalent_qualification(self) -> None:
        for qualification in (
            "BS Hons in any discipline",
            "Bachelor's Degree from a recognized university",
            "Graduation or equivalent qualification",
            "Minimum 16 years education",
            "BSc, BA, B.Com or BBA",
        ):
            self.assertEqual(
                bachelor_qualification_eligibility(qualification),
                "Yes",
            )

    def test_government_accepts_non_field_specific_bachelor_job(self) -> None:
        result = SourceOpportunity(
            title="Assistant Director Administration",
            organization="Federal Government Department",
            location="Islamabad, Pakistan",
            source_link="https://example.org/government/admin",
            required_education="Bachelor degree in any discipline",
            eligibility_domicile="Open merit - citizens of Pakistan",
            source_name="FPSC",
            deadline="2099-12-31",
        )

        self.assertTrue(is_eligible_government_result(result))
        self.assertIn("bachelor-level", result.match_reason)

    def test_government_accepts_force_bachelor_job(self) -> None:
        result = SourceOpportunity(
            title="Assistant Director",
            organization="Airport Security Force",
            location="Pakistan",
            source_link="https://joinasf.gov.pk/jobs/assistant-director",
            required_education="Bachelor degree or equivalent qualification",
            eligibility_domicile="All Pakistan candidates may apply",
            source_name="ASF Careers",
            deadline="2099-12-31",
        )

        self.assertTrue(is_eligible_government_result(result))
        self.assertEqual(result.force_category, "Airport Security Force")

    def test_government_accepts_police_bachelor_job(self) -> None:
        result = SourceOpportunity(
            title="Sub Inspector",
            organization="Punjab Police",
            location="Punjab, Pakistan",
            source_link="https://punjabpolice.gov.pk/jobs/sub-inspector",
            required_education="Graduation from a recognized university",
            eligibility_domicile="Punjab domicile required",
            source_name="Punjab Police",
            deadline="2099-12-31",
        )

        self.assertTrue(is_eligible_government_result(result))
        self.assertEqual(result.force_category, "Police")

    def test_government_agent_keeps_active_jobs_older_than_seven_days(
        self,
    ) -> None:
        result = SourceOpportunity(
            title="Accounts Officer",
            organization="Federal Finance Department",
            location="Pakistan",
            source_link="https://example.gov.pk/jobs/accounts-officer",
            posted_date="2025-01-01",
            deadline="2099-12-31",
            required_education="B.Com or equivalent bachelor degree",
            eligibility_domicile="Open merit for Pakistani citizens",
            source_name="FPSC",
        )
        agent = GovernmentJobsAgent(FreshnessWindow.LAST_7_DAYS)
        agent.sources = [StaticSource([result])]

        results = agent.execute(self.task)

        self.assertEqual(len(results), 1)

    def test_government_source_diversity_reports_counts(self) -> None:
        results = [
            SourceOpportunity(
                title="Software Engineer",
                organization="Digital Department",
                location="Punjab",
                source_link="https://example.gov.pk/jobs/1",
                source_name="Punjab Jobs Portal",
            ),
            SourceOpportunity(
                title="Accounts Officer",
                organization="Finance Department",
                location="Pakistan",
                source_link="https://example.gov.pk/jobs/2",
                source_name="FPSC",
            ),
            SourceOpportunity(
                title="Inspector",
                organization="Federal Investigation Agency",
                location="Pakistan",
                source_link="https://example.gov.pk/jobs/3",
                source_name="FPSC",
            ),
        ]

        report = government_source_diversity(results)

        self.assertEqual(report["total_results"], 3)
        self.assertEqual(report["source_count"], 2)
        self.assertEqual(report["department_count"], 3)
        self.assertEqual(report["it_development_count"], 1)
        self.assertEqual(report["non_it_count"], 2)
        self.assertEqual(
            report["results_by_source"],
            {"FPSC": 2, "Punjab Jobs Portal": 1},
        )

    def test_government_source_failure_uses_verified_active_cache(self) -> None:
        with TemporaryDirectory() as directory:
            cache_directory = Path(directory)
            JsonStorage(cache_directory).write_json(
                cache_directory / "government_20260623T080000Z.json",
                [_cached_government_record()],
            )
            agent = GovernmentJobsAgent(cache_directory=cache_directory)
            agent.sources = [NamedFailingSource("FPSC")]

            results = agent.execute(self.task)

            self.assertEqual(len(results), 1)
            self.assertTrue(results[0].is_cached)
            self.assertEqual(results[0].cache_reason, "source_unavailable")
            self.assertEqual(
                results[0].cached_from_run,
                "20260623T080000Z",
            )
            self.assertEqual(results[0].source_status, "cached_fallback")
            self.assertEqual(
                agent.source_reports[0]["cached_records_used"],
                1,
            )
            self.assertTrue(agent.source_reports[0]["fallback_used"])

    def test_government_snapshot_written_after_successful_run(self) -> None:
        with TemporaryDirectory() as directory:
            snapshot_directory = Path(directory) / "snapshots"
            agent = GovernmentJobsAgent(
                snapshot_directory=snapshot_directory
            )
            agent.sources = [
                StaticSource([_live_government_opportunity("FPSC")])
            ]
            agent.sources[0].source_name = "FPSC"

            results = agent.execute(self.task)

            snapshot_path = snapshot_directory / "fpsc_verified.json"
            payload = json.loads(snapshot_path.read_text(encoding="utf-8"))
            self.assertEqual(len(results), 1)
            self.assertEqual(payload["source_name"], "FPSC")
            self.assertEqual(payload["record_count"], 1)
            self.assertTrue(payload["generated_at"])
            self.assertEqual(len(payload["records"]), 1)

    def test_government_snapshot_excludes_expired_jobs(self) -> None:
        with TemporaryDirectory() as directory:
            snapshot_directory = Path(directory) / "snapshots"
            expired = _live_government_opportunity("FPSC")
            expired.deadline = "2020-01-01"
            agent = GovernmentJobsAgent(
                snapshot_directory=snapshot_directory
            )
            agent.sources = [StaticSource([expired])]
            agent.sources[0].source_name = "FPSC"

            agent.execute(self.task)

            payload = json.loads(
                (snapshot_directory / "fpsc_verified.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(payload["record_count"], 0)
            self.assertEqual(payload["records"], [])

    def test_government_snapshot_excludes_fallback_links(self) -> None:
        with TemporaryDirectory() as directory:
            snapshot_directory = Path(directory) / "snapshots"
            fallback = _live_government_opportunity("PPSC")
            fallback.is_source_review_link = True
            agent = GovernmentJobsAgent(
                snapshot_directory=snapshot_directory
            )
            agent.sources = [StaticSource([fallback])]
            agent.sources[0].source_name = "PPSC"

            agent.execute(self.task)

            payload = json.loads(
                (snapshot_directory / "ppsc_verified.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(payload["record_count"], 0)
            self.assertEqual(payload["records"], [])

    def test_government_source_failure_loads_snapshot(self) -> None:
        with TemporaryDirectory() as directory:
            snapshot_directory = Path(directory) / "snapshots"
            snapshot_storage = GovernmentJobsSnapshotStorage(
                snapshot_directory
            )
            generated_at = _snapshot_timestamp(hours_ago=1)
            snapshot_storage.write_snapshot(
                "FPSC",
                generated_at,
                [_cached_government_record()],
            )
            agent = GovernmentJobsAgent(
                snapshot_directory=snapshot_directory
            )
            agent.sources = [NamedFailingSource("FPSC")]

            results = agent.execute(self.task)

            self.assertEqual(len(results), 1)
            self.assertTrue(results[0].is_cached)
            self.assertEqual(
                results[0].cached_from_run,
                generated_at,
            )
            report = agent.source_reports[0]
            self.assertTrue(report["cache_snapshot_used"])
            self.assertEqual(report["cached_records_used"], 1)
            self.assertTrue(
                str(report["cache_snapshot_path"]).endswith(
                    "fpsc_verified.json"
                )
            )

    def test_government_snapshot_cached_job_is_revalidated(self) -> None:
        with TemporaryDirectory() as directory:
            snapshot_directory = Path(directory) / "snapshots"
            expired = _cached_government_record()
            expired["application_deadline"] = "2020-01-01"
            GovernmentJobsSnapshotStorage(
                snapshot_directory
            ).write_snapshot(
                "FPSC",
                _snapshot_timestamp(hours_ago=1),
                [expired],
            )
            agent = GovernmentJobsAgent(
                snapshot_directory=snapshot_directory
            )

            cached, snapshot_path, health = (
                agent._cached_results_for_source("FPSC")
            )

            self.assertEqual(cached, [])
            self.assertIsNotNone(snapshot_path)
            self.assertEqual(health, "fresh")

    def test_government_snapshot_health_reports_fresh(self) -> None:
        with TemporaryDirectory() as directory:
            storage = GovernmentJobsSnapshotStorage(Path(directory))
            now = datetime.now(timezone.utc).replace(microsecond=0)
            storage.write_snapshot(
                "FPSC",
                (now - timedelta(hours=24))
                .isoformat()
                .replace("+00:00", "Z"),
                [_cached_government_record()],
            )

            health = storage.snapshot_health(
                "FPSC",
                now=now,
            )

            self.assertEqual(health["snapshot_health"], "fresh")
            self.assertEqual(health["snapshot_age_hours"], 24.0)
            self.assertEqual(health["snapshot_record_count"], 1)

    def test_government_snapshot_health_reports_stale(self) -> None:
        with TemporaryDirectory() as directory:
            storage = GovernmentJobsSnapshotStorage(Path(directory))
            now = datetime.now(timezone.utc).replace(microsecond=0)
            storage.write_snapshot(
                "FPSC",
                (now - timedelta(hours=96))
                .isoformat()
                .replace("+00:00", "Z"),
                [_cached_government_record()],
            )

            health = storage.snapshot_health(
                "FPSC",
                now=now,
            )

            self.assertEqual(health["snapshot_health"], "stale")
            self.assertEqual(health["snapshot_age_hours"], 96.0)

    def test_government_snapshot_health_reports_empty(self) -> None:
        with TemporaryDirectory() as directory:
            storage = GovernmentJobsSnapshotStorage(Path(directory))
            storage.write_snapshot(
                "FPSC",
                _snapshot_timestamp(hours_ago=1),
                [],
            )

            health = storage.snapshot_health("FPSC")

            self.assertTrue(health["snapshot_exists"])
            self.assertEqual(health["snapshot_record_count"], 0)
            self.assertEqual(health["snapshot_health"], "empty")

    def test_government_snapshot_health_reports_missing(self) -> None:
        with TemporaryDirectory() as directory:
            health = GovernmentJobsSnapshotStorage(
                Path(directory)
            ).snapshot_health("FPSC")

            self.assertFalse(health["snapshot_exists"])
            self.assertEqual(health["snapshot_generated_at"], "")
            self.assertIsNone(health["snapshot_age_hours"])
            self.assertEqual(health["snapshot_health"], "missing")

    def test_government_aggregate_health_is_healthy_for_primary_sources(
        self,
    ) -> None:
        summary = GovernmentJobsSnapshotStorage.aggregate_health(
            {
                "National Job Portal Pakistan": _snapshot_health_entry(
                    "fresh"
                ),
                "Punjab Jobs Portal": _snapshot_health_entry("fresh"),
                "PPSC": _snapshot_health_entry("empty"),
                "FPSC": _snapshot_health_entry("empty"),
            }
        )

        self.assertEqual(summary["overall_health"], "healthy")
        self.assertEqual(summary["usable_snapshot_sources"], 2)
        self.assertEqual(summary["usable_snapshot_percentage"], 50.0)

    def test_government_aggregate_health_warns_for_critical_missing(
        self,
    ) -> None:
        summary = GovernmentJobsSnapshotStorage.aggregate_health(
            {
                "National Job Portal Pakistan": _snapshot_health_entry(
                    "fresh"
                ),
                "Punjab Jobs Portal": _snapshot_health_entry("fresh"),
                "PPSC": _snapshot_health_entry("missing"),
                "FPSC": _snapshot_health_entry("fresh"),
            }
        )

        self.assertEqual(summary["overall_health"], "warning")
        self.assertEqual(summary["critical_sources_missing"], ["PPSC"])
        self.assertIn(
            "PPSC snapshot is missing",
            summary["warnings"],
        )

    def test_government_aggregate_health_is_critical_for_primary_missing(
        self,
    ) -> None:
        summary = GovernmentJobsSnapshotStorage.aggregate_health(
            {
                "National Job Portal Pakistan": _snapshot_health_entry(
                    "missing"
                ),
                "Punjab Jobs Portal": _snapshot_health_entry("missing"),
                "PPSC": _snapshot_health_entry("fresh"),
                "FPSC": _snapshot_health_entry("fresh"),
            }
        )

        self.assertEqual(summary["overall_health"], "critical")

    def test_government_aggregate_health_warns_below_fifty_percent(
        self,
    ) -> None:
        summary = GovernmentJobsSnapshotStorage.aggregate_health(
            {
                "National Job Portal Pakistan": _snapshot_health_entry(
                    "fresh"
                ),
                "Punjab Jobs Portal": _snapshot_health_entry("fresh"),
                "PPSC": _snapshot_health_entry("empty"),
                "FPSC": _snapshot_health_entry("empty"),
                "Source Five": _snapshot_health_entry("empty"),
            }
        )

        self.assertEqual(summary["overall_health"], "warning")
        self.assertEqual(summary["usable_snapshot_percentage"], 40.0)
        self.assertIn(
            "Only 40% of sources have usable snapshots",
            summary["warnings"],
        )

    def test_government_aggregate_health_generates_warnings(self) -> None:
        summary = GovernmentJobsSnapshotStorage.aggregate_health(
            {
                "National Job Portal Pakistan": _snapshot_health_entry(
                    "fresh"
                ),
                "Punjab Jobs Portal": _snapshot_health_entry("missing"),
                "PPSC": _snapshot_health_entry("empty"),
                "FPSC": _snapshot_health_entry("stale"),
            }
        )

        self.assertIn(
            "Punjab Jobs Portal snapshot is missing",
            summary["warnings"],
        )
        self.assertIn(
            "PPSC snapshot is empty",
            summary["warnings"],
        )
        self.assertIn(
            "FPSC snapshot is stale",
            summary["warnings"],
        )
        self.assertEqual(summary["critical_sources_stale"], ["FPSC"])

    def test_government_stale_snapshot_adds_cache_warning(self) -> None:
        with TemporaryDirectory() as directory:
            snapshot_directory = Path(directory) / "snapshots"
            GovernmentJobsSnapshotStorage(
                snapshot_directory
            ).write_snapshot(
                "FPSC",
                _snapshot_timestamp(hours_ago=96),
                [_cached_government_record()],
            )
            agent = GovernmentJobsAgent(
                snapshot_directory=snapshot_directory
            )
            agent.sources = [NamedFailingSource("FPSC")]

            results = agent.execute(self.task)

            self.assertEqual(len(results), 1)
            self.assertEqual(
                results[0].source_status,
                "stale_cached_fallback",
            )
            self.assertEqual(
                results[0].cache_warning,
                "Snapshot older than 48 hours",
            )
            self.assertEqual(
                agent.source_reports[0]["status"],
                "stale_cached_fallback",
            )

    def test_government_stale_snapshot_revalidates_active_eligibility(
        self,
    ) -> None:
        with TemporaryDirectory() as directory:
            snapshot_directory = Path(directory) / "snapshots"
            invalid = _cached_government_record()
            invalid["punjab_candidate_eligible"] = "No"
            invalid["domicile_required"] = "Sindh domicile only"
            GovernmentJobsSnapshotStorage(
                snapshot_directory
            ).write_snapshot(
                "FPSC",
                _snapshot_timestamp(hours_ago=96),
                [invalid],
            )
            agent = GovernmentJobsAgent(
                snapshot_directory=snapshot_directory
            )

            results, _, health = agent._cached_results_for_source(
                "FPSC"
            )

            self.assertEqual(results, [])
            self.assertEqual(health, "stale")

    def test_government_history_is_used_only_when_snapshot_missing(
        self,
    ) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            history_directory = root / "history"
            snapshot_directory = root / "snapshots"
            JsonStorage(root).write_json(
                history_directory / "government_20260623T080000Z.json",
                [_cached_government_record()],
            )
            snapshots = GovernmentJobsSnapshotStorage(
                snapshot_directory
            )
            snapshot_path = snapshots.write_snapshot(
                "FPSC",
                _snapshot_timestamp(hours_ago=1),
                [],
            )
            agent = GovernmentJobsAgent(
                cache_directory=history_directory,
                snapshot_directory=snapshot_directory,
            )

            cached_with_snapshot, used_path, snapshot_health = (
                agent._cached_results_for_source("FPSC")
            )
            snapshot_path.unlink()
            cached_without_snapshot, historical_path, missing_health = (
                agent._cached_results_for_source("FPSC")
            )

            self.assertEqual(cached_with_snapshot, [])
            self.assertEqual(used_path, snapshot_path)
            self.assertEqual(snapshot_health, "empty")
            self.assertEqual(len(cached_without_snapshot), 1)
            self.assertIsNone(historical_path)
            self.assertEqual(missing_health, "missing")

    def test_government_cache_rejects_expired_job(self) -> None:
        record = _cached_government_record()
        record["application_deadline"] = "2020-01-01"

        result = GovernmentJobsAgent._verified_cached_item(
            record,
            "20260623T080000Z",
        )

        self.assertIsNone(result)

    def test_government_cache_rejects_invalid_eligibility(self) -> None:
        record = _cached_government_record()
        record["punjab_candidate_eligible"] = "No"
        record["domicile_required"] = "Sindh domicile only"

        result = GovernmentJobsAgent._verified_cached_item(
            record,
            "20260623T080000Z",
        )

        self.assertIsNone(result)

    def test_government_cache_rejects_review_link_and_mock(self) -> None:
        review = _cached_government_record()
        review["is_source_review_link"] = True
        mock = _cached_government_record()
        mock["is_mock"] = True

        self.assertIsNone(
            GovernmentJobsAgent._verified_cached_item(
                review,
                "20260623T080000Z",
            )
        )
        self.assertIsNone(
            GovernmentJobsAgent._verified_cached_item(
                mock,
                "20260623T080000Z",
            )
        )

    def test_government_live_duplicate_replaces_cached_record(self) -> None:
        cached = SourceOpportunity(
            title="Accounts Officer",
            organization="Finance Department",
            location="Pakistan",
            source_link="https://example.gov.pk/jobs/accounts",
            deadline="2099-12-31",
            source_name="FPSC",
            is_cached=True,
            source_status="cached_fallback",
        )
        live = SourceOpportunity(
            title="Accounts Officer",
            organization="Finance Department",
            location="Pakistan",
            source_link="https://example.gov.pk/jobs/accounts",
            deadline="2099-12-31",
            source_name="FPSC",
        )

        results = government_deduplicate([cached, live])

        self.assertEqual(len(results), 1)
        self.assertFalse(results[0].is_cached)

    def test_run_status_reports_cached_government_records_used(self) -> None:
        with TemporaryDirectory() as directory:
            data_directory = Path(directory)
            tasks_path = data_directory / "search_tasks.json"
            JsonStorage(data_directory).write_json(
                tasks_path,
                [
                    {
                        "id": "government",
                        "title": "Government jobs",
                        "task_type": "governmentJob",
                        "keywords": ["Bachelor"],
                        "location": "Pakistan",
                        "level": "Bachelor",
                        "filters": [],
                        "daily_limit": 10,
                        "is_active": True,
                        "created_at": "2026-06-24",
                    }
                ],
            )
            snapshot_path = GovernmentJobsSnapshotStorage(
                data_directory / "cache" / "government_jobs"
            ).write_snapshot(
                "FPSC",
                _snapshot_timestamp(hours_ago=1),
                [_cached_government_record()],
            )
            runner = TaskRunner(data_directory)
            runner.agents[TaskType.GOVERNMENT_JOB].sources = [
                NamedFailingSource("FPSC")
            ]

            runner.run(tasks_path)

            status = json.loads(
                (data_directory / "run_status.json").read_text(
                    encoding="utf-8"
                )
            )
            report = status["source_failures"][0]
            self.assertEqual(report["source_name"], "FPSC")
            self.assertEqual(report["status"], "cached_fallback")
            self.assertTrue(report["fallback_used"])
            self.assertEqual(report["cached_records_used"], 1)
            self.assertTrue(report["cache_snapshot_used"])
            self.assertEqual(
                Path(str(report["cache_snapshot_path"])),
                snapshot_path,
            )
            snapshot_health = status[
                "government_jobs_snapshot_health"
            ]["FPSC"]
            self.assertTrue(snapshot_health["snapshot_exists"])
            self.assertEqual(
                snapshot_health["snapshot_record_count"],
                1,
            )
            self.assertEqual(
                snapshot_health["snapshot_health"],
                "fresh",
            )
            health_summary = status[
                "government_jobs_health_summary"
            ]
            self.assertEqual(health_summary["total_sources"], 1)
            self.assertEqual(health_summary["fresh_sources"], 1)
            self.assertEqual(
                health_summary["usable_snapshot_percentage"],
                100.0,
            )

    def test_run_status_includes_government_source_diversity(self) -> None:
        with TemporaryDirectory() as directory:
            data_directory = Path(directory)
            tasks_path = data_directory / "search_tasks.json"
            JsonStorage(data_directory).write_json(
                tasks_path,
                [
                    {
                        "id": "government",
                        "title": "Government jobs",
                        "task_type": "governmentJob",
                        "keywords": ["Bachelor"],
                        "location": "Pakistan",
                        "level": "Bachelor",
                        "filters": [],
                        "daily_limit": 1,
                        "is_active": True,
                        "created_at": "2026-06-24",
                    }
                ],
            )
            job = SourceOpportunity(
                title="Accounts Officer",
                organization="Finance Department",
                location="Pakistan",
                source_link="https://example.gov.pk/jobs/accounts",
                deadline="2099-12-31",
                required_education="Bachelor degree",
                eligibility_domicile="All Pakistan",
                source_name="FPSC",
            )
            runner = TaskRunner(data_directory)
            runner.agents[TaskType.GOVERNMENT_JOB].sources = [
                StaticSource([job])
            ]

            runner.run(tasks_path)

            status = json.loads(
                (data_directory / "run_status.json").read_text(
                    encoding="utf-8"
                )
            )
            report = status["government_jobs_diversity"]
            self.assertEqual(report["total_results"], 1)
            self.assertEqual(report["results_by_source"], {"FPSC": 1})

    def test_government_accepts_punjab_and_all_pakistan_eligibility(self) -> None:
        for domicile in (
            "Punjab domicile required",
            "All Pakistan candidates may apply",
            "Open merit for Pakistani citizens",
            "Applicants from any province are eligible",
        ):
            result = SourceOpportunity(
                title="Inspector",
                organization="Federal Investigation Agency",
                location="Pakistan",
                source_link="https://example.org/government/inspector",
                required_education="Graduation or equivalent",
                eligibility_domicile=domicile,
                source_name="FIA Careers",
                deadline="2099-12-31",
            )
            self.assertTrue(is_eligible_government_result(result), domicile)

    def test_government_rejects_below_bachelor_only_job(self) -> None:
        result = SourceOpportunity(
            title="Constable",
            organization="Punjab Police",
            location="Punjab, Pakistan",
            source_link="https://example.org/government/constable",
            required_education="Intermediate only",
            eligibility_domicile="Punjab domicile",
            source_name="Punjab Police",
            deadline="2099-12-31",
        )

        self.assertFalse(is_eligible_government_result(result))

    def test_government_rejects_expired_job(self) -> None:
        result = SourceOpportunity(
            title="Assistant",
            organization="Government Department",
            location="Punjab, Pakistan",
            source_link="https://example.org/government/expired",
            required_education="Bachelor degree",
            eligibility_domicile="Punjab domicile",
            source_name="Punjab Jobs Portal",
            deadline="2020-01-01",
        )

        self.assertTrue(is_expired_government_result(result))
        self.assertFalse(is_eligible_government_result(result))

    def test_government_rejects_private_job(self) -> None:
        result = SourceOpportunity(
            title="Management Trainee",
            organization="Example Private Limited",
            location="Lahore, Pakistan",
            source_link="https://example.org/private/trainee",
            required_education="BBA or equivalent qualification",
            eligibility_domicile="Punjab residents may apply",
            source_name="Unverified listing",
            deadline="2099-12-31",
            description="Private sector company recruitment",
        )

        self.assertFalse(is_eligible_government_result(result))

    def test_government_rejects_unverified_aggregator_domicile(self) -> None:
        result = SourceOpportunity(
            title="Mixed Government Jobs in Pakistan",
            organization="Various departments",
            location="Pakistan",
            source_link="https://aggregator.example/jobs/42",
            required_education="Bachelor degree mentioned on listing page",
            eligibility_domicile="",
            source_name="Pakistan Jobs Bank",
            deadline="2099-12-31",
        )

        self.assertFalse(is_eligible_government_result(result))

    def test_government_force_category_is_normalized(self) -> None:
        self.assertEqual(
            force_category("Pakistan Air Force PAF civilian vacancy"),
            "Pakistan Air Force",
        )

    def test_government_listing_rejects_navigation_links(self) -> None:
        page_context = (
            "Current vacancies require a Bachelor's Degree and Punjab domicile."
        )
        self.assertFalse(
            _looks_like_job_link(
                "HOME",
                "https://www.ppsc.gop.pk/Default.aspx",
                page_context,
            )
        )
        self.assertFalse(
            _looks_like_job_link(
                "Jobs Archive",
                "https://www.ppsc.gop.pk/JobsArchive.aspx",
                page_context,
            )
        )
        self.assertTrue(
            _looks_like_job_link(
                "Advertisement for Assistant Director",
                "https://example.gov.pk/advertisement-42.pdf",
                page_context,
            )
        )

    def test_client_leads_fallback_board_is_low_score(self) -> None:
        source = FreelancerProjectsSource()
        source.fetch_text = lambda url: "<html><body>No project cards</body></html>"
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Development", "Computer Vision"],
            location="Remote",
            level="Professional",
            filters=["Freelance Projects"],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-23",
        )

        results = source.collect(client_task)

        self.assertTrue(results)
        self.assertTrue(
            all(
                item.lead_category == ClientLeadCategory.FALLBACK_BOARD
                for item in results
            )
        )
        self.assertTrue(all(item.lead_score <= 45 for item in results))
        self.assertTrue(all(item.search_keyword for item in results))
        self.assertTrue(all(item.manual_action for item in results))
        self.assertTrue(all(item.expected_lead_type for item in results))
        self.assertTrue(
            all("Fallback Board Link" in item.title for item in results)
        )

    def test_guru_is_disabled_from_active_client_sources(self) -> None:
        source_names = [source.source_name for source in client_leads_sources()]

        self.assertNotIn("Guru", source_names)
        self.assertIn("Freelancer Public API", source_names)

    def test_freelancer_public_api_normalizes_valid_project(self) -> None:
        source = FreelancerPublicApiSource()
        payload = {
            "status": "success",
            "result": {
                "projects": [
                    {
                        "id": 12345,
                        "title": "Build Flutter Firebase AI mobile app",
                        "seo_url": "flutter/Build-Flutter-Firebase-AI-App",
                        "submitdate": 1782265461,
                        "preview_description": "Paid fixed-price mobile AI project.",
                        "type": "fixed",
                        "budget": {"minimum": 250, "maximum": 500},
                        "currency": {"sign": "$", "code": "USD"},
                        "location": {"country": {"name": "United States"}},
                        "local": False,
                    }
                ]
            },
        }
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Firebase"],
            location="Remote",
            level="Professional",
            filters=["Freelance"],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-24",
        )

        results = source.parse_payload(payload, client_task)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].platform, "Freelancer.com")
        self.assertEqual(results[0].budget, "$250 - $500")
        self.assertEqual(results[0].budget_type, "Fixed")
        self.assertGreater(results[0].lead_score, 45)

    def test_freelancer_public_api_returns_capped_fallback(self) -> None:
        source = FreelancerPublicApiSource()
        source.fetch_json = lambda url: {
            "status": "success",
            "result": {"projects": []},
        }
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["TensorFlow Lite"],
            location="Remote",
            level="Professional",
            filters=["Freelance"],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-24",
        )

        results = source.collect(client_task)

        self.assertTrue(results)
        self.assertTrue(
            all(
                item.lead_category == ClientLeadCategory.FALLBACK_BOARD
                for item in results
            )
        )
        self.assertTrue(all(item.lead_score <= 45 for item in results))

    def test_client_leads_rejects_freelancer_category_pages(self) -> None:
        source = FreelancerProjectsSource()
        source.fetch_text = lambda url: """
          <a href="/jobs/website-design/">Website Design</a>
        """
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Firebase"],
            location="Remote",
            level="Professional",
            filters=["Freelance Projects"],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-23",
        )

        results = source.collect(client_task)

        self.assertTrue(
            all(
                item.lead_category == ClientLeadCategory.FALLBACK_BOARD
                for item in results
            )
        )

    def test_client_lead_fallback_uses_only_allowed_keywords(self) -> None:
        source = FreelancerProjectsSource()
        source.fetch_text = lambda url: "<html><body>No project cards</body></html>"
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=[
                "WordPress",
                "Website Redesign",
                "Full Stack",
                "SEO",
                "Shopify",
                "Generic Mobile App",
                "Flutter Firebase",
            ],
            location="Remote",
            level="Professional",
            filters=["Freelance Projects"],
            daily_limit=10,
            is_active=True,
            created_at="2026-06-24",
        )

        results = source.collect(client_task)
        forbidden = {
            "wordpress",
            "website redesign",
            "full stack",
            "seo",
            "shopify",
            "generic mobile app",
        }

        self.assertTrue(results)
        self.assertFalse(
            any(item.search_keyword.casefold() in forbidden for item in results)
        )

    def test_real_client_leads_rank_above_fallback_boards(self) -> None:
        source = FreelancerProjectsSource()

        def fetch_text(url: str) -> str:
            if "Flutter+Firebase" in url:
                return """
                  <a href="/projects/flutter/build-flutter-firebase-app">
                    Build Flutter Firebase mobile app
                  </a>
                  Remote urgent fixed price $600 posted today
                """
            return "<html><body>No project cards</body></html>"

        source.fetch_text = fetch_text
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Firebase"],
            location="Remote",
            level="Professional",
            filters=["Freelance Projects"],
            daily_limit=10,
            is_active=True,
            created_at="2026-06-24",
        )

        results = source.collect(client_task)

        self.assertNotEqual(
            results[0].lead_category,
            ClientLeadCategory.FALLBACK_BOARD,
        )
        self.assertGreater(results[0].lead_score, 45)

    def test_client_leads_parses_real_freelancer_project_card(self) -> None:
        source = FreelancerProjectsSource()
        source.fetch_text = lambda url: """
          <a href="/projects/flutter/build-flutter-booking-mobile-app">
            Build Flutter booking mobile app
          </a>
          Remote urgent fixed price $500 posted today
        """
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Development", "Mobile AI Apps"],
            location="Remote",
            level="Professional",
            filters=["Freelance Projects"],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-23",
        )

        results = [
            item
            for item in source.collect(client_task)
            if item.lead_category == ClientLeadCategory.FLUTTER
        ]

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].budget, "$500")
        self.assertIn("Flutter Development", results[0].required_skills)
        self.assertGreaterEqual(results[0].lead_score, 90)

    def test_client_lead_quality_service_scores_real_project_high(self) -> None:
        service = ClientLeadQualityService()
        lead = SourceOpportunity(
            title="Build Flutter booking mobile app",
            organization="Client",
            location="Remote",
            source_link="https://www.freelancer.com/projects/flutter/app",
            posted_date=datetime.now(timezone.utc).isoformat(),
            description="Urgent fixed price Flutter mobile app work.",
            budget="$500",
            budget_type="Fixed",
            platform="Freelancer.com",
            proposal_url="https://www.freelancer.com/projects/flutter/app",
            lead_category="",
        )

        scored = service.score_lead(lead)

        self.assertGreaterEqual(scored.lead_score, 90)
        self.assertIn("Flutter Development", scored.required_skills)

    def test_client_lead_quality_service_removes_noisy_lead(self) -> None:
        service = ClientLeadQualityService()
        lead = SourceOpportunity(
            title="Spanish to English Translation",
            organization="Client",
            location="Remote",
            source_link="https://example.com/translation",
            description="Translation task",
            platform="Truelancer",
            proposal_url="https://example.com/translation",
            lead_category="",
        )

        self.assertFalse(service.is_relevant_lead(lead))

    def test_client_lead_quality_service_downgrades_missing_proposal_url(self) -> None:
        service = ClientLeadQualityService()
        with_url = SourceOpportunity(
            title="Build Flutter Firebase booking app",
            organization="Client",
            location="Remote",
            source_link="https://example.com/project",
            description="Flutter Firebase mobile app with fixed budget.",
            platform="Freelancer.com",
            proposal_url="https://example.com/project",
            lead_category="",
        )
        without_url = SourceOpportunity(
            title=with_url.title,
            organization=with_url.organization,
            location=with_url.location,
            source_link=with_url.source_link,
            description=with_url.description,
            platform=with_url.platform,
            proposal_url="",
            lead_category="",
        )

        self.assertGreater(
            service.score_lead(with_url).lead_score,
            service.score_lead(without_url).lead_score,
        )

    def test_client_lead_requires_title_or_url_skill_match(self) -> None:
        service = ClientLeadQualityService()
        lead = SourceOpportunity(
            title="VBA Developer Needed to Reconcile Inventory",
            organization="Client",
            location="Remote",
            source_link="https://example.com/projects/vba-inventory",
            description=(
                "Nearby page text mentions a different Flutter Firebase project."
            ),
            platform="PeoplePerHour",
            proposal_url="https://example.com/projects/vba-inventory",
        )

        self.assertFalse(service.is_relevant_lead(lead))

    def test_client_lead_assigns_cv_relevant_categories(self) -> None:
        service = ClientLeadQualityService()
        cases = {
            "Build Flutter Firebase delivery app": ClientLeadCategory.FLUTTER,
            "Create mobile AI assistant app": ClientLeadCategory.MOBILE_AI,
            "Computer Vision image recognition project": (
                ClientLeadCategory.COMPUTER_VISION
            ),
            "Machine Learning prediction model": ClientLeadCategory.AI_ML,
            "YOLO object detection with TFLite": ClientLeadCategory.TFLITE_YOLO,
        }

        for title, expected in cases.items():
            lead = SourceOpportunity(
                title=title,
                organization="Client",
                location="Remote",
                source_link="https://example.com/project/" + title.replace(" ", "-"),
                platform="Freelancer.com",
                proposal_url="https://example.com/proposal",
            )
            self.assertEqual(service.classify_lead_category(lead), expected)

    def test_client_lead_rejects_unrelated_target_services(self) -> None:
        service = ClientLeadQualityService()
        for title in (
            "WordPress website redesign",
            "Shopify SEO specialist",
            "Generic full stack developer",
            "Manual QA testing only",
        ):
            lead = SourceOpportunity(
                title=title,
                organization="Client",
                location="Remote",
                source_link="https://example.com/project/" + title.replace(" ", "-"),
                platform="Freelancer.com",
                proposal_url="https://example.com/proposal",
            )
            self.assertFalse(service.is_relevant_lead(lead))

    def test_client_lead_scores_flutter_ai_above_generic_flutter(self) -> None:
        service = ClientLeadQualityService()
        generic = SourceOpportunity(
            title="Build Flutter booking application",
            organization="Client",
            location="Remote",
            source_link="https://example.com/projects/flutter-booking",
            platform="Freelancer.com",
            proposal_url="https://example.com/projects/flutter-booking",
        )
        combined = SourceOpportunity(
            title="Build Flutter AI mobile application",
            organization="Client",
            location="Remote",
            source_link="https://example.com/projects/flutter-ai-mobile",
            platform="Freelancer.com",
            proposal_url="https://example.com/projects/flutter-ai-mobile",
        )

        self.assertGreater(
            service.score_lead(combined).lead_score,
            service.score_lead(generic).lead_score,
        )

    def test_client_lead_dedupes_freelancer_api_project_id(self) -> None:
        service = ClientLeadQualityService()
        first = service.score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase mobile application",
                organization="Freelancer.com Client",
                location="Remote",
                source_link=(
                    "https://www.freelancer.com/projects/flutter/"
                    "build-flutter-firebase/40530001"
                ),
                platform="Freelancer.com",
                proposal_url=(
                    "https://www.freelancer.com/projects/flutter/"
                    "build-flutter-firebase/40530001"
                ),
                platform_project_id="40530001",
                budget="$250 - $500",
            )
        )
        second = service.score_lead(
            SourceOpportunity(
                title="Flutter Firebase app implementation",
                organization="Freelancer.com Client",
                location="Remote",
                source_link=(
                    "https://www.freelancer.com/projects/mobile-app/"
                    "flutter-firebase/40530001"
                ),
                platform="Freelancer.com",
                proposal_url=(
                    "https://www.freelancer.com/projects/mobile-app/"
                    "flutter-firebase/40530001"
                ),
                platform_project_id="40530001",
            )
        )

        results = service.deduplicate_leads([first, second])

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].platform_project_id, "40530001")
        self.assertEqual(
            results[0].dedupe_key,
            "Freelancer.com:id:40530001",
        )

    def test_client_lead_dedupes_api_and_html_same_project(self) -> None:
        service = ClientLeadQualityService()
        api_lead = service.score_lead(
            SourceOpportunity(
                title="Basic Cross-Platform Classifieds Prototype",
                organization="Freelancer.com Client",
                location="Remote",
                source_link=(
                    "https://www.freelancer.com/projects/flutter/"
                    "Basic-Cross-Platform-Classifieds/40535497"
                ),
                description="Detailed API project description.",
                platform="Freelancer.com",
                proposal_url=(
                    "https://www.freelancer.com/projects/flutter/"
                    "Basic-Cross-Platform-Classifieds/40535497"
                ),
                platform_project_id="40535497",
                budget="$30 - $250",
            )
        )
        html_lead = service.score_lead(
            SourceOpportunity(
                title="Basic Cross-Platform Classifieds Prototype",
                organization="Freelancer.com Client",
                location="Remote",
                source_link=(
                    "https://www.freelancer.com/projects/flutter/"
                    "basic-cross-platform-classifieds"
                ),
                platform="Freelancer.com",
                proposal_url=(
                    "https://www.freelancer.com/projects/flutter/"
                    "basic-cross-platform-classifieds"
                ),
            )
        )

        results = service.deduplicate_leads([html_lead, api_lead])

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].platform_project_id, "40535497")
        self.assertEqual(results[0].budget, "$30 - $250")
        self.assertEqual(
            results[0].description,
            "Detailed API project description.",
        )

    def test_fallback_board_never_replaces_real_client_project(self) -> None:
        service = ClientLeadQualityService()
        real = service.score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase mobile app",
                organization="Freelancer.com Client",
                location="Remote",
                source_link="https://www.freelancer.com/projects/flutter/app",
                platform="Freelancer.com",
                proposal_url="https://www.freelancer.com/projects/flutter/app",
                budget="$500",
            )
        )
        fallback = service.score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase mobile app",
                organization="Freelancer.com Project Board",
                location="Remote",
                source_link="https://www.freelancer.com/projects/flutter/app",
                platform="Freelancer.com",
                proposal_url="https://www.freelancer.com/projects/flutter/app",
                search_keyword="Flutter Firebase",
                expected_lead_type=ClientLeadCategory.FLUTTER,
            )
        )

        results = service.deduplicate_leads([fallback, real])

        self.assertEqual(len(results), 1)
        self.assertNotEqual(
            results[0].lead_category,
            ClientLeadCategory.FALLBACK_BOARD,
        )
        self.assertGreater(results[0].lead_score, 45)

    def test_similar_client_projects_are_not_wrongly_merged(self) -> None:
        service = ClientLeadQualityService()
        first = service.score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase delivery application",
                organization="Freelancer.com Client",
                location="Remote",
                source_link="https://www.freelancer.com/projects/flutter/delivery/1",
                platform="Freelancer.com",
                proposal_url="https://www.freelancer.com/projects/flutter/delivery/1",
                platform_project_id="1",
            )
        )
        second = service.score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase booking application",
                organization="Freelancer.com Client",
                location="Remote",
                source_link="https://www.freelancer.com/projects/flutter/booking/2",
                platform="Freelancer.com",
                proposal_url="https://www.freelancer.com/projects/flutter/booking/2",
                platform_project_id="2",
            )
        )

        self.assertEqual(
            len(service.deduplicate_leads([first, second])),
            2,
        )

    def test_client_leads_agent_applies_cross_source_deduplication(self) -> None:
        agent = ClientLeadsAgent()
        duplicate_title = "Flutter Firebase AI mobile app project"
        agent.sources = [
            StaticSource(
                [
                    ClientLeadQualityService().score_lead(
                        SourceOpportunity(
                            title=duplicate_title,
                            organization="Freelancer.com Client",
                            location="Remote",
                            source_link=(
                                "https://www.freelancer.com/projects/flutter/"
                                "flutter-ai-app/99"
                            ),
                            platform="Freelancer.com",
                            proposal_url=(
                                "https://www.freelancer.com/projects/flutter/"
                                "flutter-ai-app/99"
                            ),
                            platform_project_id="99",
                            budget="$500",
                        )
                    ),
                    ClientLeadQualityService().score_lead(
                        SourceOpportunity(
                            title=duplicate_title,
                            organization="Freelancer.com Client",
                            location="Remote",
                            source_link=(
                                "https://www.freelancer.com/projects/flutter/"
                                "flutter-ai-app"
                            ),
                            platform="Freelancer.com",
                            proposal_url=(
                                "https://www.freelancer.com/projects/flutter/"
                                "flutter-ai-app"
                            ),
                        )
                    ),
                ]
            )
        ]
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Firebase"],
            location="Remote",
            level="Professional",
            filters=[],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-24",
        )

        results = agent.execute(client_task)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].platform_project_id, "99")

    def test_truelancer_timeout_returns_safe_fallback_boards(self) -> None:
        source = TruelancerProjectsSource()
        source.fetch_text = lambda url: (_ for _ in ()).throw(
            SourceCollectionError("Truelancer timeout: simulated")
        )
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Firebase"],
            location="Remote",
            level="Professional",
            filters=[],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-24",
        )

        results = source.collect(client_task)

        self.assertTrue(results)
        self.assertEqual(source.last_status, "timeout")
        self.assertTrue(source.fallback_used)
        self.assertTrue(
            all(
                item.lead_category == ClientLeadCategory.FALLBACK_BOARD
                for item in results
            )
        )
        self.assertTrue(all(item.lead_score <= 45 for item in results))

    def test_truelancer_timeout_does_not_stop_other_sources(self) -> None:
        truelancer = TruelancerProjectsSource()
        truelancer.fetch_text = lambda url: (_ for _ in ()).throw(
            SourceCollectionError("Truelancer timeout: simulated")
        )
        real_lead = ClientLeadQualityService().score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase AI mobile app",
                organization="Freelancer.com Client",
                location="Remote",
                source_link="https://www.freelancer.com/projects/flutter/app/77",
                platform="Freelancer.com",
                proposal_url="https://www.freelancer.com/projects/flutter/app/77",
                platform_project_id="77",
                budget="$500",
            )
        )
        agent = ClientLeadsAgent()
        agent.sources = [truelancer, StaticSource([real_lead])]
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Firebase"],
            location="Remote",
            level="Professional",
            filters=[],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-24",
        )

        results = agent.execute(client_task)

        self.assertTrue(
            any(item.platform_project_id == "77" for item in results)
        )
        self.assertIn("Truelancer", agent.failed_sources)
        report = next(
            item
            for item in agent.source_reports
            if item["source_name"] == "Truelancer"
        )
        self.assertEqual(report["status"], "timeout")
        self.assertTrue(report["fallback_used"])

    def test_run_status_reports_truelancer_timeout_fallback(self) -> None:
        with TemporaryDirectory() as directory:
            data_directory = Path(directory)
            tasks_path = data_directory / "search_tasks.json"
            task_payload = [
                {
                    "id": "clients",
                    "title": "Client leads",
                    "task_type": "clientLead",
                    "keywords": ["Flutter Firebase"],
                    "location": "Remote",
                    "level": "Professional",
                    "filters": [],
                    "daily_limit": 5,
                    "is_active": True,
                    "created_at": "2026-06-24",
                }
            ]
            JsonStorage(data_directory).write_json(tasks_path, task_payload)
            truelancer = TruelancerProjectsSource()
            truelancer.fetch_text = lambda url: (_ for _ in ()).throw(
                SourceCollectionError("Truelancer timeout: simulated")
            )
            runner = TaskRunner(data_directory)
            runner.agents[TaskType.CLIENT_LEAD].sources = [truelancer]

            runner.run(tasks_path)

            status = json.loads(
                (data_directory / "run_status.json").read_text(encoding="utf-8")
            )
            self.assertIn("Truelancer", status["failed_sources"])
            self.assertEqual(
                status["source_failures"],
                [
                    {
                        "source_name": "Truelancer",
                        "status": "timeout",
                        "failure_reason": (
                            "Timeout after 2 attempts at 2s each."
                        ),
                        "fallback_used": True,
                    }
                ],
            )

    def test_client_sources_execute_concurrently(self) -> None:
        service = ClientLeadQualityService()
        first = service.score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase delivery app",
                organization="Client A",
                location="Remote",
                source_link="https://example.com/flutter/delivery/1",
                platform="Platform A",
                proposal_url="https://example.com/flutter/delivery/1",
                budget="$500",
            )
        )
        second = service.score_lead(
            SourceOpportunity(
                title="Build Flutter AI assistant app",
                organization="Client B",
                location="Remote",
                source_link="https://example.org/flutter/ai/2",
                platform="Platform B",
                proposal_url="https://example.org/flutter/ai/2",
                budget="$600",
            )
        )
        agent = ClientLeadsAgent()
        agent.sources = [
            DelayedSource("Slow A", 0.2, [first]),
            DelayedSource("Slow B", 0.2, [second]),
        ]
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter"],
            location="Remote",
            level="Professional",
            filters=[],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-24",
        )

        started = time.perf_counter()
        results = agent.execute(client_task)
        elapsed = time.perf_counter() - started

        self.assertEqual(len(results), 2)
        self.assertLess(elapsed, 0.35)

    def test_concurrent_merge_still_deduplicates_sources(self) -> None:
        service = ClientLeadQualityService()
        api_lead = service.score_lead(
            SourceOpportunity(
                title="Flutter Computer Vision mobile application",
                organization="Freelancer.com Client",
                location="Remote",
                source_link=(
                    "https://www.freelancer.com/projects/flutter/cv-app/123"
                ),
                platform="Freelancer.com",
                proposal_url=(
                    "https://www.freelancer.com/projects/flutter/cv-app/123"
                ),
                platform_project_id="123",
                budget="$500",
            )
        )
        html_lead = service.score_lead(
            SourceOpportunity(
                title="Flutter Computer Vision mobile application",
                organization="Freelancer.com Client",
                location="Remote",
                source_link=(
                    "https://www.freelancer.com/projects/flutter/cv-app"
                ),
                platform="Freelancer.com",
                proposal_url=(
                    "https://www.freelancer.com/projects/flutter/cv-app"
                ),
            )
        )
        agent = ClientLeadsAgent()
        agent.sources = [
            DelayedSource("API", 0.01, [api_lead]),
            DelayedSource("HTML", 0.01, [html_lead]),
        ]
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter", "Computer Vision"],
            location="Remote",
            level="Professional",
            filters=[],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-24",
        )

        results = agent.execute(client_task)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].platform_project_id, "123")
        self.assertEqual(results[0].budget, "$500")

    def test_concurrent_final_order_is_stable(self) -> None:
        service = ClientLeadQualityService()
        leads = [
            service.score_lead(
                SourceOpportunity(
                    title=title,
                    organization="Client",
                    location="Remote",
                    source_link=url,
                    platform=platform,
                    proposal_url=url,
                    budget="$500",
                )
            )
            for title, platform, url in (
                (
                    "Flutter Firebase Zebra application",
                    "Platform B",
                    "https://b.example/flutter/zebra",
                ),
                (
                    "Flutter Firebase Alpha application",
                    "Platform A",
                    "https://a.example/flutter/alpha",
                ),
                (
                    "Flutter Firebase Beta application",
                    "Platform A",
                    "https://a.example/flutter/beta",
                ),
            )
        ]
        agent = ClientLeadsAgent()
        agent.sources = [
            DelayedSource("Third", 0.03, [leads[0]]),
            DelayedSource("First", 0.02, [leads[1]]),
            DelayedSource("Second", 0.01, [leads[2]]),
        ]
        client_task = SearchTask(
            id="clients",
            title="Client leads",
            task_type=TaskType.CLIENT_LEAD,
            keywords=["Flutter Firebase"],
            location="Remote",
            level="Professional",
            filters=[],
            daily_limit=5,
            is_active=True,
            created_at="2026-06-24",
        )

        results = agent.execute(client_task)

        self.assertEqual(
            [item.title for item in results],
            [
                "Flutter Firebase Alpha application",
                "Flutter Firebase Beta application",
                "Flutter Firebase Zebra application",
            ],
        )

    def test_flutter_lead_proposal_mentions_flutter(self) -> None:
        service = ClientLeadQualityService()
        lead = service.score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase booking application",
                organization="Client",
                location="Remote",
                source_link="https://example.com/flutter-booking",
                platform="Freelancer.com",
                proposal_url="https://example.com/flutter-booking",
            )
        )

        self.assertIn("Flutter", lead.suggested_message)
        self.assertIn("short chat", lead.suggested_message)

    def test_computer_vision_proposal_mentions_relevant_experience(self) -> None:
        service = ClientLeadQualityService()
        lead = service.score_lead(
            SourceOpportunity(
                title="Computer Vision crop detection project",
                organization="Client",
                location="Remote",
                source_link="https://example.com/computer-vision-project",
                platform="PeoplePerHour",
                proposal_url="https://example.com/computer-vision-project",
            )
        )

        message = lead.suggested_message
        self.assertIn("Cotton Disease Detection", message)
        self.assertIn("TFLite", message)
        self.assertIn("computer vision", message.casefold())

    def test_yolo_tflite_proposal_mentions_matching_tools(self) -> None:
        service = ClientLeadQualityService()
        lead = service.score_lead(
            SourceOpportunity(
                title="YOLO object detection with TensorFlow Lite",
                organization="Client",
                location="Remote",
                source_link="https://example.com/yolo-tflite",
                platform="Freelancer.com",
                proposal_url="https://example.com/yolo-tflite",
            )
        )

        self.assertIn("TFLite", lead.suggested_message)
        self.assertIn("OpenCV", lead.suggested_message)

    def test_fallback_board_has_manual_action_without_proposal(self) -> None:
        service = ClientLeadQualityService()
        fallback = service.score_lead(
            SourceOpportunity(
                title="Fallback Board Link - Workana - Flutter",
                organization="Workana Project Board",
                location="Remote",
                source_link="https://www.workana.com/jobs?query=Flutter",
                platform="Workana",
                proposal_url="https://www.workana.com/jobs?query=Flutter",
                search_keyword="Flutter",
                expected_lead_type=ClientLeadCategory.FLUTTER,
                suggested_message="This must be removed.",
            )
        )

        self.assertEqual(fallback.suggested_message, "")
        self.assertEqual(
            fallback.manual_action,
            service.fallback_manual_action,
        )

    def test_client_proposals_are_short_and_avoid_overclaiming(self) -> None:
        service = ClientLeadQualityService()
        titles = (
            "Senior Flutter Firebase developer needed",
            "Mobile AI application",
            "Computer Vision inspection project",
            "Machine Learning prediction project",
            "YOLO object detection using TFLite",
        )
        for index, title in enumerate(titles):
            lead = service.score_lead(
                SourceOpportunity(
                    title=title,
                    organization="Client",
                    location="Remote",
                    source_link=f"https://example.com/project/{index}/{title}",
                    platform="Freelancer.com",
                    proposal_url=f"https://example.com/project/{index}/{title}",
                )
            )
            message = lead.suggested_message
            self.assertLess(len(message.split()), 90)
            lowered = message.casefold()
            self.assertNotIn("senior", lowered)
            self.assertNotIn("guarantee", lowered)
            self.assertNotIn("many years", lowered)
            self.assertNotIn("expert", lowered)

    def test_real_client_lead_has_short_message(self) -> None:
        service = ClientLeadQualityService()
        lead = service.score_lead(
            SourceOpportunity(
                title="Build Flutter Firebase booking application",
                organization="Client",
                location="Remote",
                source_link="https://example.com/flutter-booking",
                platform="Freelancer.com",
                proposal_url="https://example.com/flutter-booking",
            )
        )

        self.assertTrue(lead.short_message)
        self.assertIn("Flutter", lead.short_message)
        self.assertIn("short chat", lead.short_message)

    def test_fallback_board_short_message_is_empty(self) -> None:
        service = ClientLeadQualityService()
        fallback = service.score_lead(
            SourceOpportunity(
                title="Fallback Board Link - Workana - Flutter",
                organization="Workana Project Board",
                location="Remote",
                source_link="https://www.workana.com/jobs?query=Flutter",
                platform="Workana",
                proposal_url="https://www.workana.com/jobs?query=Flutter",
                search_keyword="Flutter",
                expected_lead_type=ClientLeadCategory.FLUTTER,
                short_message="Remove this message.",
            )
        )

        self.assertEqual(fallback.short_message, "")
        self.assertTrue(fallback.manual_action)

    def test_short_messages_stay_under_limit_without_overclaims(self) -> None:
        service = ClientLeadQualityService()
        titles = (
            "Senior Flutter Firebase developer needed",
            "Mobile AI application",
            "Computer Vision inspection project",
            "Machine Learning prediction project",
            "YOLO object detection using TFLite",
        )
        for index, title in enumerate(titles):
            lead = service.score_lead(
                SourceOpportunity(
                    title=title,
                    organization="Client",
                    location="Remote",
                    source_link=f"https://example.com/short/{index}/{title}",
                    platform="PeoplePerHour",
                    proposal_url=f"https://example.com/short/{index}/{title}",
                )
            )
            message = lead.short_message
            self.assertTrue(message)
            self.assertLess(len(message.split()), 45)
            lowered = message.casefold()
            self.assertNotIn("senior", lowered)
            self.assertNotIn("expert", lowered)
            self.assertNotIn("guarantee", lowered)
            self.assertNotIn("many years", lowered)

    def test_cv_and_yolo_short_messages_include_relevant_terms(self) -> None:
        service = ClientLeadQualityService()
        computer_vision = service.score_lead(
            SourceOpportunity(
                title="Computer Vision inspection application",
                organization="Client",
                location="Remote",
                source_link="https://example.com/cv-inspection",
                platform="Freelancer.com",
                proposal_url="https://example.com/cv-inspection",
            )
        )
        yolo = service.score_lead(
            SourceOpportunity(
                title="YOLO object detection using TFLite",
                organization="Client",
                location="Remote",
                source_link="https://example.com/yolo-tflite-short",
                platform="Freelancer.com",
                proposal_url="https://example.com/yolo-tflite-short",
            )
        )

        self.assertIn("computer vision", computer_vision.short_message.casefold())
        self.assertIn("TFLite", computer_vision.short_message)
        self.assertIn("YOLO", yolo.short_message)
        self.assertIn("TFLite", yolo.short_message)


if __name__ == "__main__":
    unittest.main()
