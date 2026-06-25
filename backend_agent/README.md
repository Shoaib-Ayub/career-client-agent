# Career Client Agent Backend

This folder contains a standalone Python opportunity collector for the Flutter
application. It reads active search tasks, collects real opportunities from
free public sources, calculates profile match scores, and saves categorized
JSON result files locally. Mock templates remain available only as a fallback
when public sources fail or return no fresh relevant results.

## Requirements

- Python 3.10 or newer
- Internet access for real source collection
- No third-party packages or paid API keys are required

## Run

Always run the backend as a package from the Flutter project root:

```powershell
python -m pip install --requirement backend_agent/requirements.txt
python -m backend_agent.main
```

Choose a freshness window:

```powershell
python -m backend_agent.main --freshness today
python -m backend_agent.main --freshness 24h
python -m backend_agent.main --freshness 7d
python -m backend_agent.main --freshness all
```

The default is `7d`, which hides older results. Use `all` to retain older
results for Flutter's All filter. Results without a published date are retained
because their freshness cannot be verified reliably.

Every saved result is tagged with the shared run timestamp in `found_at` and
one of these `freshness_status` values:

- `today`
- `last_24_hours`
- `last_7_days`
- `older`
- `unknown`

Results are ordered by that freshness priority and then by posted date.
The default `7d` run excludes older results while retaining unknown dates.

Do not run `python backend_agent/main.py`. The backend uses package-relative
imports, so module mode (`-m`) is required.

Run tasks and expose the Flutter API:

```powershell
python -m backend_agent.main --serve
```

Available endpoints:

- `GET /api/jobs`
- `GET /api/scholarships`
- `GET /api/government-jobs`
- `GET /api/client-leads`

For an Android emulator, run Flutter with:

```powershell
flutter run --dart-define=API_ENABLED=true --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For a physical device, replace `10.0.2.2` with the development computer's
local-network IP address. A future production URL uses the same
`API_BASE_URL` define.

## Daily GitHub Actions automation

The workflow at `.github/workflows/daily_agent.yml` runs the backend every day
at **08:00 Pakistan Standard Time**. GitHub schedules use UTC, so the workflow
cron expression is `0 3 * * *` (03:00 UTC).

The workflow:

1. Checks out the repository.
2. Sets up Python 3.10.
3. Installs `backend_agent/requirements.txt`.
4. Runs Python syntax and JSON validation checks.
5. Executes all active search tasks.
6. Validates generated JSON files.
7. Commits changes under `backend_agent/data/` using the GitHub Actions bot.

This uses GitHub-hosted Actions and standard-library public-source collectors.
It does not use paid APIs.

### Run the workflow manually

1. Open the repository on GitHub.
2. Select **Actions**.
3. Select **Daily Career Agent**.
4. Choose **Run workflow**.

You can also run the same agent locally:

```powershell
python -m pip install --requirement backend_agent/requirements.txt
python -m compileall -q backend_agent
python -m unittest discover -s backend_agent/tests -v
python -m backend_agent.main
```

### Change the daily schedule

Edit the cron value in `.github/workflows/daily_agent.yml`:

```yaml
schedule:
  - cron: "0 3 * * *"
```

Cron uses UTC. Pakistan Standard Time is UTC+5, so subtract five hours from the
desired Pakistan run time. For example, 09:30 Pakistan time is `30 4 * * *`.

The repository must allow GitHub Actions to write repository contents. In
GitHub, check **Settings → Actions → General → Workflow permissions** and
select **Read and write permissions** if organization or repository policy
does not already grant it.

Optional paths:

```powershell
python -m backend_agent.main `
  --tasks backend_agent/data/search_tasks.json `
  --profile backend_agent/data/profile.json `
  --data-dir backend_agent/data
```

## Architecture

```text
backend_agent/
  __init__.py                 Python package declaration
  models.py                    Typed tasks and opportunity models
  storage.py                   Atomic JSON reading and writing
  agent_base.py                Shared agent contract and helpers
  jobs_agent.py                Job collection with mock fallback
  scholarships_agent.py        Scholarship collection with mock fallback
  government_jobs_agent.py     Government-job collection with mock fallback
  client_leads_agent.py        Client-lead collection with mock fallback
  sources/
    base_source.py             Shared HTTP, dates, freshness, and deduplication
    rss_source.py              Public RSS parser
    search_source.py           Public JSON search-source contract
    jobs_sources.py            Arbeitnow and Remotive collectors
    scholarship_sources.py     Public scholarship RSS search
    government_jobs_sources.py Public government-job RSS search
    client_leads_sources.py    Public paid-project board collectors
  profile_match_engine.py      Deterministic profile matching
  task_runner.py               Active-task orchestration
  main.py                      Command-line entry point
  api_server.py                Standard-library HTTP API
  data/
    search_tasks.json          Input tasks
    profile.json               Match profile
    jobs/                      Generated job JSON
    scholarships/              Generated scholarship JSON
    government_jobs/           Generated government-job JSON
    client_leads/              Generated client-lead JSON
```

