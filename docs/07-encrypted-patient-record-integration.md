# Stage 07 — Encrypted Patient Record Integration

## Objective
Move the Flutter patient application beyond placeholder capture by connecting the first canonical clinical resource to the encrypted local persistence foundation.

## Delivered
- Added `PatientRecordRepository`, which creates canonical JSON envelopes with UUID resource IDs, version numbers, timestamps and mandatory patient/unverified provenance.
- Added a secure-storage-backed development vault-key provider so the AES-256-GCM codec can be exercised by the app shell. This is a development bridge, not the final Stage 03 key manager.
- App startup now opens the SQLCipher database before rendering the patient application.
- The Flutter Records screen decrypts local entries on-device and renders a newest-first timeline.
- The checkup form now writes an `encounter` resource to the encrypted local store instead of showing a transient “draft captured” message.
- The local SQLCipher index was reduced to opaque record ID, version and tombstone state. Clinical type and timestamps are now inside encrypted JSON.
- Database schema version advanced to 2. The migration drops the old unencrypted index metadata while preserving the existing opaque ciphertext records only where the old schema layout is compatible; the v1 index rebuild intentionally discards old record rows because they cannot be safely migrated without decrypting and re-encrypting them under a verified metadata policy.

## Canonical checkup mapping
The checkup form maps visit types to the Stage 04 canonical values:
- Routine checkup → `routine_checkup`
- Follow-up → `follow_up`
- Urgent visit → `urgent_care`
- Consultation → `specialist_visit`
- Screening / Other → `other`

Every saved encounter includes `resource_type`, `resource_id`, `version`, `encounter_type`, `status`, `started_at`, `related_observation_ids` and provenance. Empty optional fields are omitted.

## Security boundaries and known limitations
- The vault key provider stores a randomly generated development DEK in platform secure storage. It does not yet use the Stage 03 X25519 device envelope, recovery secret, key rotation or multi-device lifecycle.
- The vault ID is currently a local development constant and must be replaced by the authenticated user's provisioned vault identifier.
- The Flutter SQLCipher store and codec are wired into the app, but the environment does not contain a usable Flutter SDK; analyzer, device build and runtime verification could not be run.
- No network sync is implemented in this stage. The repository is local-only.
- Only checkup/encounter capture is connected. Other capture tiles remain queued for their dedicated canonical-resource forms.
- Do not use real patient data until Flutter compilation, cryptographic interoperability, secure-key lifecycle, recovery and independent security review are complete.

## Verification checklist
1. Run `flutter pub get` in `apps/patient_mobile`.
2. Run `flutter analyze` and `flutter test`.
3. Build and launch on Android; verify secure storage and SQLCipher initialization.
4. Save a checkup, force-close the app, reopen and verify the entry is still present.
5. Confirm the local SQLite schema contains no plaintext clinical type, title, notes or clinical timestamps.
6. Attempt ciphertext tampering and verify AES-GCM authentication rejects decryption.
7. Test key loss/recovery, app reinstall, device revocation and vault migration before enabling production use.

## Exit gates
- Replace development key provider with Stage 03 device-envelope/key manager.
- Add complete Dart canonical models and JSON schema validation.
- Implement observation, medication, allergy and condition forms with canonical validation.
- Add encrypted document capture and encrypted blob references.
- Implement authenticated sync, retry/idempotency, conflict resolution and tombstone propagation.
- Add database migration tests and cross-language Python/Dart AES-GCM test vectors.
- Complete threat-model review, accessibility and clinical safety review.
