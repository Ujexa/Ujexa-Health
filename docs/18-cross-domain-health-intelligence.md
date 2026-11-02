# Stage 18 — Cross-Domain Health Intelligence

## Objective
Bring together dated information from symptoms, observations, medication dose events, encounters, journal entries and medical documents. Surface temporal overlaps with transparent source links, without treating correlation as causation.

## Delivered
- Added `CrossDomainHealthIntelligence`, a deterministic local analysis engine.
- Compares symptom entries with observations, medication dose events, journal entries and encounters within a fixed ±24-hour window.
- Uses explicit `encounter_id` links to associate measurements with a visit when present.
- Finds document-date overlaps with symptom, observation, dose, encounter and journal records on the same calendar date. This is a date-level clue only; document content is not interpreted.
- Returns source record IDs, dates, event counts, comparison type and explanatory limitations.
- Added a Cross-domain Relationships panel to Health Insights with record coverage counts and a list of dated overlaps.
- Selecting a relationship opens a detail sheet showing the underlying source records and their dates.
- Existing symptom/journal and longitudinal insights remain separate and available.

## Interpretation and safety
- The primary symptom comparisons use a ±24-hour time window. This is a software comparison window, not a clinical dosing window or medically meaningful threshold.
- Document comparisons use calendar-date overlap only.
- The engine does not infer causation, medication adverse effects, drug interactions, diagnoses, disease risk or treatment.
- A relationship means only that records were recorded within the selected time window or explicitly linked by an encounter ID.
- No records are rewritten, verified or promoted by this analysis.
- All analysis runs locally against decrypted records. No external AI or remote service is used.

## Verification
- Added Dart unit tests for symptom/measurement overlap, out-of-window exclusion, symptom/medication and symptom/journal comparisons, explicit encounter links and document-date overlap.
- Backend regression tests: 31 passed.
- Python `compileall`: passed.
- ZIP integrity: passed.
- Flutter/Dart SDK unavailable; Dart tests, analyzer, formatter, native builds and device verification remain pending.

## Known limitations / future work
1. Date precision is limited by the source records; all-day dates and uncertain historical dates should be represented explicitly in future schemas.
2. The fixed ±24-hour window is not configurable and should not be interpreted as a medical threshold.
3. The current analysis uses symptom entries as the anchor for most co-occurrence checks; it does not establish population-level or within-person statistical association.
4. Medication events are patient-reported and do not prove ingestion.
5. Document content is not matched to structured data; OCR text and field-level extraction provenance are future work.
6. Add patient-controlled date windows, richer source navigation, clinician-consented export and privacy/audit controls.