## Task flow

1. `TaskRunner` loads `data/search_tasks.json`.
2. Paused tasks are ignored.
3. Each active task is dispatched to its specialized public-source collectors.
4. Results are normalized, filtered by freshness and task keywords, sorted
   newest-first, and deduplicated by title + organization + source link.
5. If no real result survives, the agent uses its mock fallback.
6. The match engine assigns a score from 0 to 100.
7. Results are written to a timestamped JSON file in the matching category.
8. The task's `last_run_at` value is updated atomically.

## Public sources and collection policy

- Private jobs: LinkedIn public job search, Rozee.pk's publicly embedded
  listing data, Mustakbil public IT listings, BrightSpyre public listings,
  RemoteOK's public API, We Work Remotely RSS, Arbeitnow's public API,
  Remotive's public API, and selected public Greenhouse company career boards
  (currently Google DeepMind, Scale AI, and Careem).
- National Job Portal, Google public search, and TechJuice are monitored as
  requested, but only stable structured job records are saved.
- Scholarships: public RSS search results.
- Government jobs: Punjab Jobs Portal, National Job Portal, PPSC, FPSC, PITB,
  NADRA Careers, NTS, OTS, PTS, STS, Pakistan Jobs Bank, and public government
  department career pages such as the Ministry of IT and Telecommunication.

Government results focus on software, IT, data, AI/ML, database, networking,
systems, programming, MIS, web, and mobile roles. The collector accepts
qualifications such as BS Software Engineering, BS Computer Science, BS IT,
BS AI, BS Data Science, 16 years of education, a bachelor's degree or
equivalent, and relevant computing degrees. It rejects clearly medical-only,
law-only, unrelated engineering, matric/intermediate-only, and domicile rules
restricted exclusively outside Punjab.

Each government result adds:

- `eligibility_domicile`
- `required_education`
- `age_limit`
- `advertisement_link`
- `match_reason`
- `bs_software_engineering_eligible` (`Yes`, `No`, or `Unknown`)
- `punjab_candidate_eligible` (`Yes`, `No`, or `Unknown`)
- `is_mock`

The apply URL remains in `source_link`. Results are deduplicated by title,
department (`organization`), and apply link.
- Client leads: Freelancer.com's public active-project JSON API, public
  Freelancer.com project search pages, PeoplePerHour, Truelancer, and Workana
  public project pages. GitHub issues remain optional and are not enabled by
  default because they are not verified paying work.

Guru is disabled because its former public search route
`/d/jobs/q/{query}/` redirects to a removed page and consistently returns HTTP
404. The agent does not attempt private endpoints or login automation. The
structured Freelancer public project API replaces Guru in the active source
list.

Client leads are deduplicated after all active sources finish. The priority is
platform project ID, normalized proposal URL, platform plus normalized title,
and title plus budget plus platform. When duplicate records are merged, the
agent keeps the higher-scoring real project, preserves a direct project URL,
and fills missing budget, description, skill, and identity fields from the
richer record. Fallback board links never replace real projects.

Truelancer uses a source-specific two-second timeout with one retry. If both
attempts time out, the source immediately returns only the configured
Flutter/AI/computer-vision fallback boards, each capped at score 45. The run
status records the degraded source under both `failed_sources` and
`source_failures`, including its failure reason and whether fallback links
were used. Other client-lead collectors continue normally.

The active client-lead collectors run concurrently with at most four worker
threads: Freelancer Public API, PeoplePerHour, Truelancer, and Workana.
Individual HTTP requests retain their source-specific timeouts and bounded
retry rules. Source failures are isolated and reported after all collectors
finish. Results are then deduplicated and ordered deterministically by lead
score descending, platform, and title, so real projects remain ahead of
fallback boards.

Real client leads include a short category-aware `suggested_message` grounded
in the configured Flutter, Firebase, mobile-AI, computer-vision, YOLO, and
TFLite project experience. Messages remain under 90 words and avoid seniority,
experience-duration, guarantee, or client claims. Computer-vision and
TFLite/YOLO proposals may reference the Cotton Disease Detection project when
relevant. Fallback boards never contain a proposal; they contain only the
manual review instruction in `manual_action`.

Each real client lead also includes a category-aware `short_message` under 45
words for compact Freelancer or PeoplePerHour proposal boxes. It mentions the
most relevant Flutter, Firebase, mobile-AI, computer-vision, YOLO, or TFLite
skill and asks for a short chat. Fallback boards keep `short_message` empty.

Collectors make ordinary public HTTP requests only. They do not log in,
solve CAPTCHAs, bypass robots or access controls, or scrape restricted pages.
Individual source failures are logged as warnings and do not stop other
collectors.

### Private-job matching and ranking

Private jobs are restricted to the requested AI/ML, computer vision, data,
Flutter, junior software, associate, trainee, graduate, and internship tracks.
Clearly senior, staff, principal, lead, manager, or roles requiring more than
two years are excluded.

The ranking order is:

