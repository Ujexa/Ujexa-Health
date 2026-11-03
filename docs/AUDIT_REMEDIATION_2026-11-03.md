# Ujexa Health — Repository Build Audit and Remediation

Date: 2026-11-03  
Branch: `fix/security-bootstrap-and-branding`  
Scope: repository inventory, Flutter/Android build surface, Python backend, automated tests, dependency manifests, CI workflows, asset references and release-readiness notes.

## Repository inventory

The branch contains 116 tracked paths, including 25 Dart files, 22 Python files, two GitHub Actions workflows, the Flutter asset and manifest, backend dependency manifests, product documentation, generated API/schema references and the browser prototype.

The build-bearing source/configuration and test paths were reviewed against the actual GitHub Actions failures. The prototype is a standalone static HTML/CSS/JavaScript demo and is not part of the Flutter or backend CI build.

## Original failure causes

### Flutter / Android
- The analyzer reported 227 findings: 226 informational hints and one warning.
- The workflow used `--fatal-infos`, so informational style hints (primarily `prefer_const_constructors`) incorrectly failed the build.
- The one actual warning was an unused local `dark` variable in the dashboard.
- The launcher icon generation step itself was already succeeding.

### Python backend
- Ruff reported import placement and unused-import errors.
- The device-trust tests contained incorrect expectations: development mode permits missing device claims, while production rejects them; the tests also reused a session ID after revoking it.
- Once tests were reached, 36 backend tests passed after correcting the test setup.
- The dependency audit found vulnerable versions of `cryptography`, `pytest` and `setuptools`.

## Remediation applied

- Moved late module imports in the health-record schema module to the module header and removed unused imports.
- Removed the unused dashboard variable.
- Changed Flutter analysis to `--no-fatal-infos --fatal-warnings`: informational suggestions remain visible, while warnings still fail CI.
- Corrected device-trust tests to exercise production enforcement and use an independent, non-revoked session for bootstrap.
- Replaced broad exception assertions in crypto/schema tests with specific `InvalidTag` and `ValidationError` assertions.
- Expanded Ruff checks to include correctness, unused-import and bugbear rules. B008 is excluded because FastAPI's `Depends()` is intentionally declared as a parameter default in dependency-injected routes.
- Updated backend dependency constraints to a patched cryptography and pytest release range; upgraded setuptools in CI; excluded the local editable project from PyPI vulnerability lookup.
- Added and retained the branded Android launcher icon generation and dark-theme logo contrast changes.

## Verification observed on GitHub Actions

| Check | Result |
|---|---|
| Backend Ruff checks | Passed |
| Backend pytest | 36 passed |
| Backend dependency audit | Passed |
| Flutter dependency resolution | Passed |
| Branded Android launcher icon generation | Passed |
| Flutter static analysis | Passed |
| Flutter tests | Passed |
| Release APK packaging | Pending at the time this report was written |

The Android workflow generates the Android platform directory on the hosted runner because that directory is not currently committed to the repository. The generated `pubspec.lock` is also uploaded as a workflow artifact rather than tracked in source control.

## Remaining release-readiness issues (not current CI failures)

These must not be confused with build blockers:

1. The app still uses the development-only vault DEK provider and a fixed local vault ID. Production key provisioning, recovery, rotation and lost-device restore are not complete.
2. Production backend persistence/migrations and a production database driver are not yet integrated; the current database foundation must not be treated as a production deployment.
3. The generated Android project and dependency lockfile are not committed, so a local Android build requires the documented Flutter project-generation step and dependency resolution.
4. Voice-note recording/playback uses temporary plaintext audio files; failure/navigation cleanup and private notification content need a dedicated privacy-hardening pass.
5. Cross-language cryptographic conformance vectors, authenticated cloud sync, multi-device conflict handling, physical-device testing and independent security/privacy/clinical review remain outstanding.
6. The Flutter analyzer still reports informational style suggestions. They are non-fatal by design; warnings remain fatal.

## Release decision

This remediation restores the CI quality gates and addresses the observed build failures. It does **not** make Ujexa Health production-ready or authorize use with real patient data. The APK must be confirmed by the final release-build and artifact-verification steps, followed by physical-device and independent release reviews.
