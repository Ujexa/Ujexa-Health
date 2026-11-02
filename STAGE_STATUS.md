
## Stage 03 — Encryption and cloud recovery
**Status: Cryptographic reference and opaque backup API implemented; production client and storage integration pending.**
- AES-256-GCM record payload encryption with context-bound AAD and integrity hash.
- Random 256-bit vault DEK and independent random 256-bit recovery secret.
- HKDF-SHA-256 recovery key derivation and wrapped DEK recovery envelope.
- Per-device X25519 + HKDF-SHA-256 + AES-256-GCM key envelopes.
- Separate Ed25519 device signing and X25519 key-agreement keys.
- Server-side opaque ciphertext upload/list/download/delete API.
- Opaque wrapped-key envelope storage and retrieval.
- Active trusted-device requirement for device envelopes.
- Device revocation also revokes its associated vault-key envelopes.
- Security protocol, metadata exposure and recovery limitations documented.

## Stage 03 verification
- Pytest: **15 passed**.
- Python compileall: PASS.
- AES-GCM round-trip and AAD context binding tested.
- Ciphertext tampering/hash mismatch tested.
- Recovery-secret wrapping/unwrapping and wrong-secret failure tested.
- X25519 device wrapping/unwrapping and wrong-device failure tested.
- Encrypted backup API upload/list/download, immutable version and hash validation tested.
- Device envelope storage requires registered active X25519 device.
- Device revocation invalidates its key envelopes.

## Stage 03 production exit gates still outstanding
1. Implement the same protocol in Flutter and publish cross-language test vectors.
2. Integrate SQLCipher local storage and platform-secure key storage.
3. Implement recovery-secret UX and multi-device provisioning/recovery flows.
4. Move ciphertext blobs to production private object storage; add Alembic migrations.
5. Add upload/download streaming, quotas, rate limits, retention and restore drills.
6. Implement DEK rotation and full vault re-encryption.
7. Complete independent cryptographic and security review before real patient use.

## Stage 04 — Health Data Foundation
**Status: Canonical schemas, encrypted health-record API and Flutter records landing screen implemented.**
- Canonical resource contracts: patient profile, condition, allergy, procedure, encounter/checkup, observation, medication statement and medical document reference.
- Mandatory provenance and verification status on all clinical resources.
- Checkup encounters link to observations and follow-up instructions.
- Clinical timeline ordering rules defined for decrypted client-side records.
- Encrypted health-record version API with immutable versions, integrity checks, owner isolation and soft deletion.
- Server-side list metadata intentionally excludes clinical type, date, title, values and notes.
- Flutter domain contracts and encrypted repository interface added.
- Patient Records tab upgraded to a structured record-category landing screen.
- JSON Schema and OpenAPI specifications generated.

## Stage 04 verification
- Pytest: **25 passed**.
- Python compileall: PASS.
- Schema tests cover patient profile, conditions, allergies, procedures, encounters, observations, medications and document references.
- Encounter chronology validation tested.
- Unexpected schema fields rejected.
- Encrypted record upload/download, version immutability, hash mismatch, vault isolation and deletion tested.
- Flutter build/analyzer not run: Flutter SDK is unavailable in this environment.

## Stage 04 production exit gates still outstanding
1. Complete Dart models/serialization for every canonical resource and add cross-language schema conformance tests.
2. Implement encrypted local persistence and a real `EncryptedHealthRecordRepository`.
3. Wire the checkup form to create typed EncounterRecord resources and related observations.
4. Implement document upload encryption and attachment references.
5. Add sync conflict resolution and tombstone propagation across devices.
6. Add database migrations, production object storage, retention and physical deletion workflows.
7. Conduct clinical schema review and privacy/security assessment before patient data is used.

