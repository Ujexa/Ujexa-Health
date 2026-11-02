# Stage 09 — Encrypted Documents and Patient Profile

## Objective
Add patient-controlled personal profile and emergency-contact information, plus local encrypted medical-document capture and references in the longitudinal record.

## Delivered
- Added `EncryptedDocumentStore` for PDF and image attachments.
- Selected file bytes are encrypted with the existing AES-256-GCM record codec before being written to the app's private application-support directory.
- Attachment filenames on disk are opaque UUIDs with `.ujx` extension; the original filename is not persisted in the clear file path.
- Added document capture for lab reports, prescriptions, discharge summaries, imaging reports, referrals, vaccination records, insurance and other documents.
- Added a 20 MB file-size limit and supported file types PDF, JPEG, PNG and WebP.
- Document metadata is saved as the canonical `document_reference` resource with an encrypted blob ID.
- Added a patient profile screen with preferred/legal name, date of birth, sex at birth, blood group, height and emergency-contact fields.
- Profile is saved as a `patient_profile` resource through the encrypted repository. Updates create a new immutable version.
- Records timeline now displays document titles and can delete the encrypted local attachment when the document record is deleted.
- Added repository guards for patient-profile blood group and document-type values.

## Data and privacy boundaries
- Both document content and document metadata are encrypted locally before persistence.
- The document blob store is local-only. It does not upload, back up or synchronize attachments.
- File selection reads file bytes into application memory to encrypt them. The 20 MB limit bounds this prototype implementation; production should use streaming encryption for larger documents.
- The current app uses the Stage 07 development DEK provider and fixed development vault ID. Key recovery, rotation, device transfer and production key lifecycle remain incomplete.
- Emergency contacts are stored as profile information only. This stage does not send notifications, provide emergency access, or expose a lock-screen emergency card.
- No OCR, AI extraction, document interpretation or clinical diagnosis is performed.
- Deleting a document record deletes its local encrypted blob and tombstones the local metadata. There is no remote copy in this stage.

## Acceptance checks for device verification
1. Select a PDF and image; save each and confirm encrypted `.ujx` blobs appear in private app storage.
2. Inspect the blob bytes and confirm the original file header/content is not visible.
3. Read/decrypt a saved blob with its matching UUID and verify the original bytes.
4. Confirm a wrong blob ID or modified ciphertext fails authentication/decryption.
5. Save and edit patient profile fields; force-close and reopen; verify the latest profile version is restored.
6. Delete a document record and confirm both the metadata and local blob are removed.
7. Confirm no original filename, document title, DOB, emergency contact or clinical content is stored in plaintext database columns or attachment filenames.

## Exit gates
- Run Flutter analyzer/tests and Android device builds.
- Replace development key provider with the Stage 03 provisioned device-envelope and recovery flow.
- Add streaming file encryption/decryption, content-size quotas and robust crash cleanup.
- Implement encrypted backup/sync for blobs and metadata with remote tombstone propagation.
- Add consent/audit for emergency and clinician access before exposing those workflows.
- Add export/restore, malware/content validation, file handling hardening and independent security review.