1. Confirmed visa sponsorship or relocation support.
2. Pakistan roles suitable for gaining relevant early-career experience.
3. Tier 1 countries: Germany, UAE, Saudi Arabia, and Qatar.
4. Tier 2 countries: UK, Canada, Australia, Singapore, and Malaysia.
5. Remote-worldwide roles.

Listings explicitly mentioning fresh graduates, entry level, 0–2 years,
internships, trainee or graduate programs are prioritized. Education evidence
accepts BS Software Engineering, BS Computer Science, BS IT, BS AI, a
bachelor's degree in Computer Science or a related field, 16 years of
education, and fresh graduates. Missing evidence remains `Unknown`; it is not
invented.

Every private-job result includes the original compatibility fields plus:

- `company`
- `country_city`
- `remote_status`
- `salary`
- `visa_sponsorship_status`
- `relocation_support_status`
- `fresher_friendly_status`
- `training_provided_status`
- `apply_link`
- `why_this_matches_me`
- `cv_changes_needed`
- `is_mock`

### Private-source limitations

- Indeed, Wellfound, and Glassdoor currently return HTTP 403 to ordinary
  automated public requests. They are reported as failed sources; the agent
  does not evade their access controls.
- LinkedIn collection is limited to its logged-out public jobs search HTML. No
  login, session automation, or private API is used.
- Google's public search page currently exposes no stable structured Google
  Jobs records suitable for reliable extraction, so the page is monitored but
  unstructured snippets are not saved.
- TechJuice's former jobs route is no longer available. Its public site is
  monitored, but news articles are not treated as job vacancies.
- Rozee, Mustakbil, and BrightSpyre may change public HTML or embedded data
  structures without notice.
- Salary, visa, relocation, training, education, and deadline remain empty or
  `Unknown` unless the public source states them.
- Public company boards cover only configured employers and are not a complete
  inventory of every company.

Mock private jobs are generated only when every configured public source
fails. Mock records use `source_name: "Mock fallback"` and `is_mock: true`.

### Government-source limitations

- Portals can change HTML without notice; parser tests cover known public
  layouts, but a changed layout may temporarily return no results.
- NADRA currently rejects ordinary automated requests with HTTP 403. The
  collector records the failure and does not bypass that restriction.
- STS is a JavaScript application. Only information present in its public
  initial HTML is collected; private application APIs are not reverse
  engineered.
- PPSC/FPSC advertisements are sometimes PDF-only. Qualification, age, and
  domicile remain `Unknown` when those details cannot be read from public HTML.
- Testing services publish projects for many fields and provinces. Their
  results are retained only when public text indicates a target IT/computing
  role and does not explicitly exclude Punjab candidates.
- Pakistan Jobs Bank is a public aggregator, not the appointing department.
  Use its advertisement/apply links to confirm every requirement on the
  official source before applying.
- Unknown qualification or domicile values mean “verify the advertisement,”
  never guaranteed eligibility.

Mock government results are generated only when every configured public source
fails. They use `source_name: "Mock fallback"` and `is_mock: true`.

## Output shape

Every generated opportunity contains:

```json
{
  "title": "Flutter Developer",
  "organization": "Global Mobile Labs",
  "location": "Remote",
  "source_link": "https://example.com/jobs/task-id/1",
  "posted_date": "2026-06-19",
  "found_at": "2026-06-23T03:00:00Z",
  "freshness_status": "last_7_days",
  "deadline": "2026-07-19",
  "match_score": 65,
  "skills": ["Flutter", "Dart"],
  "required_skills": ["Flutter", "Dart"],
  "source_name": "Arbeitnow",
  "visa_sponsorship": false,
  "fresher_friendly": true,
  "training_provided": true
}
```

## Extending the backend

Additional permitted sources can be added behind `BaseSource.collect()`.
Keep normalization inside the source layer so task orchestration, matching,
storage, Flutter mapping, and mock fallback behavior remain stable.

To add another government source:

1. Add a `BaseSource` implementation in
   `sources/government_jobs_sources.py`, or configure
   `PublicGovernmentListingSource` for a public HTML listing page.
2. Normalize the department, city/province, qualification, domicile, age,
   deadline, apply link, advertisement link, and posted date.
3. Call `finalize_government_result()` so eligibility and match explanations
   are assigned consistently.
4. Add the source to `government_jobs_sources()`.
5. Add parser and eligibility tests under `backend_agent/tests/`.
6. Never add login automation, CAPTCHA solving, restricted/private endpoints,
   or access-control bypasses.

To add another private-job source:

1. Implement `BaseSource.collect()` or `SearchSource.parse_payload()` in
   `sources/jobs_sources.py`.
2. Use only a documented/public page, feed, RSS document, or public job-board
   API.
3. Normalize the source into `SourceOpportunity`, then call
   `finalize_private_job()`.
4. Add it to `job_sources()`.
5. Add parser, fresher filtering, visa ranking, and fallback tests.
6. Do not automate logins, solve CAPTCHAs, call private browser APIs, or evade
   robots/access restrictions.
