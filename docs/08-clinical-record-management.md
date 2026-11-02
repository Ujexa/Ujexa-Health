# Stage 08 — Clinical Record Management

## Objective
Extend the encrypted patient record experience from checkup-only capture to core longitudinal clinical records, while keeping patient-entered information clearly distinguished from clinician-verified information.

## Delivered
- Added capture forms for observations/vitals, medication statements, allergies and conditions.
- Added local repository validation for the supported canonical resource types and enumerated statuses before encryption.
- Added immutable version updates: editing a record writes the next version under the same resource ID.
- The Records timeline now selects the latest version of each resource and displays the latest decrypted content.
- Added delete controls that tombstone every local version of the resource, preventing older versions from reappearing in the timeline.
- Added edit controls for observations, medications, allergies and conditions. Checkup/encounter editing is intentionally not exposed in this stage.
- Added explicit patient-entered/unverified labels to the timeline.
- Removed fabricated heart rate, blood pressure, glucose, sleep, medication and activity values from the Flutter dashboard. It now shows a count derived from locally stored records.
- Expanded the Add Record sheet to expose the new modules.

## Canonical resource mappings
- Vitals → `observation`
- Medication → `medication_statement`
- Allergies → `allergy`
- Conditions → `condition`
- Checkup → `encounter` (from Stage 07)

The client validation checks required text fields, allowed enumerated values, encounter type/status, observation value presence and related-observation list shape. This is a focused client-side guard, not a complete generated JSON Schema validator. Full canonical schema validation remains an exit gate.

## Version and deletion semantics
- New resources begin at version 1.
- Edits write version N+1; prior versions remain encrypted in the local database.
- The normal timeline displays only the latest version for each resource.
- Local delete marks all versions of the resource as deleted.
- Cloud synchronization and server-side tombstone propagation are not implemented here. A local delete must not be interpreted as deletion from other devices or remote backups.

## Important limitations
- Flutter SDK was unavailable in the build environment; Dart analyzer, Flutter tests and Android runtime tests were not run.
- Only the supported local forms are connected. Symptoms, documents, appointments, meals, activity, sleep and voice notes remain future modules.
- No clinical diagnosis, drug interaction checking, dosing recommendation or treatment advice is provided.
- The development vault-key provider and fixed vault ID from Stage 07 remain temporary. Do not use real patient data until the Stage 03 key lifecycle is integrated and reviewed.
- Local encrypted persistence does not yet imply a completed cloud backup/synchronization system.

## Acceptance checks for device verification
1. Create a vital observation, medication, allergy and condition; force-close and reopen the app; confirm they remain visible.
2. Edit each supported resource and verify that the resource ID remains the same while the version increments.
3. Confirm the timeline displays only the newest version.
4. Delete an edited resource and verify no older version reappears after restart.
5. Verify invalid numeric observations and unsupported enum values are rejected before encryption.
6. Inspect the SQLCipher schema and confirm that clinical type, dates, labels and notes remain inside ciphertext.
7. Verify that patient-entered/unverified provenance is present in each saved resource.

## Exit gates
- Run `flutter pub get`, `flutter analyze`, `flutter test` and Android device/emulator builds.
- Replace development DEK provider and fixed vault ID with the provisioned Stage 03 key manager.
- Implement generated JSON Schema validation and Dart models for all canonical resources.
- Add clinical review of observation codes, units, medication fields and provenance semantics.
- Add encrypted documents and attachment lifecycle.
- Implement authenticated sync, retry/idempotency, conflict resolution and remote tombstone propagation.
- Add export, backup/restore, audit, consent and security review.
