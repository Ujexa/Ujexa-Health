# Stage 21 — Patient-Confirmed Clinical Record Promotion

## Objective
Provide a deliberate review step between extracted document annotations and the longitudinal clinical record. The patient must confirm and, where necessary, edit each supported field before promotion.

## Delivered
- Added a Document Review Workspace reachable from the Add menu.
- Workspace lists unreviewed annotations on encrypted medical document records.
- Displays source document title, page and exact evidence excerpt.
- Laboratory candidates can be edited for test name and numeric result/unit, then promoted into canonical observation records.
- Medication instruction candidates require a patient-entered medication name and allow strength/instruction editing before promotion into a medication statement.
- Medication statements are created with `status: unknown`, no inferred dose times, and explanatory notes that clarification is required before reminders can be configured.
- Date candidates remain attached to their source document; they are not promoted into a clinical observation.
- Promoted records retain source document ID, source page, evidence text and imported-document provenance.
- Provenance distinguishes `patient_confirmed` from `clinician_verified`.
- Original document annotation is versioned and marked `promoted_patient_confirmed` after successful promotion.
- Repository serialization now preserves explicitly supplied provenance instead of overwriting it with generic patient/unverified provenance.

## Safety and integrity
- Promotion is an explicit patient action. It is not automatic.
- Patient confirmation does not equal clinician verification.
- Medication frequency, dose schedule and reminder times are never inferred from extracted phrases.
- Lab values are not interpreted against reference ranges and do not trigger diagnosis or treatment advice.
- Date candidates remain pending until a dedicated date-confirmation workflow is implemented.
- Source document and page evidence remain attached to promoted record payloads.
- No external AI service is used.

## Verification
- Backend regression tests: pending execution in this stage.
- Python compileall: pending execution in this stage.
- ZIP integrity: pending packaging verification.
- Flutter/Dart tests, analyzer, formatter, native builds and device verification pending because Flutter/Dart SDK is unavailable.

## Known limitations
1. The review workspace currently promotes supported lab-result and medication-instruction candidates only.
2. Laboratory extraction is limited to simple line-oriented patterns and numeric values with recognized units.
3. Medication promotion requires a manually supplied medicine name; extracted instruction text remains verbatim and unstructured.
4. Date candidates are not yet promotable.
5. Duplicate detection is not yet implemented. Patients should review existing records before confirming a candidate.
6. Source evidence is retained in the encrypted record payload; future versions should add typed, field-level source references to every canonical schema.
