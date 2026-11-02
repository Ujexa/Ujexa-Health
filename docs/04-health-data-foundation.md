# Stage 04 — Health Data Foundation

**Build:** 0.4.0 foundation  
**Status:** Canonical domain contracts, encrypted record API and Flutter record-category shell implemented. Persistent Flutter repositories and production migrations remain open.

## 1. Design principles
- Patient-owned record collection.
- Patient-entered data is explicitly patient-reported, not clinician-verified.
- Imported documents preserve source references and verification status.
- Clinical entries are versioned; corrections create a new version rather than silently overwriting history.
- A checkup/visit is a first-class encounter that can relate to observations, documents and follow-up instructions.
- The server stores encrypted record payloads only. Clinical type, display name, event date, values, notes and provenance remain inside the encrypted payload.
- Timeline sorting and clinical filtering happen after decryption on the trusted client.
- No AI-generated diagnosis or automatic clinical interpretation is part of this data layer.

## 2. Canonical resource types
| Resource | Purpose |
|---|---|
| PatientProfile | Patient's personal health profile and emergency contact |
| ConditionRecord | Current/past conditions with clinical status |
| AllergyRecord | Substance, reaction, severity and status |
| ProcedureRecord | Surgery and other procedures |
| EncounterRecord | Checkup, follow-up, urgent/emergency or specialist visit |
| ObservationRecord | Vitals, lab values and other measurements |
| MedicationStatement | Medication being taken or previously taken |
| MedicalDocumentReference | Reference to an encrypted document blob |

All resources carry:
- `resource_type`, `resource_id`, `version`
- `provenance.source`
- `provenance.recorded_at`
- `provenance.verification_status`
- optional actor, organization, source-document reference and notes

## 3. Provenance rules
- `patient`: entered by the patient; do not display as clinician-verified.
- `clinician`: attributed to a clinician only when identity/authority has been verified by a supported workflow.
- `imported_document`: extracted or transcribed from a source document; preserve the document reference and initially mark unverified.
- `device`: measurement imported from a supported device; preserve device/source metadata and distinguish device-origin from clinical validation.
- `application`: system-generated metadata only. Do not use this source to invent clinical facts.

Verification states:
- `unverified`
- `patient_confirmed`
- `clinician_verified`

A patient confirming that an imported record is theirs does not make its clinical content clinician-verified.

## 4. Checkup / encounter model
A checkup is represented by `EncounterRecord`, with:
- visit type and status
- start/end timestamps
- provider, organization and location
- reason for visit
- clinical notes
- follow-up instructions
- related observation IDs
- provenance and verification status

A checkup does not itself imply a diagnosis. Diagnoses/conditions are separate resources and should only be created when the patient or an authorized clinician explicitly records them.

## 5. Observation model
An observation includes a code, display, effective timestamp, value quantity or text, unit, optional components, body site, method, encounter relation and provenance.

Blood pressure is represented as a component map, for example `{"systolic": 118, "diastolic": 76}` with unit `mmHg`. Heart rate can be a quantity in `bpm`; glucose needs an explicit unit such as `mmol/L` or `mg/dL`. Never silently convert units without retaining the original value/unit and recording the conversion method.

The schema validates shape, not medical plausibility or clinical interpretation. Reference ranges and alerts require a separate reviewed clinical rules layer.

## 6. Encrypted storage contract
- Mobile client validates a resource against the canonical schema.
- Client serializes the resource and encrypts the complete serialized content using the Stage 03 vault DEK and AES-256-GCM.
- The client uploads only record UUID, version, algorithm, nonce, ciphertext and ciphertext hash.
- The API validates envelope format and ownership, then stores immutable encrypted versions.
- Listing returns only opaque IDs, versions, algorithm, ciphertext size/hash and creation time. It does not expose clinical type, display, date, value or notes.
- The client downloads, verifies and decrypts locally, then builds the timeline from decrypted `recorded_at` / clinical effective dates.

The server-side API cannot validate the plaintext resource schema because it does not receive plaintext. Client schema validation is mandatory; an independent trusted clinical system can provide a separately signed record if stronger attestation is required.

## 7. API routes
| Method | Route | Purpose |
|---|---|---|
| POST | `/v1/health-records/{vault_id}/records` | Store encrypted record version |
| GET | `/v1/health-records/{vault_id}/records` | List opaque record versions |
| GET | `/v1/health-records/{vault_id}/records/{record_id}/{version}` | Fetch ciphertext |
| DELETE | `/v1/health-records/{vault_id}/records/{record_id}/{version}` | Soft-delete version |

Deletion hides a version from ordinary API reads but does not immediately guarantee physical erasure from backups, replicas or object storage. Production retention and erasure policy must be implemented and disclosed.

## 8. Timeline and synchronization
- The client decrypts the record set and sorts locally.
- Timeline date uses resource-specific effective dates (encounter start, observation effective time, procedure date, document date) with provenance record time as fallback.
- If the device is offline, local encrypted storage is authoritative for that device until sync completes.
- Record versions are immutable. A concurrent edit creates a new version and requires conflict review; do not use silent last-write-wins for clinical history.
- A deleted record should carry a tombstone in the synchronization protocol so deletion propagates to other devices. Current API soft-delete is only a server-side primitive; cross-device tombstone propagation is still pending.

## 9. Limitations and production gates
- Flutter currently contains domain contracts and a Records category landing screen, not a persistent encrypted repository implementation.
- Checkup form remains a prototype flow and does not yet save a typed EncounterRecord.
- Add remaining Dart resource classes, JSON serialization, schema conformance tests and local encrypted persistence.
- Add SQLCipher-backed storage and encrypted attachment/document handling.
- Add migrations, tenant isolation review, rate limiting, backup/restore and data deletion lifecycle.
- Add patient sharing/consent scopes and clinician identity/authorization before clinician-authored records are enabled.
- Establish supported terminology/unit catalogs; validate clinical codes where used.
- Review the schema with clinicians and local privacy/legal experts before production.

## 10. Non-goals
This stage does not diagnose, prescribe, recommend medication changes, interpret test results, automatically infer conditions, or certify patient-entered data as clinically verified.
