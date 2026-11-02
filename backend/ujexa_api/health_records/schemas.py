"""Canonical patient-owned health record schemas.

These are client-side/reference domain contracts. In production, the mobile client
validates records before encrypting them. The API stores only encrypted payloads.
"""
from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator


class ProvenanceSource(str, Enum):
    PATIENT = "patient"
    CLINICIAN = "clinician"
    IMPORTED_DOCUMENT = "imported_document"
    DEVICE = "device"
    APPLICATION = "application"


class RecordProvenance(BaseModel):
    model_config = ConfigDict(extra="forbid")
    source: ProvenanceSource
    recorded_by: str | None = Field(default=None, max_length=160)
    organization: str | None = Field(default=None, max_length=160)
    source_document_id: str | None = None
    source_reference: str | None = Field(default=None, max_length=500)
    verification_status: Literal["unverified", "patient_confirmed", "clinician_verified"] = "unverified"
    recorded_at: datetime
    notes: str | None = Field(default=None, max_length=2000)


class PatientProfile(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["patient_profile"] = "patient_profile"
    resource_id: str
    version: int = Field(ge=1)
    preferred_name: str | None = Field(default=None, max_length=100)
    legal_name: str | None = Field(default=None, max_length=160)
    date_of_birth: date | None = None
    sex_at_birth: Literal["female", "male", "intersex", "unknown", "not_recorded"] = "not_recorded"
    gender_identity: str | None = Field(default=None, max_length=100)
    blood_group: Literal["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "unknown", "not_recorded"] = "not_recorded"
    height_cm: float | None = Field(default=None, gt=0, le=300)
    emergency_contact_name: str | None = Field(default=None, max_length=160)
    emergency_contact_relationship: str | None = Field(default=None, max_length=80)
    emergency_contact_phone: str | None = Field(default=None, max_length=40)
    provenance: RecordProvenance


class ConditionStatus(str, Enum):
    ACTIVE = "active"
    RESOLVED = "resolved"
    INACTIVE = "inactive"
    IN_REMISSION = "in_remission"
    UNKNOWN = "unknown"


class ConditionRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["condition"] = "condition"
    resource_id: str
    version: int = Field(ge=1)
    display: str = Field(min_length=1, max_length=200)
    clinical_code_system: str | None = Field(default=None, max_length=100)
    clinical_code: str | None = Field(default=None, max_length=80)
    status: ConditionStatus = ConditionStatus.UNKNOWN
    onset_date: date | None = None
    resolution_date: date | None = None
    notes: str | None = Field(default=None, max_length=4000)
    provenance: RecordProvenance


class AllergyRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["allergy"] = "allergy"
    resource_id: str
    version: int = Field(ge=1)
    substance: str = Field(min_length=1, max_length=200)
    reaction: str | None = Field(default=None, max_length=500)
    severity: Literal["mild", "moderate", "severe", "unknown"] = "unknown"
    status: Literal["active", "inactive", "entered_in_error", "unknown"] = "unknown"
    onset_date: date | None = None
    notes: str | None = Field(default=None, max_length=2000)
    provenance: RecordProvenance


class ProcedureRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["procedure"] = "procedure"
    resource_id: str
    version: int = Field(ge=1)
    display: str = Field(min_length=1, max_length=200)
    performed_date: date | None = None
    organization: str | None = Field(default=None, max_length=160)
    outcome: str | None = Field(default=None, max_length=1000)
    notes: str | None = Field(default=None, max_length=3000)
    provenance: RecordProvenance


class EncounterRecord(BaseModel):
    """A visit/checkup container. It does not itself imply a diagnosis."""
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["encounter"] = "encounter"
    resource_id: str
    version: int = Field(ge=1)
    encounter_type: Literal["routine_checkup", "follow_up", "urgent_care", "emergency", "specialist_visit", "telehealth", "other"]
    status: Literal["planned", "in_progress", "completed", "cancelled", "entered_in_error"]
    started_at: datetime
    ended_at: datetime | None = None
    provider_name: str | None = Field(default=None, max_length=160)
    provider_identifier: str | None = Field(default=None, max_length=120)
    provider_specialty: str | None = Field(default=None, max_length=120)
    department: str | None = Field(default=None, max_length=120)
    visit_mode: Literal["in_person", "remote"] | None = None
    referral_source: str | None = Field(default=None, max_length=200)
    tests_and_results: str | None = Field(default=None, max_length=8000)
    plan_and_instructions: str | None = Field(default=None, max_length=8000)
    next_follow_up_at: datetime | None = None
    organization: str | None = Field(default=None, max_length=160)
    location: str | None = Field(default=None, max_length=200)
    reason: str | None = Field(default=None, max_length=1000)
    clinical_notes: str | None = Field(default=None, max_length=8000)
    follow_up_instructions: str | None = Field(default=None, max_length=4000)
    related_observation_ids: list[str] = Field(default_factory=list, max_length=100)
    provenance: RecordProvenance

    @field_validator("ended_at")
    @classmethod
    def end_not_before_start(cls, value, info):
        start = info.data.get("started_at")
        if value and start and value < start:
            raise ValueError("Encounter end cannot precede start")
        return value


class ObservationRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["observation"] = "observation"
    resource_id: str
    version: int = Field(ge=1)
    code: str = Field(min_length=1, max_length=100)  # e.g. heart_rate, blood_pressure, body_temperature
    display: str = Field(min_length=1, max_length=160)
    status: Literal["preliminary", "final", "amended", "cancelled", "entered_in_error"] = "final"
    effective_at: datetime
    value_quantity: float | None = None
    unit: str | None = Field(default=None, max_length=40)
    value_text: str | None = Field(default=None, max_length=500)
    components: dict[str, float | str] = Field(default_factory=dict)
    body_site: str | None = Field(default=None, max_length=100)
    method: str | None = Field(default=None, max_length=100)
    encounter_id: str | None = None
    notes: str | None = Field(default=None, max_length=2000)
    source_document_id: str | None = None
    source_page: int | None = Field(default=None, ge=1)
    source_evidence: str | None = Field(default=None, max_length=2000)
    provenance: RecordProvenance

    @field_validator("components")
    @classmethod
    def limit_components(cls, value):
        if len(value) > 20:
            raise ValueError("At most 20 observation components are allowed")
        return value


class MedicationStatement(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["medication_statement"] = "medication_statement"
    resource_id: str
    version: int = Field(ge=1)
    medication_name: str = Field(min_length=1, max_length=200)
    strength: str | None = Field(default=None, max_length=80)
    dose: str | None = Field(default=None, max_length=100)
    route: str | None = Field(default=None, max_length=80)
    frequency: str | None = Field(default=None, max_length=120)
    dose_times: list[str] = Field(default_factory=list, max_length=12)
    status: Literal["active", "on_hold", "completed", "stopped", "unknown"] = "unknown"
    start_date: date | None = None
    end_date: date | None = None
    prescriber: str | None = Field(default=None, max_length=160)
    quantity: str | None = Field(default=None, max_length=80)
    refills_remaining: int | None = Field(default=None, ge=0, le=100)
    refill_due_date: date | None = None
    notes: str | None = Field(default=None, max_length=2000)
    source_document_id: str | None = None
    source_page: int | None = Field(default=None, ge=1)
    source_evidence: str | None = Field(default=None, max_length=2000)
    provenance: RecordProvenance

    @field_validator("dose_times")
    @classmethod
    def validate_dose_times(cls, value):
        import re
        if len(value) > 12 or len(set(value)) != len(value):
            raise ValueError("Dose times must be unique and contain at most 12 entries")
        if any(not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", item) for item in value):
            raise ValueError("Dose times must use 24-hour HH:MM format")
        return value


class DocumentFieldAnnotation(BaseModel):
    """Patient-accepted extraction candidate; acceptance is not clinical verification."""
    model_config = ConfigDict(extra="forbid")
    kind: Literal["lab_result_candidate", "medication_instruction_candidate", "document_date_candidate"]
    fields: dict[str, str] = Field(default_factory=dict)
    evidence: str = Field(min_length=1, max_length=2000)
    page: int = Field(ge=1)
    heuristic_confidence: float = Field(ge=0, le=1)
    status: Literal["patient_accepted_unverified"] = "patient_accepted_unverified"


class MedicalDocumentReference(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["document_reference"] = "document_reference"
    resource_id: str
    version: int = Field(ge=1)
    document_type: Literal["lab_report", "prescription", "discharge_summary", "imaging_report", "referral", "vaccination_record", "insurance", "other"]
    title: str = Field(min_length=1, max_length=200)
    media_type: str = Field(min_length=3, max_length=100)
    encrypted_blob_id: str
    document_date: date | None = None
    issuing_organization: str | None = Field(default=None, max_length=160)
    accepted_document_annotations: list[DocumentFieldAnnotation] = Field(default_factory=list, max_length=200)
    provenance: RecordProvenance




class MedicationDoseLog(BaseModel):
    """Patient-reported medication event; not proof of ingestion."""
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["medication_dose_log"] = "medication_dose_log"
    resource_id: str
    version: int = Field(ge=1)
    medication_record_id: str
    event_type: Literal["taken", "missed", "skipped", "unknown"]
    occurred_at: datetime
    dose_taken: str | None = Field(default=None, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)
    provenance: RecordProvenance




class SymptomEntry(BaseModel):
    """Patient-reported symptom episode; not a diagnosis."""
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["symptom_entry"] = "symptom_entry"
    resource_id: str
    version: int = Field(ge=1)
    symptom_name: str = Field(min_length=1, max_length=160)
    body_area: Literal["general", "head", "chest", "abdomen", "back", "muscles", "joints", "skin", "breathing", "digestive", "other"]
    severity: int = Field(ge=1, le=10)
    occurred_at: datetime
    duration: str | None = Field(default=None, max_length=120)
    possible_triggers: list[str] = Field(default_factory=list, max_length=20)
    notes: str | None = Field(default=None, max_length=2000)
    provenance: RecordProvenance


class HealthJournalEntry(BaseModel):
    """Patient-authored journal entry with optional personal ratings."""
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["health_journal"] = "health_journal"
    resource_id: str
    version: int = Field(ge=1)
    entry_text: str = Field(min_length=1, max_length=10000)
    mood_score: int | None = Field(default=None, ge=1, le=5)
    energy_score: int | None = Field(default=None, ge=1, le=5)
    stress_score: int | None = Field(default=None, ge=1, le=5)
    provenance: RecordProvenance



class AppointmentRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["appointment"] = "appointment"
    resource_id: str
    version: int = Field(ge=1)
    title: str = Field(min_length=1, max_length=200)
    appointment_at: datetime
    provider_name: str | None = Field(default=None, max_length=160)
    provider_identifier: str | None = Field(default=None, max_length=120)
    provider_specialty: str | None = Field(default=None, max_length=120)
    department: str | None = Field(default=None, max_length=120)
    visit_mode: Literal["in_person", "remote"] | None = None
    referral_source: str | None = Field(default=None, max_length=200)
    tests_and_results: str | None = Field(default=None, max_length=8000)
    plan_and_instructions: str | None = Field(default=None, max_length=8000)
    next_follow_up_at: datetime | None = None
    organization: str | None = Field(default=None, max_length=160)
    location: str | None = Field(default=None, max_length=200)
    purpose: str | None = Field(default=None, max_length=1000)
    status: Literal["planned", "completed", "cancelled", "rescheduled"] = "planned"
    provenance: RecordProvenance


class LifestyleEntry(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["lifestyle_entry"] = "lifestyle_entry"
    resource_id: str
    version: int = Field(ge=1)
    category: Literal["nutrition", "activity", "sleep", "hydration", "other"]
    occurred_at: datetime
    summary: str = Field(min_length=1, max_length=1000)
    numeric_value: float | None = None
    unit: str | None = Field(default=None, max_length=40)
    provenance: RecordProvenance


class PreventiveCareRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["preventive_care"] = "preventive_care"
    resource_id: str
    version: int = Field(ge=1)
    item: str = Field(min_length=1, max_length=200)
    due_date: date | None = None
    completed_date: date | None = None
    status: Literal["due", "scheduled", "completed", "not_applicable", "unknown"] = "unknown"
    notes: str | None = Field(default=None, max_length=2000)
    provenance: RecordProvenance


class SharingConsentRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")
    resource_type: Literal["sharing_consent"] = "sharing_consent"
    resource_id: str
    version: int = Field(ge=1)
    recipient: str = Field(min_length=1, max_length=200)
    purpose: str = Field(min_length=1, max_length=500)
    included_categories: list[str] = Field(min_length=1, max_length=20)
    granted_at: datetime
    expires_at: datetime | None = None
    status: Literal["active", "revoked", "expired"] = "active"
    provenance: RecordProvenance


# Discriminated union used to publish a canonical JSON Schema for client validators.
from typing import Annotated, Union
from pydantic import TypeAdapter, Field as PydanticField

HealthRecordResource = Annotated[
    Union[
        PatientProfile, ConditionRecord, AllergyRecord, ProcedureRecord,
        EncounterRecord, ObservationRecord, MedicationStatement,
        MedicalDocumentReference, MedicationDoseLog, SymptomEntry, HealthJournalEntry,
        AppointmentRecord, LifestyleEntry, PreventiveCareRecord, SharingConsentRecord,
    ],
    PydanticField(discriminator="resource_type"),
]
HEALTH_RECORD_SCHEMA = TypeAdapter(HealthRecordResource).json_schema()
