# Stage 13 — Health Reminders & Notifications

## Delivered
- A branded animated startup gate with a short motion-led identity sequence.
- A dedicated in-app Notification Centre, reachable from the Alerts navigation destination and dashboard bell.
- Three notice classes: **Timed**, **Regular**, and **Warning**, each with distinct iconography and visual severity.
- Patient-authored reminder creation with title, detail, notice class, and an explicit local date/time.
- Local scheduled notifications using `flutter_local_notifications`, timezone-aware conversion, audible OS notification sound, vibration, and a high-importance Android channel.
- Internal notice history persisted in platform secure storage, with unread count, read state, and mark-all-read.
- Permission requests for Android notifications and iOS alert/badge/sound permissions.

## Safety and reliability boundaries
- The app never infers a dose time from free-text frequency. A patient must explicitly create a reminder and choose a date/time.
- This stage schedules one-shot reminders. It does not yet create recurring daily/weekly medication schedules, infer overdue doses, or automatically escalate missed doses. Those require explicit schedule rules and dose-event reconciliation in a later stage.
- Warning is a user-selected severity class in this stage, not an automatically generated clinical alert or emergency escalation.
- External notification sound uses the device's configured default notification sound and vibration; it is not a custom medical alarm tone.
- Scheduled delivery depends on platform permission, device settings, battery optimization, OS scheduling behavior, and app/platform configuration.
- Internal notification history is stored using platform secure storage. It is not a substitute for the encrypted clinical-record vault.
- No notification content is sent to a third-party notification service.

## Verification
- Source-level checks and Python backend regression tests are run with this stage.
- Flutter/Dart SDK and Android/iOS device builds are not available in this build environment. Plugin API compatibility, permission prompts, sound playback, timezone/DST behavior, reboot persistence, and real device delivery remain to be verified on target devices.
