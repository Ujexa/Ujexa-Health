# Stage 14 — Medication Scheduling & Adherence

## Implemented
- Medication records now support explicit `dose_times` as up to 12 unique 24-hour local clock times (`HH:MM`).
- Medication entry/edit includes a clear field for exact dose times and explains that reminders are not generated when times are absent.
- Saving an active medication schedules local audible reminders from its prescribed dose, medication name, explicit times, and optional start/end dates.
- Schedules are generated as one-shot local notifications across a rolling 90-day horizon, rather than indefinite daily repeating alarms. Editing a medication replaces its future schedule; inactive medication records cancel their scheduled reminders.
- Medication management cards display the exact recorded dose times.
- Existing Taken / Missed / Skipped controls continue to create linked dose-log records, with event timestamps and medication record linkage.
- Medication schema now validates unique `HH:MM` schedule entries.

## Safety behavior
- Frequency text such as “twice daily” does not create guessed clock times. The patient must enter the actual times from the prescription or confirm them with the prescriber/pharmacist.
- The reminder displays the recorded prescribed dose; it does not calculate or modify the dose.
- Editing medication details does not rewrite prior dose logs.
- This stage does not advise what to do after a missed dose or recommend doubling a dose.
- Reminder delivery is local and depends on OS permission, battery policy and platform scheduling constraints.

## Remaining verification / next work
- Flutter/Dart SDK is not available in this environment; analyzer, APK build and physical-device tests are pending.
- Device reboot behavior, exact alarm permission requirements, timezone changes and DST transitions need Android/iOS verification.
- The rolling 90-day schedule should be refreshed when the app launches and after any medication edit; background refresh and automatic overdue/missed-dose reconciliation are future work.