## Stage 05 — Record Capture, Offline Storage and Synchronization
**Status: Sync API and Flutter encrypted local-storage foundation implemented; full app integration pending.**
- Cursor-based opaque sync journal endpoint.
- Upsert and delete/tombstone events emitted for health record versions.
- Flutter app manifest/dependency declaration added.
- SQLCipher local database store added.
- Independent local DB key held in Flutter secure storage.
- AES-256-GCM record codec added with Stage 03-compatible AAD binding.
- Local sync cursor persistence and tombstone support added.

## Stage 05 verification
- Pytest: **26 passed**.
- API sync tests verify upsert, tombstone, cursor behavior and absence of clinical metadata.
- Flutter analyzer/build not run because Flutter SDK is unavailable in this environment.
- Cryptographic cross-language conformance not yet verified.

## Stage 05 remaining integration gates
1. Implement and inject VaultDekProvider from the Stage 03 key manager.
2. Run Flutter pub get, analyzer and tests; fix package/API compatibility issues.
3. Wire SQLCipher repository and encrypted codec into app startup and record forms.
4. Persist typed checkups and observations, then add allergy, condition and medication forms.
5. Implement authenticated network sync, retry queue, idempotent page application and cursor commits.
6. Add encrypted attachment uploads and document capture.
7. Add conflict-resolution UI, multi-device tombstone propagation, migrations and backup/restore tests.
8. Complete security review before real patient data use.

## Stage 06 — Patient Health Experience
**Status: Browser interaction prototype upgraded; production Flutter persistence and integration remain pending.**
- Patient-facing capture forms now save demo records across browser sessions using local browser storage.
- Records view renders a newest-first timeline, provenance/verification labels and record deletion.
- Insights view derives simple record counts from entered data only; no clinical scoring or diagnosis.
- Profile view includes local demo-data clearing and explains future identity, emergency and sharing controls.
- Removed fabricated health metrics, medication reminders and activity figures from the dashboard.
- Persistent prototype warning states that local browser storage is unencrypted and must not contain real health information.

## Stage 06 verification
- JavaScript syntax check and browser-level acceptance testing are required before treating the prototype as verified.
- Flutter analyzer/build remains unavailable in this environment.
- Browser prototype data is unencrypted and is not production health-data storage.

## Stage 06 remaining integration gates
1. Complete Dart serialization for every canonical resource and implement a SQLCipher-backed encrypted repository.
2. Wire Flutter checkup, observation, medication, allergy and condition capture to canonical records with provenance.
3. Implement encrypted document capture and attachment storage.
4. Integrate authenticated sync, retry queue, idempotent application, conflict resolution and tombstone propagation.
5. Add patient profile, emergency-contact and clinician-sharing workflows with consent and audit controls.
6. Run automated browser tests, Flutter analyzer/build, accessibility review and independent security/clinical safety review.

## Stage 07 — Encrypted Patient Record Integration
**Status: Flutter repository integration and checkup persistence implemented in source; runtime verification pending.**
- Added patient record repository with canonical JSON envelope fields and patient/unverified provenance.
- Added secure-storage-backed development DEK provider.
- Flutter startup initializes SQLCipher and AES-256-GCM store.
- Records screen reads/decrypts and renders a newest-first local timeline.
- Checkup form persists canonical encounter resources locally.
- SQLCipher index reduced to opaque identifiers/version/tombstone; clinical type and timestamps moved into encrypted payload.
- Local schema advanced to v2.

## Stage 07 verification
- Flutter analyzer, tests and Android runtime build could not be run because a usable Flutter SDK is unavailable in this environment.
- Python backend regression suite and source-level checks are run as part of this stage build.
- Production key lifecycle, network sync and cross-language crypto tests remain incomplete.

## Stage 07 remaining integration gates
1. Replace development DEK provider and fixed local vault ID with the Stage 03 provisioned key manager and authenticated vault context.
2. Complete canonical Dart models and JSON Schema validation.
3. Implement observations, medications, allergies and conditions capture.
4. Add encrypted document ingestion and attachment storage.
5. Implement authenticated sync, retries, idempotency, conflict resolution and tombstone propagation.
6. Run Flutter analyzer/build/device tests and cross-language AES-GCM vectors.
7. Complete recovery, key rotation, device revocation, privacy and independent security reviews before real patient use.

