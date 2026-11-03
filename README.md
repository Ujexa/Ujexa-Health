# Ujexa Health — Stage 00 & 01 Build

This repository contains the Stage 00 product baseline and Stage 01 patient app shell prototype.

## Run the interactive prototype
Open `prototype/index.html` in a modern browser. No build step or package installation is required. For a local server:

```bash
cd prototype
python -m http.server 8000
```

Then visit `http://localhost:8000`.

## What works
- Dashboard shell and responsive layout.
- Home / Records / Insights / Profile navigation.
- Central Add and More action sheet.
- Structured forms for symptoms, medication, vitals, meals, activity, sleep, documents, appointments, notes and checkups.
- Checkup entry from both the dashboard and Add Menu.
- Sheet dismissal via close, backdrop and Escape.
- Session-only success feedback.

## Important prototype boundary
All displayed health metrics and names are synthetic demonstration content. Form submissions are transient and are not saved to a database. Do not enter real patient information. This prototype is not for diagnosis, treatment, medication decisions or emergency use.

## Framework baseline
The target patient mobile app is Flutter. The browser prototype is a rapid visual/interaction acceptance surface for Stage 01; it does not replace the Flutter implementation. Backend baseline: Python/FastAPI, PostgreSQL, SQLCipher-backed SQLite and encrypted object storage.

## Stage gates
See `docs/00-product-specification.md`, `docs/01-design-system-and-app-shell.md`, `docs/architecture-decisions.md` and `docs/threat-model-v0.md`.


## Stage 02 — Identity and device trust
A FastAPI backend foundation is in `backend/`. It validates provider-issued OIDC JWTs, enforces MFA claims, issues one-time device-enrollment challenges, verifies Ed25519 proof-of-possession, lists/revokes trusted devices and revokes sessions. See `docs/02-identity-and-device-trust.md` and `docs/02-oidc-provider-integration.md`.

Run backend tests:
```bash
cd backend
pip install -r requirements.txt
pytest -q
```

The OIDC issuer/JWKS values are placeholders in `.env.example`. Real sign-in is not enabled until an identity provider is selected and configured. Account recovery does not recover medical-record encryption keys.


## Stage 03 — Encryption and cloud recovery
The backend now includes a cryptographic reference implementation in `backend/ujexa_api/crypto/envelope.py` and opaque encrypted-vault endpoints in `backend/ujexa_api/vault.py`. The reference protocol uses AES-256-GCM for records, HKDF-SHA-256 to derive recovery/device wrapping keys, a random 256-bit recovery secret, and ephemeral X25519 for per-device vault-key envelopes. See `docs/03-encryption-cloud-recovery.md` and `docs/03-key-management-protocol.md`.

The server stores ciphertext and wrapped-key envelopes only; the Python crypto module is a test/reference implementation and is not called by the API. Flutter encryption, SQLCipher local persistence, platform key storage, production object storage, database migrations, recovery UX and independent security review remain required before production.


## Stage 04 — Health data foundation
Canonical health-resource contracts are in `backend/ujexa_api/health_records/schemas.py`, with a generated JSON Schema at `docs/health-record-resource.schema.json`. The encrypted health-record API is in `backend/ujexa_api/health_records/router.py`; it stores ciphertext and opaque IDs only. Flutter domain contracts and the encrypted repository interface are in `apps/patient_mobile/lib/domain/health_records.dart`. The Records tab now has a structured category landing screen.

Read `docs/04-health-data-foundation.md` and `docs/04-record-provenance-and-timeline.md`. The Flutter checkup form is still a prototype and does not yet persist a typed encounter. The API cannot validate encrypted plaintext resources; the trusted client must validate against the canonical schema before encryption.


## Stage 05 — Offline storage and synchronization
The backend exposes an opaque cursor-based sync journal at `GET /v1/health-records/{vault_id}/sync`. Flutter now has a SQLCipher local encrypted-record store and an AES-256-GCM codec foundation in `apps/patient_mobile/lib/data/encrypted_record_store.dart`. The codec requires a `VaultDekProvider` from the Stage 03 key manager; no fallback or plaintext storage path is provided. See `docs/05-record-capture-offline-sync.md` and `docs/05-sync-api.md`.

The UI forms are not yet connected to this repository, and the authenticated network sync orchestrator is still pending. Do not use real patient data until the Flutter app is compiled, cryptographic conformance is tested, and the remaining production gates are closed.


## Stage 06 — Patient health experience
The browser prototype now supports patient-entered capture, a locally persisted record timeline, provenance labels, deletion and simple record-count insights. See `docs/06-patient-health-experience.md`.

**Prototype safety boundary:** the browser demo uses unencrypted local browser storage. Do not enter real health information. It is not the production Flutter app and does not yet use the Stage 05 SQLCipher store or authenticated sync.


## Stage 07 — Encrypted patient record integration
The Flutter app now initializes the SQLCipher store, uses an AES-256-GCM development key provider, persists checkup encounters through a patient record repository, and reads a decrypted local timeline. See `docs/07-encrypted-patient-record-integration.md`.

The current key provider and fixed vault ID are development-only. The Flutter SDK was unavailable for analyzer/build/runtime verification. Do not use real patient data.


## Stage 08 — Clinical record management
The Flutter patient app now includes local encrypted capture for observations/vitals, medications, allergies and conditions; versioned edits; latest-version timeline rendering; and resource deletion tombstones. Hard-coded clinical demo values have been removed from the dashboard. See `docs/08-clinical-record-management.md`.

