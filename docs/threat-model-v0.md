# Ujexa Health — Initial Threat Model (Stage 00)

**Scope:** Patient mobile client, future API, encrypted synchronization, documents, sharing and emergency access. This is an initial engineering threat model, not a completed security assessment.

| Threat | Impact | Initial mitigation / required validation |
|---|---|---|
| Lost or stolen unlocked device | Exposure of personal health data | Device-bound key protection, app lock, session revocation, remote revoke where possible |
| Cloud/database compromise | Bulk record disclosure | Client-side authenticated encryption, ciphertext-only storage, key separation |
| Account takeover | Unauthorized access/sharing | Passkeys/MFA, risk controls, device trust, session revocation |
| Weak recovery design | Permanent loss or unauthorized decryption | Separate key recovery, recovery credentials, loss-of-all-devices tests |
| Malicious/overprivileged clinician | Unauthorized disclosure | Professional verification, patient consent, least privilege, purpose/time limits, audit |
| QR/emergency credential abuse | Public exposure of health data | Minimal emergency profile; QR is not identity proof; expiry and access logging |
| OCR extraction error | Incorrect medication/result data | Preserve original, confidence, human review, provenance |
| Sync conflict or replay | Corrupt/overwritten history | Versioning, integrity checks, conflict resolution, audit trail |
| Metadata leakage | Sensitive patterns inferred from usage | Minimize metadata, document observable server fields |
| AI hallucination or unsafe trend | Misleading health guidance | Qualified outputs, source traceability, evaluation, no diagnosis/prescribing |
| Insider access | Unauthorized record viewing | No routine plaintext admin access, scoped break-glass, audit and monitoring |

## Security design constraints
- Use established cryptographic libraries; do not design custom cryptography.
- Authenticated encryption and TLS in transit.
- Separate identity credentials from data-encryption keys.
- Key-encryption keys and hardware-backed storage where available.
- Threat-model metadata leakage, backup, recovery, revocation and multi-device pairing.
- Emergency access is minimal, purpose-limited, time-limited and audited.
- Verify professional identity and relevant registration/facility affiliation.
- Patient-visible access history and post-emergency notification where appropriate.

## Review gates
Before private beta: independent review of key management, sync, authorization, recovery and audit. Before clinical/emergency use: clinical, legal, privacy and security review. Assess Ghana Data Protection Act, 2012 (Act 843), healthcare obligations and cross-border requirements with qualified counsel.
