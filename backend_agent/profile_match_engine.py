from __future__ import annotations

from dataclasses import dataclass, field

from .models import Opportunity


@dataclass(slots=True)
class Profile:
    skills: list[str] = field(default_factory=list)
    education: str = ""
    location: str = ""
    preferred_countries: list[str] = field(default_factory=list)
    preferred_job_types: list[str] = field(default_factory=list)

    @classmethod
    def default(cls) -> "Profile":
        """Default Shoaib profile used when no user profile is configured."""

        return cls(
            skills=[
                "Flutter",
                "Dart",
                "Firebase",
                "Python",
                "AI",
                "Machine Learning",
                "Computer Vision",
                "YOLO",
                "TensorFlow Lite",
                "TFLite",
                "OpenCV",
                "Roboflow",
            ],
            education="BS Software Engineering",
            location="Pakistan",
            preferred_countries=[
                "Pakistan",
                "Germany",
                "UAE",
                "Saudi Arabia",
                "Qatar",
                "UK",
                "Canada",
                "Australia",
                "Singapore",
                "Malaysia",
                "Remote",
            ],
            preferred_job_types=[
                "Fresher",
                "Entry Level",
                "Internship",
                "Trainee",
                "Remote",
                "Full-time",
                "Freelance",
            ],
        )

    @classmethod
    def from_dict(cls, data: dict[str, object]) -> "Profile":
        profile = cls(
            skills=[str(value) for value in data.get("skills", [])],
            education=str(data.get("education", "")),
            location=str(data.get("location", "")),
            preferred_countries=[
                str(value) for value in data.get("preferred_countries", data.get("preferredCountries", []))
            ],
            preferred_job_types=[
                str(value) for value in data.get("preferred_job_types", data.get("preferredJobTypes", []))
            ],
        )
        return profile.or_default()

    def is_empty(self) -> bool:
        return not any(
            [
                self.skills,
                self.education.strip(),
                self.location.strip(),
                self.preferred_countries,
                self.preferred_job_types,
            ]
        )

    def or_default(self) -> "Profile":
        return self.default() if self.is_empty() else self


class ProfileMatchEngine:
    SKILL_WEIGHT = 70
    LOCATION_WEIGHT = 20
    VISA_WEIGHT = 10

    def calculate(self, opportunity: Opportunity, profile: Profile) -> int:
        profile_skills = {self._normalize(value) for value in profile.skills}
        required_skills = {self._normalize(value) for value in opportunity.skills}
        skill_score = (
            len(profile_skills & required_skills) / len(required_skills)
            if required_skills
            else 1.0
        )

        preferred_locations = {
            self._normalize(profile.location),
            *(self._normalize(value) for value in profile.preferred_countries),
        }
        location_score = (
            1.0
            if any(
                value and value in self._normalize(opportunity.location)
                for value in preferred_locations
            )
            or any(
                value in self._normalize(opportunity.location)
                for value in ("remote", "worldwide")
            )
            else 0.0
        )
        visa_score = 1.0 if opportunity.visa_sponsorship else 0.0

        score = (
            skill_score * self.SKILL_WEIGHT
            + location_score * self.LOCATION_WEIGHT
            + visa_score * self.VISA_WEIGHT
        )
        return max(0, min(100, round(score)))

    def apply(self, opportunities: list[Opportunity], profile: Profile) -> None:
        for opportunity in opportunities:
            opportunity.match_score = self.calculate(opportunity, profile)

    @staticmethod
    def _normalize(value: str) -> str:
        return value.strip().casefold()
