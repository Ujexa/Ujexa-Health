# Stage 17 — Symptom & Health Journal Intelligence

## Objective
Add structured patient-reported symptom episodes and personal health journal entries, then provide descriptive summaries of recurring entries and self-rated day-to-day context.

## Delivered

### Symptom capture
- New encrypted `symptom_entry` record type.
- Captures symptom name, body area/system, patient-rated severity (1–10), occurrence date, optional duration, possible triggers and notes.
- Possible triggers are explicitly labelled as patient observations, not confirmed causes.
- Validation rejects missing symptom names, unsupported body areas and severity outside 1–10.
- The Symptoms action in the Add menu opens the new symptom capture form.

### Health journal
- New encrypted `health_journal` record type.
- Captures free-text patient journal entries and optional mood, energy and stress self-ratings (each 1–5).
- Ratings are personal self-ratings, not validated clinical scales.
- Validation bounds each supplied score to 1–5.
- The Journal action in the Add menu opens the journal capture form.

### Timeline and intelligence
- Both record types appear in the unified health timeline and can be searched.
- Added a local `SymptomJournalIntelligence` aggregation engine.
- Groups symptom episodes by symptom name (case-insensitive), counts episodes, calculates mean/highest patient-rated severity, shows latest occurrence and ranks frequently noted possible triggers.
- Summarizes journal entry count, distinct days with entries and mean mood/energy/stress ratings.
- Health Insights now displays a Symptom & Journal Patterns panel alongside existing medication and longitudinal summaries.
- Added Pydantic backend reference schemas and included both record types in the canonical discriminated union.

## Privacy, provenance and safety
- Entries are saved through the existing patient record repository and encrypted before local SQLCipher persistence.
- Provenance remains patient-entered and unverified.
- Symptom recurrence and trigger frequencies are descriptive summaries only. They do not establish causation, diagnosis, disease risk or treatment.
- No external AI or remote service is used.
- Journal text is sensitive free text; it remains within the encrypted patient record payload.

## Verification
- Backend tests: 31 passed.
- Python `compileall`: passed.
- ZIP integrity: passed.
- Added Dart unit tests for symptom grouping, severity summaries, trigger counts, journal score aggregation and empty-data behaviour.
- Flutter/Dart SDK unavailable in the environment, so Dart tests, analyzer, formatting, Android/iOS builds and device verification remain pending.

## Remaining work
1. Add richer symptom taxonomy and optional patient-defined symptom labels without forcing a diagnosis code.
2. Add duration/frequency visual timelines and patient-controlled symptom-to-vital/medication/encounter comparisons.
3. Support structured symptom context such as onset pattern, impact on daily activity and patient-selected associated factors.
4. Add journal export and selective clinician sharing with consent and audit.
5. Add field-level provenance and clinician verification workflows.
6. Keep causal inference, clinical risk scoring and diagnosis out of scope unless separately validated and clinically governed.
