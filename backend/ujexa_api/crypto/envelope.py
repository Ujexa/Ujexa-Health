"""Client-side cryptographic reference implementation for Ujexa Health.

This module is a reference/test implementation. In production the same protocol
must be implemented in the Flutter client with vetted platform libraries and
hardware-backed key storage where supported. The API must never call these
functions or receive plaintext keys.
"""
from __future__ import annotations

import base64
import hashlib
import os
from dataclasses import dataclass

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

CONTENT_ALGORITHM = "AES-256-GCM"
WRAP_RECOVERY_ALGORITHM = "AES-256-GCM-HKDF-SHA256-RECOVERY"
WRAP_DEVICE_ALGORITHM = "X25519-HKDF-SHA256-AES-256-GCM"
KEY_BYTES = 32
NONCE_BYTES = 12
TAG_BYTES = 16

def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")

def unb64u(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))

def generate_vault_key() -> bytes:
    """Generate a random 256-bit vault data-encryption key (DEK)."""
    return AESGCM.generate_key(bit_length=256)

def generate_recovery_secret() -> bytes:
    """Generate a random 256-bit recovery secret. It is shown once to the user."""
    return os.urandom(KEY_BYTES)

def generate_device_keypair() -> tuple[X25519PrivateKey, bytes]:
    """Generate X25519 device keypair; private key must remain in platform secure storage."""
    private_key = X25519PrivateKey.generate()
    public_bytes = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    return private_key, public_bytes

def _aad(vault_id: str, object_id: str, version: int, purpose: str) -> bytes:
    if not vault_id or not object_id or version < 1:
        raise ValueError("Invalid vault encryption context")
    return f"UJEXA_VAULT_V1|{purpose}|{vault_id}|{object_id}|{version}".encode("utf-8")

@dataclass(frozen=True)
class EncryptedPayload:
    algorithm: str
    nonce: bytes
    ciphertext: bytes
    sha256: str
    version: int

def encrypt_payload(plaintext: bytes, dek: bytes, vault_id: str, object_id: str, version: int) -> EncryptedPayload:
    if len(dek) != KEY_BYTES:
        raise ValueError("Vault DEK must be 32 bytes")
    nonce = os.urandom(NONCE_BYTES)
    ciphertext = AESGCM(dek).encrypt(nonce, plaintext, _aad(vault_id, object_id, version, "record"))
    return EncryptedPayload(CONTENT_ALGORITHM, nonce, ciphertext, hashlib.sha256(ciphertext).hexdigest(), version)

def decrypt_payload(payload: EncryptedPayload, dek: bytes, vault_id: str, object_id: str) -> bytes:
    if payload.algorithm != CONTENT_ALGORITHM or len(dek) != KEY_BYTES or len(payload.nonce) != NONCE_BYTES:
        raise ValueError("Unsupported encrypted payload parameters")
    if hashlib.sha256(payload.ciphertext).hexdigest() != payload.sha256:
        raise ValueError("Ciphertext integrity hash mismatch")
    return AESGCM(dek).decrypt(payload.nonce, payload.ciphertext, _aad(vault_id, object_id, payload.version, "record"))

def _recovery_kek(recovery_secret: bytes, vault_id: str) -> bytes:
    if len(recovery_secret) != KEY_BYTES:
        raise ValueError("Recovery secret must be 32 random bytes")
    return HKDF(algorithm=hashes.SHA256(), length=KEY_BYTES, salt=hashlib.sha256(vault_id.encode()).digest(),
                info=b"UJEXA_VAULT_V1_RECOVERY_KEK").derive(recovery_secret)

def wrap_vault_key_for_recovery(dek: bytes, recovery_secret: bytes, vault_id: str) -> dict[str, str]:
    if len(dek) != KEY_BYTES:
        raise ValueError("Vault DEK must be 32 bytes")
    nonce = os.urandom(NONCE_BYTES)
    aad = _aad(vault_id, "recovery-key-envelope", 1, "key-wrap")
    wrapped = AESGCM(_recovery_kek(recovery_secret, vault_id)).encrypt(nonce, dek, aad)
    return {"algorithm": WRAP_RECOVERY_ALGORITHM, "nonce": b64u(nonce), "wrapped_key": b64u(wrapped), "version": "1"}

def unwrap_vault_key_from_recovery(envelope: dict[str, str], recovery_secret: bytes, vault_id: str) -> bytes:
    if envelope.get("algorithm") != WRAP_RECOVERY_ALGORITHM:
        raise ValueError("Unsupported recovery envelope algorithm")
    nonce = unb64u(envelope["nonce"])
    wrapped = unb64u(envelope["wrapped_key"])
    return AESGCM(_recovery_kek(recovery_secret, vault_id)).decrypt(
        nonce, wrapped, _aad(vault_id, "recovery-key-envelope", 1, "key-wrap")
    )

def _device_wrap_key(shared_secret: bytes, vault_id: str, ephemeral_public: bytes, recipient_public: bytes) -> bytes:
    salt = hashlib.sha256(ephemeral_public + recipient_public + vault_id.encode()).digest()
    return HKDF(algorithm=hashes.SHA256(), length=KEY_BYTES, salt=salt,
                info=b"UJEXA_VAULT_V1_DEVICE_KEY_WRAP").derive(shared_secret)

def wrap_vault_key_for_device(dek: bytes, recipient_public_bytes: bytes, vault_id: str) -> dict[str, str]:
    if len(dek) != KEY_BYTES or len(recipient_public_bytes) != 32:
        raise ValueError("Invalid DEK or X25519 public key")
    recipient_public = X25519PublicKey.from_public_bytes(recipient_public_bytes)
    ephemeral_private = X25519PrivateKey.generate()
    ephemeral_public = ephemeral_private.public_key().public_bytes(
        encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw
    )
    shared = ephemeral_private.exchange(recipient_public)
    wrap_key = _device_wrap_key(shared, vault_id, ephemeral_public, recipient_public_bytes)
    nonce = os.urandom(NONCE_BYTES)
    aad = _aad(vault_id, "device-key-envelope", 1, "key-wrap")
    wrapped = AESGCM(wrap_key).encrypt(nonce, dek, aad)
    return {
        "algorithm": WRAP_DEVICE_ALGORITHM,
        "ephemeral_public_key": b64u(ephemeral_public),
        "nonce": b64u(nonce),
        "wrapped_key": b64u(wrapped),
        "version": "1",
    }

def unwrap_vault_key_for_device(envelope: dict[str, str], recipient_private: X25519PrivateKey,
                                vault_id: str) -> bytes:
    if envelope.get("algorithm") != WRAP_DEVICE_ALGORITHM:
        raise ValueError("Unsupported device envelope algorithm")
    ephemeral_public = unb64u(envelope["ephemeral_public_key"])
    recipient_public = recipient_private.public_key().public_bytes(
        encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw
    )
    shared = recipient_private.exchange(X25519PublicKey.from_public_bytes(ephemeral_public))
    wrap_key = _device_wrap_key(shared, vault_id, ephemeral_public, recipient_public)
    return AESGCM(wrap_key).decrypt(
        unb64u(envelope["nonce"]), unb64u(envelope["wrapped_key"]),
        _aad(vault_id, "device-key-envelope", 1, "key-wrap")
    )
