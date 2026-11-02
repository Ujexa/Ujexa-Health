# Stage 19 — Medical Document Understanding

## Objective
Extend on-device image OCR into page-aware PDF scanning and conservative document understanding. Keep original files encrypted and require explicit patient review before retaining extracted text or candidate annotations.

## Delivered
- Added local PDF page rendering with `pdfx`, followed by on-device Google ML Kit Latin-script OCR.
- Supports PDF documents up to 20 pages per extraction run; original documents up to the existing 20 MB capture limit remain encrypted in the document store.
- Image extraction now returns page-aware extraction output as well.
- Temporary rendered images are written to app cache and removed after recognition; the PDF document and recognizer are closed in cleanup paths.
- Added deterministic keyword-based document type suggestions for lab reports, prescriptions, discharge summaries, imaging reports, referrals, vaccination records and insurance documents.
- Added conservative candidate detection for numeric values with common units and simple medication instruction phrases.
- Candidate annotations retain evidence text, page number and a heuristic review score.
- Added a patient review dialog for extracted text and individually selectable candidate annotations.
- Accepted extracted text and candidate annotations are saved inside the encrypted document record payload. Accepted annotations are marked `patient_accepted_unverified`.
- No candidate is automatically promoted into a structured observation, medication statement, allergy, condition or encounter.
- Added unit tests for classification, candidate extraction, page attribution and empty text.

## Privacy, provenance and safety
- PDF rendering and OCR are local on-device operations. No document content is sent to an external AI/OCR service.
- Original PDF/image bytes remain encrypted by `EncryptedDocumentStore`.
- Extracted text and accepted candidate annotations are stored in the encrypted patient record payload.
- Patient acceptance confirms only that the patient chose to retain the extraction; it is not clinician verification.
- Classification and candidate scores are simple heuristics, not calibrated probabilities or clinical confidence.
- The extraction patterns are intentionally limited. A candidate can be incorrect, incomplete, or miss context such as reference ranges, units, medication formulation or timing.
- No diagnosis, treatment, drug interaction, risk score or autonomous clinical action is generated.

## Verification
- Backend regression tests: 31 passed.
- Python `compileall`: passed.
- ZIP integrity: passed.
- Dart tests added but not executed because Flutter/Dart SDK is unavailable in this environment.
- Flutter analyzer, formatter, Android/iOS builds, PDF plugin compatibility and physical-device OCR verification remain pending.

## Known limitations / future work
1. PDF OCR is rendered-page OCR, not native embedded PDF text extraction. This can be slower and less accurate for small print.
2. Maximum extraction size is 20 pages per run; larger documents can still be stored encrypted.
3. Latin-script OCR only; multilingual script selection is future work.
4. Candidate detection is intentionally narrow and does not parse tables, reference ranges, dates, medicine strengths or complete prescription regimens reliably.
5. Page attribution is retained in extracted text and candidate evidence; precise bounding boxes and source coordinates are not yet captured.
6. Structured record creation must remain a separate patient-confirmed workflow with field-level provenance and, where appropriate, clinician verification.
7. Validate `pdfx` native platform setup, memory use, malformed/encrypted PDF handling, cleanup, large page processing and Android/iOS behaviour on real devices.