## Stage 08 — Clinical Record Management
**Status: Core local clinical capture, versioning and timeline integration implemented in Flutter source; device verification pending.**
- Added observation/vitals, medication, allergy and condition forms.
- Added focused client-side validation for required fields and canonical enumerations before encryption.
- Edits create immutable next versions under the same resource ID.
- Timeline displays only the latest version of each resource.
- Local delete tombstones every version of the resource.
- Added edit/delete controls and patient-entered/unverified labels.
- Removed fabricated dashboard health metrics and reminders; dashboard now derives a record count from the encrypted local repository.

## Stage 08 verification
- Backend pytest regression suite: 26 passed.
- Python compileall: PASS.
- Flutter analyzer, tests and Android build not run because Flutter SDK is unavailable.
- Local sync and remote tombstone propagation are not implemented.

## Stage 08 remaining integration gates
1. Run Flutter analyzer/tests and device acceptance checks.
2. Integrate the production Stage 03 key manager and authenticated vault ID.
3. Replace focused validation with complete generated JSON Schema validation.
4. Complete observations, medication, allergy and condition clinical review.
5. Add encrypted documents and attachment lifecycle.
6. Implement authenticated sync, retries, idempotency, conflict resolution and remote tombstones.
7. Complete backup/restore, consent, audit, privacy and independent security review.

## Stage 09 — Encrypted Documents and Patient Profile
**Status: Local encrypted document capture and patient profile implemented in Flutter source; device verification pending.**
- Added encrypted local PDF/image blob store using the Stage 07 AES-GCM codec.
- Added document metadata capture and canonical `document_reference` resources.
- Supported lab reports, prescriptions, discharge summaries, imaging, referrals, vaccination records, insurance and other.
- Added 20 MB limit for PDF/JPEG/PNG/WebP.
- Added patient profile capture for names, DOB, sex at birth, blood group, height and emergency contact.
- Profile edits create immutable versions; latest profile is loaded on the Profile tab.
- Deleting a local document removes its encrypted blob and tombstones the local metadata.
- Emergency contacts are stored as data only; no emergency notification/access is implemented.

## Stage 09 verification
- Backend regression suite and Python compilation are rerun for this stage.
- Flutter analyzer, tests and Android device tests are not available because Flutter SDK is missing.
- Local document storage is not cloud-backed or synchronized.
- Development vault key provider remains temporary.

## Stage 09 remaining integration gates
1. Run Flutter analyzer, tests and Android builds.
2. Integrate Stage 03 device envelopes, recovery, rotation and device revocation.
3. Implement streaming encrypted attachments and encrypted cloud backup/sync.
4. Add secure document export/restore and robust cleanup.
5. Build consented emergency and clinician access with audit trails.
6. Complete file handling, privacy, threat-model and independent security review.

## Stage 10 — Unified Health Timeline
**Status: Unified searchable and filterable timeline implemented in Flutter source; device verification pending.**
- Replaced the basic records list with date-grouped, newest-first timeline.
- Uses event-specific clinical dates where available, with provenance timestamp fallback.
- Added category filters for visits, vitals, medications, allergies, conditions and documents.
- Added local search, inclusive date-range filtering and pull-to-refresh.
- Added a detail sheet with resource fields, version and provenance.
- Added encounter-to-observation linking in checkup capture and linked-record navigation in details.
- Patient profile remains in its separate profile area rather than being misrepresented as a dated event.
- Search/filter runs on decrypted local data; no plaintext server index or database metadata index was added.

## Stage 10 verification
- Source-level checks and backend regression tests are run for this stage.
- Flutter analyzer, widget tests and Android device verification remain pending because Flutter SDK is unavailable.
- Search is in-memory; large-vault pagination/virtualization remains future work.
- Relationship support currently covers encounter-to-observation only.

