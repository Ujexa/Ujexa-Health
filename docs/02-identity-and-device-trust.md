# Stage 02 — Identity & Device Trust

**Status:** Backend foundation implemented; production identity-provider integration remains configuration-dependent.  
**Version:** 0.2.0

## Goals
Establish authenticated patient identity, MFA assurance, session revocation, trusted-device enrollment and device revocation. Account authentication is deliberately separate from the cryptographic recovery of medical-record keys.

## Authentication protocol
- Use an external OpenID Connect provider.
- Mobile app uses Authorization Code Flow with PKCE (S256) through the system browser / platform AppAuth implementation.
- No embedded webview password collection.
- API accepts provider-issued access tokens only.
- API validates signature using the configured JWKS endpoint, strict issuer, audience, expiry, issued-at, subject and token ID (`jti`).
- Only explicitly configured asymmetric signing algorithms RS256 and ES256 are accepted.
- Provider manages credential lifecycle, passkeys/WebAuthn and MFA. Ujexa API does not store passwords or passkey private keys.
- MFA is required by default: token must include `amr: ["mfa", ...]` or the configured `acr` value.

## Trusted-device enrollment
1. Authenticated user requests a one-time device challenge.
2. API creates a random nonce, bound to the authenticated subject and a five-minute expiry.
3. Client generates an Ed25519 key pair using platform-protected key storage.
4. Client signs the canonical message:
   `UJEXA_DEVICE_ENROLLMENT_V1\\n{nonce}\\n{subject}\\n{device_name}`
5. API verifies proof-of-possession, consumes the challenge and stores the public key only.
6. Device appears in the trusted-device list.
7. Device revocation marks it revoked and prevents further use of tokens carrying its `device_id` claim.

The Ed25519 and X25519 private keys must never be exported to application logs or sent to the API. The Ed25519 signature binds the submitted X25519 public key to the authenticated device enrollment. Production Flutter implementation must use Android Keystore / iOS Keychain-backed key material or an independently reviewed equivalent. The current API accepts raw Ed25519 public keys for enrollment; secure hardware-backed key generation and signing are client tasks.

## Session management
- OIDC access tokens are short-lived and provider-issued.
- Every protected request checks the token's `jti` against persistent revoked-session records.
- `POST /v1/identity/sessions/revoke-current` revokes the current token ID.
- Refresh-token rotation, refresh-token reuse detection and provider-side global logout must be configured at the identity provider; they are not simulated by this API.
- Access tokens should carry a provider-issued `device_id` claim after device enrollment. If present, the API checks that the device belongs to the subject and remains active. This claim mapping is a production integration gate.

## Account recovery boundary
This stage restores access to an account identity only. It does not decrypt medical records, recreate data-encryption keys or reset cryptographic recovery material. Stage 03 must specify a separate recovery-key hierarchy and test loss of every device.

## API routes
| Method | Route | Purpose |
|---|---|---|
| GET | `/health` | Service liveness |
| GET | `/v1/identity/me` | Current verified identity |
| POST | `/v1/identity/device-challenges` | Issue one-time enrollment challenge |
| POST | `/v1/identity/devices` | Enroll device using Ed25519 proof |
| GET | `/v1/identity/devices` | List active trusted devices |
| DELETE | `/v1/identity/devices/{device_id}` | Revoke a trusted device |
| POST | `/v1/identity/sessions/revoke-current` | Revoke current access-token session |

## Local setup
```bash
cd backend
python -m venv .venv
# activate the virtual environment
pip install -r requirements.txt
cp .env.example .env
# Set real issuer, audience and JWKS URL before testing real OIDC tokens.
uvicorn ujexa_api.main:app --reload
```
The local development database defaults to SQLite. Production database schema changes must use reviewed Alembic migrations; automatic `create_all` is development convenience only.

## Security limitations / integration gates
- Configure and test a real OIDC issuer; placeholder issuer/JWKS URLs are intentionally nonfunctional.
- Configure provider MFA policy, passkey enrollment and recovery.
- Configure the provider to issue and protect the `device_id` claim; test token/device binding end to end.
- Add refresh-token rotation and global logout controls at provider.
- Move challenge storage to a shared durable database in production; add rate limits and abuse controls.
- Add Alembic migrations, retention rules and security-event export/monitoring.
- Validate device key storage on supported Android/iOS versions.
- Complete threat modelling, penetration testing and privacy/legal review before real patient use.

## Exit criteria
- OIDC issuer/audience/JWKS validation tests pass.
- MFA-required and MFA-missing cases are tested.
- Passkey and MFA enrollment/recovery tested against the selected provider.
- Session revocation is enforced on every protected route.
- Device enrollment rejects invalid, expired, replayed and wrong-owner challenges.
- Device revocation blocks device-bound sessions.
- Account recovery is demonstrably separate from health-data key recovery.
- Device/session audit events are recorded and visible to the patient.
