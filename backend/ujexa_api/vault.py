from __future__ import annotations

import base64
import hashlib
import json
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy import select, desc
from sqlalchemy.orm import Session

from .database import get_db
from .identity.auth import Identity
from .identity.dependencies import get_active_identity
from .identity.models import VaultObject, VaultKeyEnvelope, SecurityEvent, TrustedDevice

router = APIRouter(prefix="/v1/vaults", tags=["encrypted patient vault"])
MAX_CIPHERTEXT_BYTES = 8 * 1024 * 1024
ALLOWED_CONTENT_ALGORITHMS = {"AES-256-GCM"}
ALLOWED_ENVELOPE_ALGORITHMS = {
    "AES-256-GCM-HKDF-SHA256-RECOVERY",
    "X25519-HKDF-SHA256-AES-256-GCM",
}

class EncryptedObjectInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    object_id: str = Field(min_length=36, max_length=36)
    version: int = Field(ge=1, le=2_147_483_647)
    algorithm: str = Field(pattern=r"^AES-256-GCM$")
    nonce: str = Field(min_length=16, max_length=24)
    ciphertext: str = Field(min_length=22, max_length=12_000_000)
    ciphertext_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")

class KeyEnvelopeInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    envelope_id: str = Field(min_length=36, max_length=36)
    recipient_type: str = Field(pattern=r"^(recovery|device)$")
    recipient_id: str | None = Field(default=None, max_length=36)
    algorithm: str = Field(min_length=10, max_length=64)
    envelope_json: dict = Field()

def _uuid(value: str, label: str):
    try:
        UUID(value)
    except (ValueError, TypeError, AttributeError) as exc:
        raise HTTPException(status_code=422, detail=f"{label} must be a UUID") from exc

def _decode(value: str, label: str) -> bytes:
    try:
        padded = value + "=" * (-len(value) % 4)
        return base64.b64decode(padded, altchars=b"-_", validate=True)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Invalid {label} encoding") from exc

def _event(db: Session, subject: str, kind: str, target: str):
    db.add(SecurityEvent(id=str(uuid4()), subject=subject, event_type=kind, target_id=target))

