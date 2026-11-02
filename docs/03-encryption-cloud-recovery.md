# Stage 03 — Encryption & Cloud Recovery

**Build:** 0.3.0 foundation  
**Status:** Cryptographic reference implementation and opaque encrypted-backup API implemented. Flutter secure-storage/SQLCipher integration, production object storage, migrations and recovery UX remain open.

## 1. Security objective
Patient record plaintext and vault data-encryption keys (DEKs) are created and used on the patient client. The backend stores encrypted record payloads and encrypted key envelopes only. Account authentication does not unlock the vault; account recovery does not automatically recover the vault key.

## 2. Key hierarchy
- **Vault DEK:** random 256-bit key generated on a trusted client. Encrypts record payloads using AES-256-GCM.
- **Recovery secret:** independent random 256-bit secret generated client-side and shown to the patient once. It is never sent to the server.
- **Recovery KEK:** derived from the recovery secret using HKDF-SHA-256 with a vault-specific salt and fixed protocol info. It wraps the vault DEK using AES-256-GCM.
- **Device key agreement:** each device has an X25519 key pair. The private key remains in platform secure storage. A per-device envelope wraps the vault DEK using ephemeral X25519, HKDF-SHA-256 and AES-256-GCM.
- **Device signing key:** separate Ed25519 key used for trusted-device proof-of-possession. Do not reuse an Ed25519 key as an X25519 key.

The server stores only the wrapped DEK envelopes. It does not receive the DEK, recovery secret, recovery KEK, device private key or plaintext record content.

## 3. Record encryption
- Algorithm: AES-256-GCM.
- Nonce: 96 bits (12 bytes), generated randomly for every encryption operation.
- Authentication tag: 128 bits (16 bytes).
- Associated data binds protocol version, purpose, vault ID, object ID and object version.
- Ciphertext integrity hash: SHA-256, used for transfer/storage corruption detection. The GCM tag remains the cryptographic authenticity check.
- Every updated object version must use a fresh nonce. Never reuse a nonce with the same DEK.

The Python implementation in `backend/ujexa_api/crypto/envelope.py` is a reference implementation and test oracle. The Flutter client must independently implement the same protocol with maintained cryptographic libraries and conformance vectors before production use.

## 4. Recovery model
1. On initial vault setup, the client generates the vault DEK and a random recovery secret.
2. The client wraps the DEK with a recovery KEK derived from that secret.
3. The client displays the recovery secret once and requires the patient to confirm they have stored it safely.
4. The server stores the recovery-wrapped DEK envelope, never the recovery secret.
5. A new trusted device generates a new X25519 key pair and enrolls it.
6. An already trusted client or recovery flow unwraps the vault DEK locally and creates a new device-specific wrapped envelope.
7. If the patient loses all devices and the recovery secret, the encrypted vault is intentionally unrecoverable. Support staff cannot bypass this.
8. If the recovery secret is compromised, the patient must rotate the vault DEK and re-encrypt affected data, then replace recovery/device envelopes. Rotation and re-encryption tooling is future work.

A random 256-bit recovery secret is not a memorable password. Product UX must offer safe display, confirmation, secure export/print guidance and clear warnings against screenshots/cloud notes. Do not derive the recovery key from the account password.

## 5. Cloud backup API
The API currently supports:
- Upload immutable encrypted object versions.
- List metadata for the user's encrypted objects.
- Download ciphertext and nonce for client-side decryption.
- Delete an encrypted object version.
- Store and list opaque recovery/device key envelopes.
- Validate algorithm identifiers, nonce sizes, ciphertext size and ciphertext SHA-256.
- Enforce authenticated subject ownership.
- Require a registered, active trusted device with an X25519 public key for device-recipient envelopes.
- Hide revoked envelopes; revoking a device revokes its associated vault-key envelopes.

Current development persistence stores ciphertext bytes in the relational database. Production should move larger encrypted payloads to private object storage with opaque object IDs, strict tenant authorization, retention/versioning and integrity verification. The relational database should retain only necessary metadata and object references.

## 6. Metadata exposure
Even with encrypted payloads, the service can currently observe account subject, vault ID, object ID, version, ciphertext length, algorithm, timestamps, ciphertext hash, envelope recipient type and device ID. This can reveal usage patterns. Production privacy review must minimize, partition or pad metadata where practical and disclose remaining metadata in the privacy notice.

## 7. Stage 03 API
| Method | Route | Purpose |
|---|---|---|
| POST | `/v1/vaults/{vault_id}/objects` | Upload encrypted object |
| GET | `/v1/vaults/{vault_id}/objects` | List encrypted object metadata |
| GET | `/v1/vaults/{vault_id}/objects/{object_id}/{version}` | Download ciphertext |
| DELETE | `/v1/vaults/{vault_id}/objects/{object_id}/{version}` | Delete encrypted version |
| POST | `/v1/vaults/{vault_id}/key-envelopes` | Store wrapped DEK envelope |
| GET | `/v1/vaults/{vault_id}/key-envelopes` | Retrieve active wrapped envelopes |

## 8. Local setup and tests
```bash
cd backend
pip install -r requirements.txt
pytest -q
```
The current implementation is a backend/reference foundation. It is not yet a complete production E2EE service.

## 9. Outstanding production gates
- Implement Flutter vault encryption and decryption with protocol test vectors.
- Integrate SQLCipher-backed local persistence and safe key handling.
- Store device X25519 private keys using platform secure storage / hardware-backed facilities where available.
- Build recovery-secret creation, confirmation, backup and restore UX.
- Implement multi-device provisioning and revocation end to end.
- Add production database migrations and object storage.
- Add quotas, rate limits, upload/download streaming, lifecycle and retention controls.
- Add backup restore drills, corruption tests, key rotation and recovery-loss tests.
- Review metadata leakage, client compromise, rooted/jailbroken devices and backup exclusions.
- Obtain independent cryptographic/security review before real patient data is used.

## 10. Explicit non-goals
The API must never decrypt records, receive the recovery secret, receive a plaintext DEK, accept account passwords, or offer staff a vault decryption override.
