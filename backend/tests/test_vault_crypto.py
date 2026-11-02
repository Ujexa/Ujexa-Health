import pytest
from ujexa_api.crypto.envelope import (
    generate_vault_key, generate_recovery_secret, generate_device_keypair,
    encrypt_payload, decrypt_payload, wrap_vault_key_for_recovery,
    unwrap_vault_key_from_recovery, wrap_vault_key_for_device,
    unwrap_vault_key_for_device,
)

def test_payload_encrypt_decrypt_and_context_binding():
    dek = generate_vault_key()
    original = b'{"kind":"patient-note","body":"synthetic fixture"}'
    payload = encrypt_payload(original, dek, "vault-a", "object-a", 1)
    assert payload.ciphertext != original
    assert decrypt_payload(payload, dek, "vault-a", "object-a") == original
    with pytest.raises(Exception):
        decrypt_payload(payload, dek, "vault-b", "object-a")

def test_ciphertext_hash_tampering_is_detected():
    dek = generate_vault_key()
    payload = encrypt_payload(b"fixture", dek, "vault-a", "object-a", 1)
    altered = type(payload)(payload.algorithm, payload.nonce, payload.ciphertext[:-1] + bytes([payload.ciphertext[-1] ^ 1]), payload.sha256, payload.version)
    with pytest.raises(ValueError, match="hash mismatch"):
        decrypt_payload(altered, dek, "vault-a", "object-a")

def test_recovery_secret_wraps_vault_key_without_server_secret():
    dek = generate_vault_key()
    recovery = generate_recovery_secret()
    envelope = wrap_vault_key_for_recovery(dek, recovery, "vault-a")
    assert unwrap_vault_key_from_recovery(envelope, recovery, "vault-a") == dek
    with pytest.raises(Exception):
        unwrap_vault_key_from_recovery(envelope, generate_recovery_secret(), "vault-a")

def test_device_envelope_uses_ephemeral_x25519_exchange():
    dek = generate_vault_key()
    private, public = generate_device_keypair()
    envelope = wrap_vault_key_for_device(dek, public, "vault-a")
    assert unwrap_vault_key_for_device(envelope, private, "vault-a") == dek
    other_private, _ = generate_device_keypair()
    with pytest.raises(Exception):
        unwrap_vault_key_for_device(envelope, other_private, "vault-a")