@router.post("/{vault_id}/objects", status_code=status.HTTP_201_CREATED)
def put_encrypted_object(vault_id: str, payload: EncryptedObjectInput,
                         identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    _uuid(payload.object_id, "object_id")
    if payload.algorithm not in ALLOWED_CONTENT_ALGORITHMS:
        raise HTTPException(status_code=422, detail="Unsupported encryption algorithm")
    nonce = _decode(payload.nonce, "nonce")
    ciphertext = _decode(payload.ciphertext, "ciphertext")
    if len(nonce) != 12:
        raise HTTPException(status_code=422, detail="AES-256-GCM nonce must be 12 bytes")
    if len(ciphertext) < 16 or len(ciphertext) > MAX_CIPHERTEXT_BYTES:
        raise HTTPException(status_code=413, detail="Encrypted object must be between 16 bytes and 8 MiB")
    digest = hashlib.sha256(ciphertext).hexdigest()
    if digest != payload.ciphertext_sha256:
        raise HTTPException(status_code=422, detail="Ciphertext hash mismatch")

    existing = db.get(VaultObject, (payload.object_id, identity.subject, payload.version))
    if existing:
        # Immutable versions: use a new version number for edits.
        raise HTTPException(status_code=409, detail="This object version already exists")
    row = VaultObject(
        object_id=payload.object_id, subject=identity.subject, vault_id=vault_id,
        version=payload.version, algorithm=payload.algorithm, nonce=nonce,
        ciphertext=ciphertext, ciphertext_sha256=digest,
    )
    db.add(row)
    _event(db, identity.subject, "encrypted_vault_object_uploaded", payload.object_id)
    db.commit()
    return {"object_id": row.object_id, "version": row.version, "vault_id": row.vault_id,
            "ciphertext_sha256": digest, "stored": True, "plaintext_access": False}

@router.get("/{vault_id}/objects")
def list_encrypted_objects(vault_id: str, limit: int = Query(100, ge=1, le=500),
                            identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    rows = db.scalars(select(VaultObject).where(
        VaultObject.subject == identity.subject, VaultObject.vault_id == vault_id
    ).order_by(desc(VaultObject.created_at)).limit(limit)).all()
    return [{"object_id": r.object_id, "version": r.version, "algorithm": r.algorithm,
             "ciphertext_sha256": r.ciphertext_sha256, "ciphertext_bytes": len(r.ciphertext),
             "created_at": r.created_at.isoformat()} for r in rows]

@router.get("/{vault_id}/objects/{object_id}/{version}")
def get_encrypted_object(vault_id: str, object_id: str, version: int,
                         identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    _uuid(object_id, "object_id")
    row = db.get(VaultObject, (object_id, identity.subject, version))
    if not row or row.vault_id != vault_id:
        raise HTTPException(status_code=404, detail="Encrypted object not found")
    return {"object_id": row.object_id, "vault_id": row.vault_id, "version": row.version,
            "algorithm": row.algorithm, "nonce": base64.urlsafe_b64encode(row.nonce).decode().rstrip("="),
            "ciphertext": base64.urlsafe_b64encode(row.ciphertext).decode().rstrip("="),
            "ciphertext_sha256": row.ciphertext_sha256}

@router.delete("/{vault_id}/objects/{object_id}/{version}")
def delete_encrypted_object(vault_id: str, object_id: str, version: int,
                            identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    _uuid(object_id, "object_id")
    row = db.get(VaultObject, (object_id, identity.subject, version))
    if not row or row.vault_id != vault_id:
        raise HTTPException(status_code=404, detail="Encrypted object not found")
    db.delete(row)
    _event(db, identity.subject, "encrypted_vault_object_deleted", object_id)
    db.commit()
    return {"deleted": True, "object_id": object_id, "version": version}

@router.post("/{vault_id}/key-envelopes", status_code=status.HTTP_201_CREATED)
def put_key_envelope(vault_id: str, payload: KeyEnvelopeInput,
                     identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    _uuid(payload.envelope_id, "envelope_id")
    if payload.algorithm not in ALLOWED_ENVELOPE_ALGORITHMS:
        raise HTTPException(status_code=422, detail="Unsupported key-envelope algorithm")
    if payload.recipient_type == "device":
        if payload.algorithm != "X25519-HKDF-SHA256-AES-256-GCM":
            raise HTTPException(status_code=422, detail="Device recipient requires X25519 key wrapping")
        if not payload.recipient_id:
            raise HTTPException(status_code=422, detail="Device envelope requires recipient_id")
        _uuid(payload.recipient_id, "recipient_id")
        device = db.get(TrustedDevice, payload.recipient_id)
        if not device or device.subject != identity.subject or device.is_revoked or not device.encryption_public_key:
            raise HTTPException(status_code=404, detail="Active trusted recipient device with a registered encryption key not found")
        required_fields = {"algorithm", "ephemeral_public_key", "nonce", "wrapped_key", "version"}
    else:
        if payload.algorithm != "AES-256-GCM-HKDF-SHA256-RECOVERY":
            raise HTTPException(status_code=422, detail="Recovery recipient requires recovery-key wrapping")
        if payload.recipient_id is not None:
            raise HTTPException(status_code=422, detail="Recovery envelope must not have recipient_id")
        required_fields = {"algorithm", "nonce", "wrapped_key", "version"}
    if not required_fields.issubset(payload.envelope_json.keys()):
        raise HTTPException(status_code=422, detail="Key envelope is missing required fields")
    if payload.envelope_json.get("algorithm") != payload.algorithm:
        raise HTTPException(status_code=422, detail="Envelope algorithm metadata mismatch")
    try:
        nonce = _decode(payload.envelope_json["nonce"], "envelope nonce")
        wrapped_key = _decode(payload.envelope_json["wrapped_key"], "wrapped key")
        if len(nonce) != 12 or len(wrapped_key) != 48:
            raise ValueError("invalid envelope nonce or wrapped key length")
        if payload.recipient_type == "device":
            ephemeral = _decode(payload.envelope_json["ephemeral_public_key"], "ephemeral public key")
            if len(ephemeral) != 32:
                raise ValueError("invalid ephemeral X25519 public key length")
    except (KeyError, ValueError) as exc:
        raise HTTPException(status_code=422, detail="Malformed key envelope") from exc
    encoded = json.dumps(payload.envelope_json, separators=(",", ":"))
    if len(encoded.encode()) > 4096:
        raise HTTPException(status_code=413, detail="Key envelope is too large")
    row = VaultKeyEnvelope(
        id=payload.envelope_id, subject=identity.subject, vault_id=vault_id,
        recipient_type=payload.recipient_type, recipient_id=payload.recipient_id,
        algorithm=payload.algorithm, envelope_json=encoded,
    )
    db.add(row)
    _event(db, identity.subject, "vault_key_envelope_uploaded", payload.envelope_id)
    db.commit()
    return {"envelope_id": row.id, "vault_id": vault_id, "stored": True, "plaintext_key_access": False}

@router.get("/{vault_id}/key-envelopes")
def list_key_envelopes(vault_id: str, identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    rows = db.scalars(select(VaultKeyEnvelope).where(
        VaultKeyEnvelope.subject == identity.subject, VaultKeyEnvelope.vault_id == vault_id,
        VaultKeyEnvelope.revoked_at.is_(None)
    )).all()
    return [{"envelope_id": r.id, "recipient_type": r.recipient_type, "recipient_id": r.recipient_id,
             "algorithm": r.algorithm, "envelope": json.loads(r.envelope_json)} for r in rows]
