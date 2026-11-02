# Stage 20 — Structured Clinical Data Extraction

## Objective
Convert OCR text into reviewable, field-level candidate annotations while preserving evidence and avoiding automatic creation of clinical records.

## Delivered
- Added structured extraction candidates for simple laboratory result lines, prescription instruction phrases and explicitly labelled date text.
- Laboratory candidates can include a test label, numeric value/unit and a nearby textual reference range when the line pattern is recognized.
- Prescription candidates retain the instruction phrase verbatim; no dosage schedule, dose timing or duration is inferred.
- Date candidates retain the original date string without silently resolving ambiguous locale formats.
- Each candidate carries the source evidence line/text, page number and heuristic confidence score.
- Patient review displays candidates individually and allows selection before retention.
- Accepted annotations are stored within the encrypted document record payload with `patient_accepted_unverified` status.
- Added a backend `DocumentFieldAnnotation` schema and included it in the medical document reference contract.
- Added Dart tests for lab value/range extraction, instruction extraction without schedule inference, date preservation and empty input.

## Safety and provenance
- These are deliberately narrow deterministic text patterns, not comprehensive clinical NLP.
- A candidate may be incomplete or incorrect due to OCR errors, layout, tables, locale or ambiguous labels.
- Heuristic confidence is not a calibrated probability or clinical confidence.
- Medication instructions are not converted to medication statements or reminder schedules.
- Lab candidates are not converted to observations, compared with clinical thresholds or used for diagnosis.
- Date strings remain verbatim; no ambiguous date interpretation is made.
- Patient acceptance only authorizes retaining an annotation. It does not establish clinical verification.
- No external AI or remote service is used.

## Verification
- Backend regression tests: pending execution in this stage.
- Python compileall: pending execution in this stage.
- ZIP integrity: pending packaging verification.
- Dart tests added but cannot be executed without Flutter/Dart SDK.
- Flutter analyzer, formatter, Android/iOS builds and device testing remain pending.

## Known limitations
1. Only simple single-line measurement patterns are recognized; multi-column lab tables and split labels/values are not parsed.
2. Reference range extraction is opportunistic and may capture adjacent text incorrectly.
3. Medication phrase extraction is intentionally minimal and does not reliably extract medicine name, strength, route, frequency, duration or PRN conditions.
4. Clinician identity, organization and diagnosis extraction are not implemented.
5. No structured record promotion workflow is implemented yet; candidates remain annotations on the source document.
6. Next work should implement explicit field-by-field confirmation into canonical records, with source document ID, page, evidence and verification status retained.
