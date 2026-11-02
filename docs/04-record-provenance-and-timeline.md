# Stage 04 — Provenance and Timeline Rules

## Provenance is mandatory
Every resource must carry source and recorded timestamp. Never silently upgrade provenance.

## Source display guidance
- Patient: "Entered by you"
- Clinician: "Recorded by [verified clinician]" only after identity verification
- Imported document: "From imported document" with a link to the source document
- Device: "Measured by [device]" where device metadata is available
- Application: "Added by Ujexa Health" for system metadata only

## Timeline sorting
Prefer the event's clinical date:
1. Encounter `started_at`
2. Observation `effective_at`
3. Procedure `performed_date`
4. Document `document_date`
5. Condition onset/resolution dates
6. Medication start/end dates
7. Provenance `recorded_at` as fallback

The timeline is computed on the decrypted client. The API deliberately does not receive these dates.

## Conflict handling
Versions are immutable. If two devices create version 3 from version 2, the client must surface a conflict and allow the patient to compare/retain both or create a reviewed merged version 4. Do not silently overwrite one branch.

## Corrections
Correcting a past record creates a new version with provenance and an explanation. The prior version remains in the encrypted history unless the patient invokes a deletion workflow subject to retention policy.
