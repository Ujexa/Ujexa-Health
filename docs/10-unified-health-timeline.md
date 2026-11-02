# Stage 10 — Unified Health Timeline

## Objective
Present patient-entered clinical records and medical documents as one searchable, filterable chronological history while retaining encrypted storage, provenance and relationships.

## Delivered in the patient app
- Replaced the basic records list with a unified health timeline.
- Groups entries by event date and sorts newest first.
- Uses clinical dates when available:
  - Encounter: `started_at`
  - Observation: `effective_at`
  - Medical document: `document_date`
  - Other resources: provenance `recorded_at`
- Category filters: visits, vitals, medications, allergies, conditions and documents.
- Search across resource category and decrypted record summary.
- Date-range filtering with a clear-filter action.
- Pull-to-refresh reloads the encrypted repository.
- Detail sheet shows the complete saved resource fields, version and patient-entered/unverified provenance.
- Encounter form can link one or more existing vital observations by opaque record ID.
- Encounter details resolve and display linked observations when available.
- Profile is intentionally managed separately and is not represented as a dated clinical event.
- Existing edit and delete flows remain available for supported record types. Document deletion removes the local encrypted blob and tombstones its reference.

## Privacy and clinical boundaries
- Filtering and search run after the repository decrypts records locally; no clinical search terms or decrypted content are sent to a server.
- No new plaintext clinical indexes are added to SQLCipher metadata.
- Timeline entries remain explicitly patient-entered and unverified.
- A relationship is a reference to another local record ID; it does not assert clinical causality.
- The timeline does not calculate diagnoses, risk scores or treatment recommendations.

## Acceptance checks
1. Create a visit, several observations, medications, allergies, conditions and documents.
2. Confirm events group by clinical date and sort newest first.
3. Confirm category chips isolate the expected resource types.
4. Search for a known medication, observation display name and document title.
5. Apply a date range and verify inclusive start/end dates.
6. Link vital observations to a new encounter and open the encounter details to follow those links.
7. Edit a supported record and confirm the newest version appears once in the timeline.
8. Delete a record and confirm it no longer appears after refresh.
9. Confirm profile remains available in the Profile tab and does not appear as a timeline event.
10. Inspect database metadata to confirm no plaintext search index, clinical title or event date was introduced.

## Known limitations
- Search is in-memory over decrypted local records; it is not full-text indexed and may become slow for very large vaults.
- Related-record linking currently supports encounter-to-observation references only.
- Document details show encrypted attachment metadata; in-app PDF/image preview and safe export are not yet implemented.
- No clinician-authored verification state, remote sharing, cloud synchronization or cross-device relationship resolution is implemented.
- The Flutter SDK was unavailable in the build environment; analyzer, widget tests and device tests remain required.

## Exit gates
- Run `flutter analyze`, `flutter test` and Android device builds.
- Add dedicated Flutter tests for date grouping, filters, search, record versioning and relationship resolution.
- Add pagination/virtualized timeline loading for large vaults.
- Add broader relationship types and integrity checks for missing/deleted linked resources.
- Implement encrypted sync before relationships are expected to resolve across devices.
- Complete accessibility, localization and security review.
