from datetime import datetime, timezone, timedelta
import pytest
from pydantic import ValidationError

from ujexa_api.health_records.schemas import (
    RecordProvenance, ProvenanceSource, PatientProfile, ConditionRecord,
    AllergyRecord, ProcedureRecord, EncounterRecord, ObservationRecord,
    MedicationStatement, MedicalDocumentReference, MedicationDoseLog,
)

def provenance():
    return RecordProvenance(
        source=ProvenanceSource.PATIENT,
        verification_status="patient_confirmed",
        recorded_at=datetime.now(timezone.utc),
    )

def test_patient_profile_schema_accepts_optional_unknown_values():
    profile = PatientProfile(
        resource_id="profile-1", version=1, blood_group="unknown",
        provenance=provenance(),
    )
    assert profile.resource_type == "patient_profile"
    assert profile.date_of_birth is None

def test_condition_allergy_and_procedure_have_explicit_provenance():
    condition = ConditionRecord(
        resource_id="condition-1", version=1, display="Asthma",
        status="active", provenance=provenance(),
    )
    allergy = AllergyRecord(
        resource_id="allergy-1", version=1, substance="Peanuts",
        reaction="Hives", severity="moderate", provenance=provenance(),
    )
    procedure = ProcedureRecord(
        resource_id="procedure-1", version=1, display="Appendectomy",
        provenance=provenance(),
    )
    assert condition.provenance.source == "patient"
    assert allergy.severity == "moderate"
    assert procedure.resource_type == "procedure"

def test_checkup_encounter_validates_chronology_and_relations():
    start = datetime.now(timezone.utc)
    encounter = EncounterRecord(
        resource_id="enc-1", version=1, encounter_type="routine_checkup",
        status="completed", started_at=start, ended_at=start + timedelta(minutes=30),
        related_observation_ids=["obs-1"], provenance=provenance(),
    )
    assert encounter.status == "completed"
    with pytest.raises(ValidationError):
        EncounterRecord(
            resource_id="enc-2", version=1, encounter_type="routine_checkup",
            status="completed", started_at=start, ended_at=start - timedelta(minutes=1),
            provenance=provenance(),
        )

def test_observation_supports_quantity_components_and_units():
    observation = ObservationRecord(
        resource_id="obs-1", version=1, code="blood_pressure",
        display="Blood pressure", effective_at=datetime.now(timezone.utc),
        components={"systolic": 118, "diastolic": 76}, unit="mmHg",
        provenance=provenance(),
    )
    assert observation.components["systolic"] == 118

def test_medication_and_document_reference_are_structured():
    medication = MedicationStatement(
        resource_id="med-1", version=1, medication_name="Amlodipine",
        strength="5 mg", frequency="once daily", status="active",
        provenance=provenance(),
    )
    document = MedicalDocumentReference(
        resource_id="doc-1", version=1, document_type="lab_report",
        title="Full blood count", media_type="application/pdf",
        encrypted_blob_id="blob-123", provenance=provenance(),
    )
    assert medication.status == "active"
    assert document.encrypted_blob_id == "blob-123"

def test_unexpected_fields_are_rejected():
    with pytest.raises(ValidationError):
        ConditionRecord(
            resource_id="condition-1", version=1, display="Hypertension",
            diagnosis="AI inferred", provenance=provenance(),
        )


def test_medication_dose_log_requires_link_and_supported_event():
    log = MedicationDoseLog(
        resource_id="dose-1", version=1, medication_record_id="med-1",
        event_type="taken", occurred_at=datetime.now(timezone.utc),
        provenance=provenance(),
    )
    assert log.resource_type == "medication_dose_log"
    assert log.event_type == "taken"
    with pytest.raises(ValidationError):
        MedicationDoseLog(
            resource_id="dose-2", version=1, medication_record_id="med-1",
            event_type="maybe", occurred_at=datetime.now(timezone.utc),
            provenance=provenance(),
        )

def test_medication_refill_fields_are_bounded():
    medication = MedicationStatement(
        resource_id="med-2", version=1, medication_name="Example",
        refills_remaining=2, quantity="30 tablets",
        provenance=provenance(),
    )
    assert medication.refills_remaining == 2
    with pytest.raises(ValidationError):
        MedicationStatement(
            resource_id="med-3", version=1, medication_name="Example",
            refills_remaining=-1, provenance=provenance(),
        )


