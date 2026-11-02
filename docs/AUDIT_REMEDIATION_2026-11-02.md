# Ujexa Health — Audit Remediation Update

Date: 2026-11-02
Baseline: Stages 00–29 GitHub build package

## Changes applied in this remediation pass

### Data integrity
- Fixed the SQLCipher v1-to-v2 encrypted-record migration so encrypted record versions and tombstones are copied rather than discarded.
- Added a row-count verification before the legacy table is dropped. A mismatch aborts the migration.
- Ensured the sync-state table and initial cursor exist after upgrade.

### Medication adherence
- Dose-log events are now consumed at most once per medication schedule analysis.
- The closest event within the existing six-hour matching heuristic is selected.
- Equally-close ambiguous events are left unresolved rather than arbitrarily assigned.
- Added Dart regression tests for event reuse and separate taken/missed events.

### Checkup capture
- Expanded the encounter form with provider identifier, specialty, department, visit mode, referral source, tests/results, plan/instructions and next follow-up date.
- Extended the backend EncounterRecord schema for these fields.
- Existing provenance remains patient-reported/unverified unless authenticated by a clinician.

### Mobile experience
- Added the selected Ujexa Health tree mark as an app asset and replaced the generic heart mark in the dashboard header.
- Fixed the dashboard Log Vitals action so it opens the actual Vitals form rather than displaying a placeholder message.
- Added a working More action to the dashboard.
- Reworked the Add sheet to use a bounded, scrollable, adaptive grid; removed the duplicate Appointment tile.

### Backend access control
- Production requests now fail closed when the access token lacks the `device_id` claim required for trusted-device enforcement.
- Non-production behaviour remains compatible with the existing development test configuration.

### GitHub Actions
- Pinned Flutter to 3.35.5 instead of tracking the moving stable channel.
- Added a dependency graph capture step.
- Added a SHA-256 checksum for the APK.
- Added the generated `pubspec.lock` to the build artifact so the exact resolved dependency set can be reviewed and committed.

## Verification completed in this environment
- Backend pytest: 35 passed.
- Python compileall: passed.
- `pubspec.yaml` YAML parsing: passed.
- GitHub Actions workflow YAML parsing: passed.
- ZIP integrity: verified after packaging.

## Still release-blocking / not verifiable here
1. Flutter and Dart SDKs are not installed in this environment. The Dart changes and tests have not been compiled or executed.
2. Android platform files are generated in CI because the source package does not retain a checked-in Android project. CI must be run to verify Gradle/plugin compatibility.
3. A committed `pubspec.lock` is still required for fully reproducible dependency resolution. The workflow now publishes its generated lockfile, but it must be committed after the first successful CI resolution.
4. Production vault DEK provisioning, recovery, rotation, and lost-device restore are not complete. The development-only DEK provider and fixed local vault ID must not ship.
5. Full end-to-end encrypted sync, multi-device conflict resolution and authenticated clinician sharing are not implemented.
6. Emergency access governance, verified responder identity and audited remote disclosure are not implemented.
7. Physical-device testing remains required for SQLCipher migration, notifications/reboot behaviour, document OCR/PDF rendering, keyboard/small-screen layouts, font scaling, screen readers and offline use.
8. Independent security, privacy, clinical and regulatory review remains required before handling real patient data.

## Release decision
This package is an improved remediation candidate, not a production-ready or verified v1.0.0 release. Run the GitHub Actions workflow and resolve every Flutter/Android failure before installing it. Use synthetic data only until the remaining security and clinical release gates are met.
