# Stage 16 — Medical Document Intelligence

## Objective
Extend the Stage 09 encrypted document archive with a first, privacy-preserving document-understanding capability: on-device OCR for image-based medical documents, patient review of extracted text, encrypted retention of the reviewed text, and local timeline search.

## Delivered
- Added `DocumentTextExtractor` using Google ML Kit Text Recognition with the Latin script.
- OCR runs on-device for JPG, JPEG, PNG and WebP images. The selected image is written briefly to the app cache for native recognition and removed in a `finally` cleanup path.
- No image or extracted text is sent to a remote AI/OCR service.
- Added an explicit **Extract text from image** action to document capture.
- Extracted text is shown in a selectable review dialog before saving. The patient can inspect the OCR output; OCR errors and omissions remain possible.
- Original document bytes continue to be encrypted by `EncryptedDocumentStore`.
- When present, extracted text and extraction status are saved inside the encrypted `document_reference` payload through `PatientRecordRepository`.
- Extracted text participates in local timeline search and is available in the encrypted document record detail view.
- Extraction status distinguishes not run, no text detected, and OCR text reviewed by the patient.
- PDF and image documents can still be archived. PDF text extraction/OCR is not implemented in this stage; the UI explains this limitation.
- No clinical facts are automatically created from OCR. No medication, diagnosis, lab value or allergy is promoted into structured records.

## Privacy and provenance
- OCR processing is local to the device using the native ML Kit implementation.
- Extracted text is encrypted as part of the existing record payload. It is not placed in plaintext database metadata.
- The OCR output remains unverified. Patient review of text does not equal clinical verification.
- The original encrypted attachment remains the source artifact; extracted text is a derived representation and may contain recognition errors.
- This stage does not add external AI, cloud OCR, document uploads, clinician verification, or automatic clinical interpretation.

## Verification
- Backend regression tests: 29 passed.
- Python `compileall`: passed.
- ZIP integrity: passed.
- Flutter analyzer, Dart formatting, Flutter tests, Android/iOS builds and physical-device OCR tests were not run because a Flutter/Dart SDK and mobile device runtime are unavailable in this environment.
- The Google ML Kit Flutter dependency is added to `pubspec.yaml`; native platform compatibility and plugin setup must be confirmed by running `flutter pub get` and device builds.

## Known limitations and next work
1. OCR currently supports image documents only; scanned and text-based PDFs are stored but not parsed.
2. OCR uses the Latin recognition model; multilingual and non-Latin medical documents need script selection and validation.
3. No structured extraction candidates are generated yet. Future extraction must surface field-level confidence and source spans and require explicit patient review before creating records.
4. Add page-level OCR for multi-page PDFs, document classification, lab result candidate extraction, medication instruction extraction and symptom/encounter extraction.
5. Add extraction provenance linking each accepted field to its source document and exact text span.
6. Add OCR performance, memory, file cleanup and large-image tests.
7. Production DEK lifecycle, encrypted backup/sync, document malware/content validation, streaming encryption and independent security review remain open gates.
