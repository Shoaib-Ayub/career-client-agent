from __future__ import annotations

import re
from dataclasses import replace
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from ..sources.base_source import SourceOpportunity, plain_text


class ClientLeadCategory:
    FALLBACK_BOARD = "Fallback Board Link"
    FLUTTER = "Flutter Client Project"
    MOBILE_AI = "Mobile AI Project"
    COMPUTER_VISION = "Computer Vision Project"
    AI_ML = "AI/ML Project"
    TFLITE_YOLO = "TFLite / YOLO Project"


class ClientLeadQualityService:
    fallback_score_cap = 45
    fallback_manual_action = (
        "Open this board, filter latest projects, and apply only to "
        "Flutter/AI/CV/TFLite projects with clear budget."
    )

    service_skill_patterns = (
        ("Flutter Development", (r"\bflutter\b", r"\bdart\b")),
        ("Firebase", (r"\bfirebase\b", r"\bfirestore\b")),
        (
            "Mobile AI Apps",
            (
                r"\bmobile[-\s]+ai\b",
                r"\bai[-\s]+mobile\b",
                r"\bai[-\s]+app\b",
                r"\bmobile[-\s]+app\b.*\b(?:ai|ml)\b",
                r"\b(?:ai|ml)\b.*\bmobile[-\s]+app\b",
            ),
        ),
        (
            "AI/ML",
            (
                r"\bai\b",
                r"\bml\b",
                r"\bartificial intelligence\b",
                r"\bmachine learning\b",
                r"\bai[-\s]+(?:integration|developer|engineer|project|model)\b",
                r"\bml[-\s]+(?:developer|engineer|project|model)\b",
            ),
        ),
        ("Computer Vision", (r"\bcomputer vision\b", r"\bimage recognition\b")),
        (
            "YOLO / Object Detection",
            (
                r"\byolo(?:v\d+)?\b",
                r"\bobject detection\b",
                r"\broboflow\b",
            ),
        ),
        (
            "TensorFlow / TFLite",
            (
                r"\btensorflow(?:\s+lite)?\b",
                r"\btflite\b",
            ),
        ),
    )

    noise_terms = (
        "wordpress",
        "website redesign",
        "web redesign",
        "full stack",
        "full-stack",
        "shopify",
        "seo",
        "ui/ux",
        "ui ux",
        "ux design",
        "graphic design",
        "content writing",
        "content marketing",
        "digital marketing",
        "social media marketing",
        "vba",
        "data entry",
        "translation",
        "virtual assistant",
        "testing only",
        "manual testing",
        "qa tester",
        "app testing",
        "legal",
        "lawyer",
        "accounting",
    )

    low_competition_terms = (
        "urgent",
        "new",
        "entry",
        "beginner",
        "starter",
        "simple",
        "small",
        "fixed price",
    )

    generic_link_titles = {
        "view & apply",
        "view and apply",
        "apply now",
        "view project",
        "read more",
        "details",
    }

    generic_project_titles = {
        "view & apply",
        "view and apply",
        "apply now",
        "view project",
        "app development",
        "android app development",
        "api developer",
        "java developer",
        "flutter developer",
    }

    vague_terms = ("jobs", "freelancers", "services", "company details")

    def is_relevant_lead(self, raw_lead: SourceOpportunity) -> bool:
        if not raw_lead.title or not raw_lead.proposal_url:
            return False
        title_and_url = self._title_and_url(raw_lead)
        if self.is_noisy(title_and_url):
            return False
        if not self.is_quality_title(raw_lead.title):
            return False
        return bool(self.match_skills(title_and_url))

    def score_lead(self, raw_lead: SourceOpportunity) -> SourceOpportunity:
        raw_lead = self.add_identity(raw_lead)
        category = self.classify_lead_category(raw_lead)
        title_and_url = self._title_and_url(raw_lead)
        skills = self.match_skills(title_and_url)
        reasons = self.explain_why_good_lead(raw_lead)

        if self.is_fallback_board(raw_lead):
            return replace(
                raw_lead,
                lead_category=category,
                lead_score=self.fallback_score_cap,
                required_skills=skills,
                why_good_lead=reasons,
                suggested_message="",
                short_message="",
                manual_action=self.fallback_manual_action,
            )

        score = 0
        if self.is_real_project(raw_lead):
            score += 30
        if raw_lead.budget:
            score += 20
        if raw_lead.proposal_url and raw_lead.proposal_url == raw_lead.source_link:
            score += 20
        if skills:
            score += self.skill_match_score(title_and_url)
        if self.is_recent_or_urgent(raw_lead):
            score += 10

        return replace(
            raw_lead,
            lead_category=category,
            lead_score=min(score, 100),
            required_skills=skills,
            why_good_lead=reasons,
            suggested_message=self.suggested_message(
                raw_lead.title,
                skills,
                raw_lead.platform,
                category,
            ),
            short_message=self.short_message(
                raw_lead.title,
                raw_lead.platform,
                category,
            ),
        )

    def add_identity(self, raw_lead: SourceOpportunity) -> SourceOpportunity:
        platform = self.normalize_platform(raw_lead.platform or raw_lead.source_name)
        proposal_url = raw_lead.proposal_url or raw_lead.source_link
        project_id = raw_lead.platform_project_id or self.extract_project_id(
            platform,
            proposal_url,
        )
        normalized_title = self.normalize_title_for_dedupe(raw_lead.title)
        normalized_url = self.normalize_proposal_url(proposal_url)
        if project_id:
            dedupe_key = f"{platform}:id:{project_id}"
        elif normalized_url:
            dedupe_key = f"url:{normalized_url}"
        else:
            dedupe_key = f"{platform}:title:{normalized_title}"
        return replace(
            raw_lead,
            platform=platform or raw_lead.platform,
            platform_project_id=project_id,
            normalized_title=normalized_title,
            normalized_proposal_url=normalized_url,
            dedupe_key=dedupe_key,
        )

    def deduplicate_leads(
        self,
        leads: list[SourceOpportunity],
    ) -> list[SourceOpportunity]:
        unique: list[SourceOpportunity] = []
        for raw_lead in leads:
            lead = self.add_identity(raw_lead)
            duplicate_index = next(
                (
                    index
                    for index, existing in enumerate(unique)
                    if self.are_duplicates(existing, lead)
                ),
                None,
            )
            if duplicate_index is None:
                unique.append(lead)
                continue
            unique[duplicate_index] = self.merge_duplicates(
                unique[duplicate_index],
                lead,
            )
        return unique

    def are_duplicates(
        self,
        first: SourceOpportunity,
        second: SourceOpportunity,
    ) -> bool:
        first = self.add_identity(first)
        second = self.add_identity(second)
        same_platform = (
            self.normalize_platform(first.platform)
            == self.normalize_platform(second.platform)
        )
        if (
            same_platform
            and first.platform_project_id
            and first.platform_project_id == second.platform_project_id
        ):
            return True
        if (
            first.normalized_proposal_url
            and first.normalized_proposal_url == second.normalized_proposal_url
        ):
            return True
        if (
            same_platform
            and first.normalized_title
            and first.normalized_title == second.normalized_title
        ):
            return True
        return bool(
            same_platform
            and first.normalized_title
            and first.normalized_title == second.normalized_title
            and first.budget
            and first.budget == second.budget
        )

    def merge_duplicates(
        self,
        first: SourceOpportunity,
        second: SourceOpportunity,
    ) -> SourceOpportunity:
        first = self.add_identity(first)
        second = self.add_identity(second)
        winner, other = sorted(
            (first, second),
            key=self._dedupe_priority,
            reverse=True,
        )
        merged_skills = self._merge_list(
            winner.required_skills,
            other.required_skills,
        )
        merged_reasons = self._merge_list(
            winner.why_good_lead,
            other.why_good_lead,
        )
        return self.add_identity(
            replace(
                winner,
                description=self._richer_text(
                    winner.description,
                    other.description,
                ),
                budget=winner.budget or other.budget,
                budget_type=(
                    winner.budget_type
                    if winner.budget_type != "Unknown"
                    else other.budget_type
                ),
                country=winner.country or other.country,
                location=winner.location or other.location,
                posted_date=winner.posted_date or other.posted_date,
                required_skills=merged_skills,
                why_good_lead=merged_reasons,
                suggested_message=(
                    winner.suggested_message or other.suggested_message
                ),
                short_message=winner.short_message or other.short_message,
                platform_project_id=(
                    winner.platform_project_id or other.platform_project_id
                ),
            )
        )

    def normalize_title_for_dedupe(self, title: str) -> str:
        normalized = plain_text(title).casefold()
        normalized = re.sub(r"[^a-z0-9]+", " ", normalized)
        return re.sub(r"\s+", " ", normalized).strip()

    def normalize_proposal_url(self, url: str) -> str:
        if not url:
            return ""
        parts = urlsplit(url.strip())
        host = parts.netloc.casefold().removeprefix("www.")
        path = re.sub(r"/+", "/", parts.path).rstrip("/").casefold()
        retained_query = [
            (key.casefold(), value.casefold())
            for key, value in parse_qsl(parts.query, keep_blank_values=False)
            if key.casefold() not in {
                "utm_source",
                "utm_medium",
                "utm_campaign",
                "utm_content",
                "ref",
                "source",
            }
        ]
        return urlunsplit(
            (
                "https" if host else "",
                host,
                path,
                urlencode(sorted(retained_query)),
                "",
            )
        )

    def normalize_platform(self, platform: str) -> str:
        normalized = plain_text(platform).casefold()
        aliases = {
            "freelancer public api": "Freelancer.com",
            "freelancer": "Freelancer.com",
            "freelancer.com": "Freelancer.com",
            "peopleperhour": "PeoplePerHour",
            "truelancer": "Truelancer",
            "workana": "Workana",
        }
        return aliases.get(normalized, plain_text(platform))

    def extract_project_id(self, platform: str, url: str) -> str:
        if not url:
            return ""
        normalized_platform = self.normalize_platform(platform)
        path = urlsplit(url).path.rstrip("/")
        patterns = {
            "Freelancer.com": (
                r"/projects/(?:[^/]+/)+(\d+)$",
                r"/projects/[^/]+-(\d+)$",
            ),
            "PeoplePerHour": (r"-(\d+)$",),
            "Truelancer": (r"-(\d+)$", r"/(\d+)$"),
            "Workana": (r"/(\d+)$",),
        }
        for pattern in patterns.get(normalized_platform, (r"/(\d+)$",)):
            match = re.search(pattern, path, flags=re.IGNORECASE)
            if match:
                return match.group(1)
        return ""

    def normalize_title(self, title: str, url: str, platform: str) -> str:
        clean = plain_text(title)
        if self.is_generic_link_title(clean):
            derived = self.title_from_url(url)
            if derived:
                return derived
        return clean

    def classify_lead_category(self, raw_lead: SourceOpportunity) -> str:
        if self.is_fallback_board(raw_lead):
            return ClientLeadCategory.FALLBACK_BOARD
        return self.expected_lead_type(raw_lead)

    def expected_lead_type(self, raw_lead: SourceOpportunity) -> str:
        text = self._title_and_url(raw_lead)
        lowered = text.casefold()
        has_flutter = bool(re.search(r"\b(?:flutter|dart)\b", text, re.I))
        has_mobile = bool(
            re.search(r"\b(?:mobile|android|ios|app)\b", text, re.I)
        )
        has_ai = bool(
            re.search(
                r"\b(?:ai|ml|artificial intelligence|machine learning)\b",
                text,
                re.I,
            )
        )
        if re.search(
            r"\b(?:tflite|tensorflow(?:\s+lite)?|yolo(?:v\d+)?|"
            r"object detection|roboflow)\b",
            text,
            re.I,
        ):
            return ClientLeadCategory.TFLITE_YOLO
        if has_mobile and has_ai:
            return ClientLeadCategory.MOBILE_AI
        if "computer vision" in lowered or "image recognition" in lowered:
            return ClientLeadCategory.COMPUTER_VISION
        if has_flutter:
            return ClientLeadCategory.FLUTTER
        return ClientLeadCategory.AI_ML

    def explain_why_good_lead(self, raw_lead: SourceOpportunity) -> list[str]:
        category = self.classify_lead_category(raw_lead)
        if self.is_fallback_board(raw_lead):
            return [
                (
                    f"{raw_lead.platform} board for the exact "
                    f"'{raw_lead.search_keyword}' search category."
                ),
                (
                    "Useful when the collector finds too few clean, direct "
                    f"project cards for {raw_lead.expected_lead_type}."
                ),
            ]

        reasons = list(raw_lead.why_good_lead)
        if self.is_real_project(raw_lead):
            reasons.append(
                "Comes from a freelance marketplace where buyers post paid work."
            )
        if raw_lead.budget:
            reasons.append(f"Budget is visible: {raw_lead.budget}.")
        if raw_lead.proposal_url and raw_lead.proposal_url == raw_lead.source_link:
            reasons.append("Has a direct proposal or project URL.")
        skills = self.match_skills(self._title_and_url(raw_lead))
        if skills:
            reasons.append(f"Matches requested skills: {', '.join(skills[:3])}.")
        if self.is_recent_or_urgent(raw_lead):
            reasons.append("Recent or urgent lead.")
        if not reasons:
            reasons.append("Matches one of the requested paid service categories.")
        return reasons[:5]

    def match_skills(self, text: str) -> list[str]:
        sanitized = re.sub(
            r"\b(no|without)\s+ai\b",
            "",
            text,
            flags=re.IGNORECASE,
        )
        matched: list[str] = []
        for skill, patterns in self.service_skill_patterns:
            if any(
                re.search(pattern, sanitized, flags=re.IGNORECASE)
                for pattern in patterns
            ):
                matched.append(skill)
        return matched

    def skill_match_score(self, text: str) -> int:
        lowered = text.casefold()
        has_flutter = bool(re.search(r"\b(?:flutter|dart)\b", text, re.I))
        has_firebase = bool(re.search(r"\b(?:firebase|firestore)\b", text, re.I))
        has_mobile = bool(
            re.search(r"\b(?:mobile|android|ios|app)\b", text, re.I)
        )
        has_ai = bool(
            re.search(
                r"\b(?:ai|ml|artificial intelligence|machine learning)\b",
                text,
                re.I,
            )
        )
        if (
            (has_flutter and (has_ai or has_firebase))
            or (has_mobile and has_ai)
            or re.search(
                r"\b(?:computer vision|object detection|yolo(?:v\d+)?|"
                r"tensorflow lite|tflite)\b",
                lowered,
                re.I,
            )
        ):
            return 30
        return 20

    def is_paid_likely(self, raw_lead: SourceOpportunity) -> bool:
        text = self._searchable(raw_lead).casefold()
        return bool(raw_lead.budget) or any(
            term in text for term in ("budget", "fixed price", "hourly", "paid")
        )

    def is_noisy(self, text: str) -> bool:
        lowered = text.casefold()
        return any(term in lowered for term in self.noise_terms)

    def is_fallback_board(self, raw_lead: SourceOpportunity) -> bool:
        return "Project Board" in raw_lead.organization

    def is_real_project(self, raw_lead: SourceOpportunity) -> bool:
        return (
            not self.is_fallback_board(raw_lead)
            and raw_lead.platform not in {"Business Outreach Planner", "GitHub Issues"}
        )

    def is_quality_title(self, title: str) -> bool:
        clean = plain_text(title)
        lowered = clean.casefold()
        if len(clean) < 12 or len(clean) > 120:
            return False
        if self.is_noisy(clean):
            return False
        if lowered in self.generic_project_titles:
            return False
        return not any(term in lowered for term in self.vague_terms)

    def is_generic_link_title(self, title: str) -> bool:
        return plain_text(title).casefold() in self.generic_link_titles

    def title_from_url(self, url: str) -> str:
        slug = url.rstrip("/").rsplit("/", maxsplit=1)[-1]
        slug = re.sub(r"[-_]\d+$", "", slug)
        slug = re.sub(r"\.(html|php)$", "", slug, flags=re.IGNORECASE)
        words = [word for word in re.split(r"[-_]+", slug) if word]
        if len(words) < 2:
            return ""
        return " ".join(words).title()

    def is_recent_or_urgent(self, raw_lead: SourceOpportunity) -> bool:
        text = raw_lead.description.casefold()
        return bool(raw_lead.posted_date) or any(
            term in text for term in self.low_competition_terms
        )

    def suggested_message(
        self,
        title: str,
        skills: list[str],
        platform: str,
        category: str = "",
    ) -> str:
        if category == ClientLeadCategory.FALLBACK_BOARD:
            return ""

        context = self._proposal_context(title)

        details = {
            ClientLeadCategory.FLUTTER: (
                "I develop Flutter apps and work with Firebase for authentication, "
                "data, storage, and app features."
            ),
            ClientLeadCategory.MOBILE_AI: (
                "I build Flutter apps and can integrate AI models into practical "
                "mobile workflows."
            ),
            ClientLeadCategory.COMPUTER_VISION: (
                "I built a Cotton Disease Detection app using Flutter, Firebase, "
                "TFLite, OpenCV, and Roboflow, so this computer vision work fits "
                "my project experience."
            ),
            ClientLeadCategory.AI_ML: (
                "I am growing my AI/ML skills and have hands-on experience "
                "integrating trained models into Flutter applications."
            ),
            ClientLeadCategory.TFLITE_YOLO: (
                "I have project experience with TFLite, computer vision, OpenCV, "
                "Roboflow, and mobile model integration, including a Cotton "
                "Disease Detection app."
            ),
        }
        detail = details.get(
            category,
            "I can help with Flutter development and mobile AI integration.",
        )
        return (
            f"Hello, I saw your “{context}” project on {platform}. "
            f"{detail} I would be glad to understand the requirements and suggest "
            "a clear implementation approach. Could we have a short chat about "
            "the scope and expected outcome?"
        )

    def short_message(
        self,
        title: str,
        platform: str,
        category: str,
    ) -> str:
        if category == ClientLeadCategory.FALLBACK_BOARD:
            return ""
        context = self._proposal_context(title, max_length=42)
        skill_text = {
            ClientLeadCategory.FLUTTER: "Flutter and Firebase development",
            ClientLeadCategory.MOBILE_AI: "Flutter and mobile AI integration",
            ClientLeadCategory.COMPUTER_VISION: (
                "computer vision, TFLite, and OpenCV"
            ),
            ClientLeadCategory.AI_ML: "AI/ML and Flutter model integration",
            ClientLeadCategory.TFLITE_YOLO: (
                "YOLO, TFLite, and mobile model integration"
            ),
        }.get(category, "Flutter and mobile AI development")
        return (
            f"Hello, I saw your “{context}” project on {platform}. "
            f"I can help with {skill_text}. Could we have a short chat about "
            "the scope and requirements?"
        )

    def _proposal_context(self, title: str, max_length: int = 65) -> str:
        context = plain_text(title)
        context = re.sub(
            r"\b(?:senior|expert|guaranteed?|guarantee)\b",
            "",
            context,
            flags=re.IGNORECASE,
        )
        context = re.sub(r"\s+", " ", context).strip(" -:")
        if len(context) > max_length:
            context = context[: max_length - 3].rstrip() + "..."
        return context

    def _searchable(self, raw_lead: SourceOpportunity) -> str:
        return " ".join(
            [
                raw_lead.title,
                raw_lead.description,
                raw_lead.source_link,
                raw_lead.platform,
                *raw_lead.required_skills,
            ]
        )

    def _title_and_url(self, raw_lead: SourceOpportunity) -> str:
        return f"{raw_lead.title} {raw_lead.source_link} {raw_lead.proposal_url}"

    def _dedupe_priority(self, lead: SourceOpportunity) -> tuple[int, ...]:
        return (
            0 if self.is_fallback_board(lead) else 1,
            lead.lead_score,
            1 if lead.platform_project_id else 0,
            1 if lead.proposal_url and "/projects/" in lead.proposal_url else 0,
            1 if lead.budget else 0,
            len(lead.description),
            len(lead.required_skills),
        )

    def _merge_list(self, first: list[str], second: list[str]) -> list[str]:
        merged: list[str] = []
        seen: set[str] = set()
        for value in [*first, *second]:
            key = value.casefold()
            if not value or key in seen:
                continue
            seen.add(key)
            merged.append(value)
        return merged

    def _richer_text(self, first: str, second: str) -> str:
        return max((first, second), key=len)