def test_medication_dose_times_are_explicit_and_validated():
    medication = MedicationStatement(
        resource_id="med-times-1", version=1, medication_name="Example",
        dose="1 tablet", frequency="twice daily", dose_times=["08:00", "20:00"],
        provenance=provenance(),
    )
    assert medication.dose_times == ["08:00", "20:00"]
    with pytest.raises(ValidationError):
        MedicationStatement(
            resource_id="med-times-2", version=1, medication_name="Example",
            dose_times=["8am"], provenance=provenance(),
        )
    with pytest.raises(ValidationError):
        MedicationStatement(
            resource_id="med-times-3", version=1, medication_name="Example",
            dose_times=["08:00", "08:00"], provenance=provenance(),
        )



def test_symptom_entry_requires_valid_severity_and_preserves_patient_provenance():
    from ujexa_api.health_records.schemas import SymptomEntry
    from datetime import datetime, timezone
    base = {
        "resource_id": "symptom-1", "version": 1, "symptom_name": "Headache",
        "body_area": "head", "severity": 7,
        "occurred_at": datetime.now(timezone.utc),
        "possible_triggers": ["poor sleep"],
        "provenance": {"source": "patient", "verification_status": "unverified", "recorded_at": datetime.now(timezone.utc)},
    }
    record = SymptomEntry(**base)
    assert record.resource_type == "symptom_entry"
    assert record.provenance.verification_status == "unverified"
    import pytest
    with pytest.raises(ValidationError):
        SymptomEntry(**{**base, "severity": 11})


def test_health_journal_scores_are_bounded():
    from ujexa_api.health_records.schemas import HealthJournalEntry
    from datetime import datetime, timezone
    base = {
        "resource_id": "journal-1", "version": 1, "entry_text": "Felt tired today.",
        "mood_score": 3, "energy_score": 2, "stress_score": 4,
        "provenance": {"source": "patient", "verification_status": "unverified", "recorded_at": datetime.now(timezone.utc)},
    }
    assert HealthJournalEntry(**base).energy_score == 2
    import pytest
    with pytest.raises(ValidationError):
        HealthJournalEntry(**{**base, "mood_score": 0})


def test_document_annotation_schema_preserves_patient_confirmation_provenance():
    from ujexa_api.health_records.schemas import DocumentFieldAnnotation
    item = DocumentFieldAnnotation(
        kind="lab_result_candidate",
        fields={"test_name":"Haemoglobin","value":"13.5 g/dL"},
        evidence="Haemoglobin 13.5 g/dL",
        page=2,
        heuristic_confidence=0.55,
        status="patient_accepted_unverified",
    )
    assert item.page == 2
    assert item.status == "patient_accepted_unverified"


def test_document_annotation_rejects_invalid_page_and_confidence():
    from pydantic import ValidationError
    from ujexa_api.health_records.schemas import DocumentFieldAnnotation
    with pytest.raises(ValidationError):
        DocumentFieldAnnotation(
            kind="lab_result_candidate", fields={}, evidence="result", page=0,
            heuristic_confidence=0.5,
        )
    with pytest.raises(ValidationError):
        DocumentFieldAnnotation(
            kind="lab_result_candidate", fields={}, evidence="result", page=1,
            heuristic_confidence=1.5,
        )


def test_stage22_29_domain_schemas_accept_new_resources():
    from datetime import datetime, timezone
    from ujexa_api.health_records.schemas import AppointmentRecord, LifestyleEntry, PreventiveCareRecord, SharingConsentRecord
    provenance = {"source":"patient","verification_status":"unverified","recorded_at":datetime.now(timezone.utc)}
    assert AppointmentRecord(resource_id="a",version=1,title="Review",appointment_at=datetime.now(timezone.utc),provenance=provenance)
    assert LifestyleEntry(resource_id="l",version=1,category="sleep",occurred_at=datetime.now(timezone.utc),summary="Slept 7 hours",provenance=provenance)
    assert PreventiveCareRecord(resource_id="p",version=1,item="Dental checkup",status="due",provenance=provenance)
    assert SharingConsentRecord(resource_id="s",version=1,recipient="Clinic",purpose="Consultation",included_categories=["allergies"],granted_at=datetime.now(timezone.utc),provenance=provenance)


def test_stage22_29_sharing_consent_requires_scope():
    from datetime import datetime, timezone
    from pydantic import ValidationError
    from ujexa_api.health_records.schemas import SharingConsentRecord
    with pytest.raises(ValidationError):
        SharingConsentRecord(resource_id="s",version=1,recipient="Clinic",purpose="Consultation",included_categories=[],granted_at=datetime.now(timezone.utc),provenance={"source":"patient","recorded_at":datetime.now(timezone.utc)})
