# Architecture Decision Records

## ADR-001 — Modular monolith first
**Decision:** Begin with a modular monolith and explicit domain boundaries.  
**Reason:** Avoid premature distributed-system complexity while preserving the ability to extract high-risk/high-load services later.  
**Boundaries:** identity/device trust; patient profile/record; documents; medication/checkups; measurements/lifestyle; analytics/AI; consent/emergency disclosure; encrypted sync/recovery; reporting/interoperability; audit/notifications/operations.

## ADR-002 — Patient client and service stack
**Decision:** Flutter patient mobile app; React/Next.js clinician and administration portals; Python/FastAPI backend.  
**Reason:** Cross-platform patient experience and a stable API boundary between clients and services.

## ADR-003 — Local and server storage
**Decision:** SQLCipher-backed SQLite (or equivalent) locally; PostgreSQL for server metadata and non-E2EE records; encrypted object storage for attachments.  
**Constraint:** Ciphertext-only cloud record storage in the end-to-end encrypted design.

## ADR-004 — Authentication is not key recovery
**Decision:** Keep account authentication and cryptographic recovery separate.  
**Reason:** Password reset or OAuth re-authentication must not by itself decrypt patient records. A documented recovery-key/key hierarchy design is required and must be tested against loss of all devices.

## ADR-005 — UI prototype data
**Decision:** Stage 01 uses synthetic display data and transient interaction state only.  
**Reason:** No production persistence, secrets or real patient information are appropriate before the data protection architecture is implemented.
