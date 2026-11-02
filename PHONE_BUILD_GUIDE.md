# Build Ujexa Health APK using GitHub Mobile

This repository includes a GitHub Actions workflow at `.github/workflows/android-apk.yml`.
It builds the Flutter Android app in GitHub's hosted runner and uploads the release APK as a workflow artifact.

## First-time setup from your phone

1. Create a new GitHub repository (for example, `ujexa-health`).
2. Upload the contents of this project ZIP to the repository, preserving folders. The `.github/workflows/android-apk.yml` file must end up at the repository path `.github/workflows/android-apk.yml`.
3. Open the repository in GitHub Mobile, go to **Actions**, and select **Build Ujexa Health Android APK**.
4. Tap **Run workflow** and confirm.
5. Wait for the run to finish. A green check means all configured checks and the APK build completed.
6. Open the completed workflow run, find **Artifacts**, and download `ujexa-health-android-apk`.
7. Extract the downloaded artifact ZIP and tap `app-release.apk` to install it. Android may ask you to allow installs from that source.

## Automatic builds

After the first successful setup, pushes that change `apps/patient_mobile/**` or the workflow file on `main` trigger another build.

## Important

- The workflow generates the missing Android platform project in the CI runner if it is not present in source control.
- The workflow deliberately runs `flutter analyze` and `flutter test` before building. If either fails, the APK is not published; inspect the failed step's logs rather than treating a failed run as an installable build.
- This is a release APK build, not a Play Store-signed production release. App signing, production key management, device verification and security review remain outstanding.
- The current app's development-only vault key provider is not suitable for real patient data. Do not use real medical information until the production key lifecycle and security review are complete.
