# Stage 12 — Medication Management

## Objective
Move medication data from a simple list to a patient-reported management workflow while distinguishing prescribed/recorded instructions from reported dose events.

## Delivered
- Extended medication statement fields for route, prescriber, start/end dates, quantity, remaining refills and refill due date.
- Added client-side date format and start/end chronology checks, plus integer validation for remaining refills.
- Added canonical `medication_dose_log` resource in the backend schema and exported resource union.
- Dose-log event types are `taken`, `missed`, `skipped` and `unknown`.
- Each dose event references the medication statement's opaque record ID and stores an occurrence timestamp and patient provenance.
- Added Medication Management screen with current medication cards, status, recorded schedule, dates, quantity/refills and refill date.
- Added one-tap patient-reported Taken, Missed and Skipped events for active medication statements.
- Added event counts and latest dose event on each medication card.
- Added a medication management quick action and entry from the Add Record sheet.
- Dose events are included in the general timeline under the Medication category.
- Added backend schema tests for supported dose event values and bounded refill counts.

## Clinical and safety boundaries
- A dose event is a patient report, not proof that a medication was ingested.
- No dosing schedule is generated from free-text frequency; no alarm or push notification is created.
- Refill due dates are displayed as entered. The UI highlights dates within seven days or earlier as approaching/overdue; this is a calendar reminder cue only, not a pharmacy stock or prescription status check.
- No drug interaction, contraindication, dose-range or allergy interaction checking is implemented. Do not imply that the absence of a warning means a combination is safe.
- Medication changes and dosing decisions must be confirmed with a qualified clinician or pharmacist.
- No AI model or external medication service is called.
- Medication statements and dose events are stored through the existing encrypted local record repository.

## Acceptance checks
1. Add and edit medication name, strength/dose, route, frequency, prescriber and status.
2. Save start/end dates and reject malformed dates or an end date before the start date.
3. Save quantity, remaining refill count and refill due date.
4. Confirm negative or non-integer refill counts are rejected by client/backend validation.
5. Log Taken, Missed and Skipped events for active medications.
6. Confirm each dose event links to the correct medication record and appears in the medication category on the timeline.
7. Confirm dose event totals and latest event refresh after logging.
8. Confirm no event can be interpreted as verified ingestion.
9. Run Flutter analyzer, widget/unit tests and Android device builds.

## Known limitations
- Frequency/schedule is currently a patient-entered text field, not a structured dose timetable.
- No notification scheduler, adherence percentage, streak, refill ordering or pharmacy integration exists.
- No medication knowledge base or interaction checking is included.
- The Flutter SDK was unavailable in the build environment; analyzer, test execution and device builds remain pending.
- Production vault key lifecycle and encrypted cloud sync remain outstanding.

## Exit gates
- Add a structured, clinician-reviewable dose schedule before generating reminders.
- Integrate a reputable, licensed and maintained medication knowledge source before any interaction-checking feature.
- Add medication reconciliation and prescription provenance workflows.
- Complete medication safety review, accessibility checks and Flutter device verification.
