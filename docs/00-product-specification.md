# Ujexa Health — Stage 00 Product Specification

**Version:** 1.0 · **Status:** Baseline for implementation · **Product:** Ujexa Health

## 1. Product definition
Ujexa Health is a patient-owned, privacy-first health information platform. It helps people collect, understand, manage and securely share their health information while keeping healthcare professionals as the clinical authority.

### Product principles
- Patient control over ordinary storage, synchronization and sharing.
- Privacy by design; sensitive records are encrypted locally before cloud transmission.
- Continuity through encrypted backup and secure device recovery.
- Clinical humility: no autonomous diagnosis, prescribing or treatment changes.
- Provenance: patient-reported, device-imported, document-extracted and clinician-verified data remain distinguishable.
- Offline resilience for essential records.
- Interoperability through appropriate HL7 FHIR resources.

## 2. Users and roles
| Role | Scope |
|---|---|
| Patient | Own records, journal, medication, checkups, measurements, reports, privacy and sharing |
| Caregiver | Only patient- or guardian-delegated information and tasks |
| Healthcare professional | Verified, relevant information and authenticated clinical contributions |
| Emergency responder | Minimal emergency summary through governed access |
| Platform administrator | Operations without routine plaintext access to patient records |

## 3. Stage 01 scope
### Included
- Responsive patient application shell.
- Approved dashboard visual direction.
- Header, greeting, daily overview, metric tiles, medication/activity cards.
- Quick actions and central Add Menu.
- Home, Records, Insights and Profile navigation.
- Contextual record-entry forms, including first-class checkup logging.
- Design tokens, reusable components, accessibility and reduced-motion foundations.
- Synthetic demonstration content only.

### Excluded from Stage 01
- Production authentication or identity verification.
- Real medical record persistence, cloud sync or encryption implementation.
- Real medication reminders or clinical alerts.
- OCR, AI, clinical recommendations or diagnostic functionality.
- Clinician portal and emergency disclosure.
- Any use of demonstration metrics as actual patient measurements.

## 4. Primary patient journeys
1. Open Home and review the day's summary.
2. Open Add and select a record type.
3. Enter structured information and review it before saving.
4. Open Records to inspect the longitudinal history.
5. Open Insights to inspect qualified trends after sufficient data exists.
6. Open Profile to manage identity, privacy and sharing settings.
7. Start a checkup record from Home or Add; enter visit context, provider, measurements, findings, documents and follow-up; review provenance before saving.

## 5. Checkup encounter requirements
A checkup is an encounter, not an appointment. It has a unique ID, patient, visit date/time and type; provider/facility; reason and visit context; measurements; findings and examination details; tests and documents; clinician instructions and plan; follow-up tasks; creator, verifier, source and correction history.

Patient-entered notes must never be represented as clinician-authenticated findings. Incomplete encounters are allowed and missing fields are explicit.

## 6. Data classification and provenance
| Class | Example | Required metadata |
|---|---|---|
| Patient-reported | Symptom, manually entered BP | Actor, timestamp, source |
| Device-imported | Wearable heart rate | Device/source, timestamp, unit |
| Document-extracted | OCR result | Original document, extraction time, confidence, review status |
| Clinician-verified | Authenticated finding | Professional identity, verification timestamp, source |
| Derived | Trend or summary | Input records, calculation/version, period, limitations |

Do not convert an unknown or missing value into a negative finding.

## 7. Non-functional requirements
- Offline-first patient experience.
- Encrypt sensitive data at rest and in transit.
- Server must not hold patient data-decryption keys in the intended end-to-end encrypted design.
- Accessible contrast, screen-reader labels, scalable text and reduced motion.
- Exact units, timestamps and provenance on health measurements.
- Clear loading, empty, error, success and undo states.
- No hidden critical warning or meaning communicated by colour alone.
- Low-bandwidth resilience.
- Auditable access and correction history.

## 8. Stage 00 exit gate
- Product scope and exclusions documented.
- User roles and primary journeys defined.
- Data classes and provenance defined.
- Checkup workflow specified.
- Architecture decisions recorded.
- Threat model and privacy risks recorded.
- Stage 01 acceptance criteria and test plan defined.

## 9. Open decisions before production
Target release platforms; cloud provider/region and data residency; cryptographic recovery model; professional verification source; emergency access legal/clinical model; remote AI processing policy; regulatory classification and clinical validation. These remain open and must not be silently assumed.
