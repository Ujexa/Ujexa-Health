# Stage 06 — Patient Health Experience

## Objective
Turn the patient-facing shell into a usable health-record experience: patient-entered capture, a chronological record list, transparent provenance labels, and data-derived summaries.

## Delivered in this stage
- Browser prototype capture forms for checkups, observations/vitals, medication statements, symptoms, appointments, meals, activity, sleep, notes and document metadata.
- Patient-entered records are persisted between browser sessions using local browser storage.
- Records view lists saved entries newest-first and exposes a deliberate delete action.
- Each entry is labelled patient-entered and unverified; the UI does not imply clinician verification.
- Insights view derives record counts from the user's entered records only; it does not invent clinical scores or offer diagnosis/treatment advice.
- Profile view explains planned trust, emergency-access and sharing capabilities and provides a clear local-data deletion action.
- Removed fabricated dashboard vitals, medication reminders and activity figures from the prototype.
- Added a persistent warning that browser storage is unencrypted and the prototype must not receive real health information.

## Important implementation boundary
This is an interaction prototype, not the production patient app. Browser `localStorage` is not encrypted, authenticated, backed up, synchronized or suitable for real health information. The Flutter SQLCipher repository from Stage 05 is not yet wired into the Flutter screens. Document selection stores only a filename marker in this prototype; it does not upload or encrypt the file. No emergency workflow, clinician sharing, medication adherence logic or medical decision support is implemented.

## Acceptance checks
1. Create a checkup and confirm it appears in Records after navigation and page reload.
2. Create a vital observation and confirm it is included in the record list and insight counts.
3. Delete an entry and confirm it disappears after reload.
4. Clear all demo data from Profile and confirm the Records and Insights views return to empty states.
5. Confirm no fabricated clinical measurements or adherence claims appear on the dashboard.
6. Confirm the persistent warning is visible on the prototype.

## Exit gates
- Implement and test complete Dart serialization for all canonical record resources.
- Build a production `EncryptedHealthRecordRepository` over SQLCipher and inject the Stage 03 vault key provider.
- Wire Flutter capture forms to typed canonical records and provenance.
- Implement encrypted document capture and attachment references.
- Add authenticated sync, retries, idempotency, conflict resolution and tombstone propagation.
- Add patient identity/profile and emergency-contact models with explicit consent and access controls.
- Complete accessibility, clinical safety, privacy and security review before any real patient use.
