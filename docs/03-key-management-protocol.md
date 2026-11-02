# Ujexa Vault Protocol — Key Management Reference v1

## Domain separation
Protocol messages use the `UJEXA_VAULT_V1` namespace and distinct purpose labels for record encryption, recovery wrapping and device wrapping.

## Record associated data
UTF-8:
`UJEXA_VAULT_V1|record|{vault_id}|{object_id}|{version}`

## Recovery wrapping
- Secret: 32 random bytes.
- Salt: SHA-256(UTF-8 vault ID).
- KDF: HKDF-SHA-256, output 32 bytes.
- Info: `UJEXA_VAULT_V1_RECOVERY_KEK`.
- Wrap cipher: AES-256-GCM.
- AAD: `UJEXA_VAULT_V1|key-wrap|{vault_id}|recovery-key-envelope|1`.
- Envelope fields: `algorithm`, `nonce`, `wrapped_key`, `version`.

## Device wrapping
- Recipient: 32-byte X25519 public key.
- Ephemeral: fresh X25519 key pair for every envelope.
- Shared secret: X25519 ephemeral private × recipient public.
- Salt: SHA-256(ephemeral public || recipient public || UTF-8 vault ID).
- KDF: HKDF-SHA-256, output 32 bytes.
- Info: `UJEXA_VAULT_V1_DEVICE_KEY_WRAP`.
- Wrap cipher: AES-256-GCM.
- AAD: `UJEXA_VAULT_V1|key-wrap|{vault_id}|device-key-envelope|1`.
- Envelope fields: `algorithm`, `ephemeral_public_key`, `nonce`, `wrapped_key`, `version`.

## Ciphertext representation
The reference API stores AES-GCM output as ciphertext concatenated with the 16-byte authentication tag. The 12-byte nonce is stored separately. Base64url is used at JSON boundaries without padding.

## Key safety rules
- No key or plaintext in logs, crash reports, analytics, clipboard or server telemetry.
- Fresh random nonce for every AES-GCM encryption under a given key.
- Never use a password directly as an encryption key.
- Never reuse Ed25519 signing key material for X25519 key agreement.
- Device revocation invalidates the device's server-side key envelope but cannot erase a compromised private key from an offline device. Rotate the vault DEK if compromise is suspected.
- Recovery-secret loss cannot be bypassed by customer support.