Dart analyzer, Flutter tests and Android runtime verification remain pending because Flutter SDK was unavailable. The Stage 07 development vault key provider is not production-ready. Do not use real patient data.


## Stage 09 — Encrypted documents and patient profile
The patient app now includes local encrypted PDF/image document capture, canonical document references, patient profile fields and emergency-contact information. Profile edits are versioned, and deleting a document removes its local encrypted attachment. See `docs/09-encrypted-documents-and-profile.md`.

Document attachments are local-only; emergency contacts do not trigger notifications or emergency access. Flutter analyzer and device verification remain pending. Do not use real patient data until the production key lifecycle and security review are complete.


## Stage 10 — Unified health timeline
The patient app now combines visits, observations, medications, allergies, conditions and medical documents in a chronological timeline with local search, category filters, date-range filtering, detailed record views and encounter-to-observation links. The patient profile remains separately managed. See `docs/10-unified-health-timeline.md`.


## Stage 11 — Health insights engine
The patient app now includes deterministic on-device summaries for numeric vital trends, medication status, active allergies/conditions, recent encounters, stored follow-up instructions and data completeness. It does not diagnose, assess clinical normality or recommend treatment. See `docs/11-health-insights-engine.md`.


## Stage 12 — Medication management
Medication statements now support route, prescriber, treatment dates and refill information. The patient app includes a medication management screen and patient-reported taken/missed/skipped dose events. No interaction checker, reminders, adherence score or pharmacy integration is included. See `docs/12-medication-management.md`.


## Stage 13 — Health reminders and notifications
A motion-led startup experience, local scheduled reminder notifications, audible OS notification delivery, and an in-app notification centre with Timed / Regular / Warning categories. See `docs/13-health-reminders-notifications.md` for scope and verification limits.


## Stage 14 — Medication scheduling and adherence
Medication dose reminders are generated only from explicit patient-entered HH:MM times and recorded dose instructions. Dose logs remain linked to their medication record. See `docs/14-medication-scheduling-adherence.md`.


## Stage 15 — Medication adherence and longitudinal health intelligence
Stage 15 adds schedule-derived adherence analysis and a private, self-supervised temporal autoencoder over selected patient-record history. It is an exploratory personal-pattern monitor, not a clinically validated model. See `docs/15-medication-adherence-and-health-intelligence.md`.


## Stage 16 — Medical document intelligence
The patient app now supports on-device OCR for JPG/JPEG/PNG/WebP medical documents using Google ML Kit. Patients can review extracted text before saving; extracted text and status are stored inside the encrypted document record and are searchable in the local timeline. No OCR-derived clinical facts are automatically added to the structured record. PDF extraction, structured field candidates and clinical verification remain future work. See `docs/16-medical-document-intelligence.md`.


## Stage 17 — Symptom and health journal intelligence
The patient app now supports encrypted symptom episode capture and personal health journal entries, including optional mood, energy and stress self-ratings. A local deterministic engine summarizes recurring symptom names, patient-rated severity, commonly noted possible triggers and journal rating averages. These are descriptive patient-record summaries, not diagnoses or causal findings. See `docs/17-symptom-and-health-journal-intelligence.md`.


## Stage 18 — Cross-domain health intelligence
The local deterministic analysis engine surfaces temporal overlaps between symptom entries and nearby measurements, medication dose events, journal entries and encounters; explicit encounter-linked measurements; and same-date overlaps with medical documents. Each relationship links back to source records and carries interpretation limits. Temporal overlap is not causation or clinical significance. See `docs/18-cross-domain-health-intelligence.md`.


## Stage 19 — Medical document understanding
Adds local page-rendered PDF OCR (up to 20 pages per run), page-aware image/PDF text extraction, heuristic document classification, limited value/instruction candidates, and explicit patient review. Accepted text and candidate annotations remain encrypted and unverified; nothing is automatically promoted to structured clinical records. See `docs/19-medical-document-understanding.md`.


## Stage 20 — Structured clinical data extraction
Adds conservative field-level candidates for simple lab result lines (label, value/unit and optional nearby reference range), verbatim prescription instruction phrases and explicitly labelled date strings. Candidates retain page/evidence and heuristic scores, require patient selection, and remain encrypted document annotations marked unverified. No medication schedule or clinical record is inferred. See `docs/20-structured-clinical-data-extraction.md`.


## Stage 21 — Patient-confirmed clinical record promotion
Adds a Document Review Workspace. Patients can edit and confirm supported laboratory candidates into observation records, or supply a medication name and confirm an extracted instruction into an unknown-status medication statement. Source document, page, evidence and imported-document provenance are retained. Medication timing is never inferred. Date candidates remain on the document. See `docs/21-patient-confirmed-clinical-record-promotion.md`.


## Combined Stages 22–29 milestone
Adds local record-integrity findings and version history, appointment and preventive-care records, lifestyle capture, a patient-facing emergency summary, scoped local sharing-consent records with revocation, and source-document provenance fields. The existing longitudinal intelligence remains in place. No clinician portal or remote sharing transport is claimed. Production security audit, emergency remote access, automated preventive reminders, Flutter builds and device validation remain outstanding. See `docs/22-29-combined-milestone.md`.


## Current build verification — 2026-11-03

The latest remediation and CI findings are documented in [the repository build audit](docs/AUDIT_REMEDIATION_2026-11-03.md). GitHub Actions now runs backend lint/tests/dependency auditing and Flutter analysis/tests before the Android release build. The Android platform directory is generated in CI if absent from source control. Do not use real patient data: production vault key lifecycle, recovery, sync and independent security/clinical review remain release gates.
