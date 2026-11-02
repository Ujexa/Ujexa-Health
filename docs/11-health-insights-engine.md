# Stage 11 — Health Insights Engine

## Objective
Introduce a cautious, local-first descriptive intelligence layer over patient-owned health records. Insights must be traceable to saved data and must not diagnose, recommend treatment or create unsupported risk scores.

## Delivered
- Added `domain/health_insights.dart`, a deterministic analysis engine operating on already-decrypted record payloads.
- Added a Health Insights tab in the patient application.
- Vital observations are grouped by observation code and unit; different units are never combined.
- Numeric observations with usable event dates are sorted chronologically and exposed as trend points.
- The UI shows a compact sparkline, measurement count, date span, latest recorded value and arithmetic change from first to latest measurement.
- The change statement is explicitly descriptive and not a clinical interpretation.
- Medication summary counts only statements marked `active`; other statuses are counted separately.
- Allergy and condition summaries include only entries explicitly marked `active`.
- Recent encounters are listed using their stored visit date and facility/reason where available.
- Existing encounter `follow_up_instructions` are surfaced as recorded text. This is not a reminder engine and no due date is inferred.
- Data-completeness notes identify missing numeric observations, missing usable observation fields, medication history gaps and missing encounter history.
- The insights page refreshes from the encrypted repository and computes summaries on-device.
- Added Flutter unit tests for unit separation, excluded observation statuses, active-status filtering, follow-up text and patient-profile exclusion.

## Clinical and privacy boundaries
- No clinical reference ranges, thresholds, diagnoses, treatment advice or risk scores are applied.
- The system does not label a measurement normal or abnormal.
- A change between first and latest observation is not evidence of improvement or deterioration.
- Only the latest record version returned by the repository is analyzed.
- All inputs are decrypted locally; no plaintext clinical data or insight payload is transmitted.
- Insights are deterministic and do not call an AI model.
- Follow-up instructions are displayed verbatim from saved encounters; the app does not invent a schedule or notification.
- An absent allergy or condition entry is not interpreted as absence of that condition/allergy.

## Acceptance checks
1. Record multiple measurements of the same observation code and unit and verify the displayed series and arithmetic change.
2. Record the same code using different units and verify separate trend cards.
3. Confirm cancelled and entered-in-error observations are excluded.
4. Confirm medication, allergy and condition summaries include only explicit `active` statuses.
5. Confirm follow-up text is sourced verbatim from encounter records.
6. Confirm empty datasets produce missing-data notes rather than synthetic values.
7. Confirm patient profile records are not counted as clinical events.
8. Verify no remote API call or plaintext database index is added by the insights feature.
9. Run Flutter analyzer, unit tests and Android device verification.

## Known limitations
- No reference intervals or clinical decision support are included.
- Trend plots are descriptive, with no statistical significance or time-weighted analysis.
- Follow-up text is not a reminder or scheduling system.
- In-memory analysis may need pagination or incremental computation for very large vaults.
- The Flutter SDK was unavailable in the build environment; analyzer, tests and device builds remain pending.

## Exit gates
- Execute the Flutter test suite and analyzer on a supported Flutter environment.
- Add accessibility labels and screen-reader semantics to trend charts.
- Consider clinician-reviewed reference intervals only in a separately governed future feature.
- Add explicit data freshness and provenance summaries before any external sharing.
- Complete clinical safety review before presenting any future interpretive insight.