## Stage 11 — Health Insights Engine
**Status: Deterministic, local-first insights engine and Health Insights UI implemented in Flutter source; Flutter verification pending.**
- Added vital trend aggregation by observation code and unit, excluding cancelled/entered-in-error records and unusable numeric/date values.
- Added local sparkline, latest recorded value, measurement count/date span and first-to-latest arithmetic change.
- Added medication status summary, explicitly active allergy/condition lists, recent encounter history and stored follow-up instruction display.
- Added data completeness notes for missing source data; no synthetic measurements are created.
- Added Flutter unit tests for unit separation, status filtering, follow-up extraction and profile exclusion.
- No diagnosis, reference-range assessment, treatment advice, risk score or AI model is used.
- Insights run locally on decrypted latest-version records; no server-side plaintext index or insight endpoint was added.

## Stage 11 verification
- Backend regression tests and Python compilation are rerun for this stage.
- Flutter SDK is unavailable; `flutter analyze`, `flutter test` and Android device builds remain pending.
- Trend change is arithmetic first-to-latest difference, not a clinical interpretation.
- Follow-up instructions are displayed as entered and do not generate reminders.

## Stage 12 — Medication Management
**Status: Medication management UI and dose-log schema implemented in Flutter/backend source; Flutter verification pending.**
- Added route, prescriber, start/end dates, quantity, refills remaining and refill due date to medication statements.
- Added canonical `medication_dose_log` resource with taken/missed/skipped/unknown events linked to a medication record.
- Added date and refill-count validation in the patient form and bounded backend schema fields.
- Added Medication Management screen with medication cards, status/schedule details, refill cue and dose event history.
- Added patient-reported Taken, Missed and Skipped actions for active medication records.
- Dose logs appear in the timeline under Medication.
- No dosing alarms, adherence score, pharmacy integration or medication interaction checking is implemented.
- No AI or external medication service is used.

## Stage 12 verification
- Backend schema and regression tests are rerun for this stage.
- Flutter SDK unavailable; analyzer, Flutter tests and Android device verification remain pending.
- Dose events are patient-reported and do not verify ingestion.
- Refill cue is derived only from the date entered by the patient; it does not confirm a prescription or pharmacy refill.

## Stage 13 — Health Reminders & Notifications
- [x] Animated branded startup gate
- [x] Internal notification centre and unread/read state
- [x] Timed, regular, and warning notice classes
- [x] Explicit date/time local scheduling
- [x] Audible default OS notification sound and vibration configuration
- [x] Timezone-aware scheduling setup and permission requests
- [ ] Recurring medication schedule rules and dose-linked escalation (future stage)
- [ ] Flutter analyzer, platform builds, and physical-device notification verification

## Stage 14 — Medication Scheduling & Adherence
- [x] Explicit dose-time entry and HH:MM validation
- [x] Schedule local audible reminders from patient-entered dose and times
- [x] Respect medication start/end dates when generating the 90-day reminder horizon
- [x] Replace future schedule on medication edit; cancel schedules for inactive medications
- [x] Display dose times on medication cards
- [x] Preserve linked Taken / Missed / Skipped dose-event logging
- [ ] Flutter analyzer, APK build, and physical-device verification
- [ ] App-launch schedule reconciliation and automatic overdue-dose state (future work)

## Stage 15 — Medication Adherence & Longitudinal Health Intelligence
- [x] Schedule-derived dose occurrence timeline
- [x] Taken / missed / skipped / overdue / upcoming classification
- [x] Descriptive adherence percentage from recorded events
- [x] Recent/upcoming dose timeline in Health Insights
- [x] On-device self-supervised temporal autoencoder for personal history
- [x] Patient-specific robust normalization and missing-data masks
- [x] Chronological holdout comparison and minimum-history gate
- [x] Visible clinical and model limitations
- [x] Flutter unit tests added
- [ ] Flutter analyzer, tests, Android/iOS build and device verification
- [ ] Persisted encrypted model checkpoints, OCR/NLP model branches and broader symptom/journal feature extraction (future work)
