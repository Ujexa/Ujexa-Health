from __future__ import annotations

import base64
import hashlib
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, desc
from sqlalchemy.orm import Session

from ..database import get_db
from ..identity.auth import Identity
from ..identity.dependencies import get_active_identity
from ..identity.models import HealthRecordVersion, SecurityEvent, HealthRecordSyncChange

router = APIRouter(prefix="/v1/health-records", tags=["encrypted health records"])
MAX_RECORD_CIPHERTEXT_BYTES = 8 * 1024 * 1024


class EncryptedHealthRecordInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    record_id: str = Field(min_length=36, max_length=36)
    version: int = Field(ge=1, le=2_147_483_647)
    algorithm: str = Field(pattern=r"^AES-256-GCM$")
    nonce: str = Field(min_length=16, max_length=24)
    ciphertext: str = Field(min_length=22, max_length=12_000_000)
    ciphertext_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")


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


def _audit(db: Session, subject: str, event: str, record_id: str):
    db.add(SecurityEvent(id=str(uuid4()), subject=subject, event_type=event, target_id=record_id))


@router.post("/{vault_id}/records", status_code=status.HTTP_201_CREATED)
def create_record_version(vault_id: str, payload: EncryptedHealthRecordInput,
                          identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    _uuid(payload.record_id, "record_id")
    nonce = _decode(payload.nonce, "nonce")
    ciphertext = _decode(payload.ciphertext, "ciphertext")
    if len(nonce) != 12:
        raise HTTPException(status_code=422, detail="AES-256-GCM nonce must be 12 bytes")
    if len(ciphertext) < 16 or len(ciphertext) > MAX_RECORD_CIPHERTEXT_BYTES:
        raise HTTPException(status_code=413, detail="Encrypted record must be between 16 bytes and 8 MiB")
    digest = hashlib.sha256(ciphertext).hexdigest()
    if digest != payload.ciphertext_sha256:
        raise HTTPException(status_code=422, detail="Ciphertext hash mismatch")
    if db.get(HealthRecordVersion, (payload.record_id, identity.subject, payload.version)):
        raise HTTPException(status_code=409, detail="This record version already exists")

    row = HealthRecordVersion(
        record_id=payload.record_id, subject=identity.subject, version=payload.version,
        vault_id=vault_id, algorithm=payload.algorithm, nonce=nonce,
        ciphertext=ciphertext, ciphertext_sha256=digest,
    )
    db.add(row)
    db.flush()
    db.add(HealthRecordSyncChange(subject=identity.subject, vault_id=vault_id,
        record_id=payload.record_id, version=payload.version, operation="upsert"))
    _audit(db, identity.subject, "encrypted_health_record_created", payload.record_id)
    db.commit()
    return {"record_id": row.record_id, "version": row.version, "stored": True,
            "plaintext_access": False, "ciphertext_sha256": digest}


@router.get("/{vault_id}/records")
def list_record_versions(vault_id: str, limit: int = Query(100, ge=1, le=500),
                          identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    rows = db.scalars(select(HealthRecordVersion).where(
        HealthRecordVersion.subject == identity.subject,
        HealthRecordVersion.vault_id == vault_id,
        HealthRecordVersion.deleted_at.is_(None),
    ).order_by(desc(HealthRecordVersion.created_at)).limit(limit)).all()
    # Deliberately omit clinical type, title, dates and content from server-visible metadata.
    return [{"record_id": r.record_id, "version": r.version, "algorithm": r.algorithm,
             "ciphertext_sha256": r.ciphertext_sha256, "ciphertext_bytes": len(r.ciphertext),
             "created_at": r.created_at.isoformat()} for r in rows]


@router.get("/{vault_id}/records/{record_id}/{version}")
def read_record_version(vault_id: str, record_id: str, version: int,
                        identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    _uuid(record_id, "record_id")
    row = db.get(HealthRecordVersion, (record_id, identity.subject, version))
    if not row or row.vault_id != vault_id or row.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Health record not found")
    return {"record_id": row.record_id, "version": row.version, "algorithm": row.algorithm,
            "nonce": base64.urlsafe_b64encode(row.nonce).decode().rstrip("="),
            "ciphertext": base64.urlsafe_b64encode(row.ciphertext).decode().rstrip("="),
            "ciphertext_sha256": row.ciphertext_sha256}


@router.delete("/{vault_id}/records/{record_id}/{version}")
def delete_record_version(vault_id: str, record_id: str, version: int,
                          identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    _uuid(vault_id, "vault_id")
    _uuid(record_id, "record_id")
    row = db.get(HealthRecordVersion, (record_id, identity.subject, version))
    if not row or row.vault_id != vault_id or row.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Health record not found")
    from datetime import datetime, timezone
    row.deleted_at = datetime.now(timezone.utc)
    db.add(HealthRecordSyncChange(subject=identity.subject, vault_id=vault_id,
        record_id=record_id, version=version, operation="delete"))
    _audit(db, identity.subject, "encrypted_health_record_deleted", record_id)
    db.commit()
    return {"deleted": True, "record_id": record_id, "version": version}


@router.get("/{vault_id}/sync")
def sync_changes(vault_id: str, after: int = Query(0, ge=0), limit: int = Query(200, ge=1, le=500),
                 identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    """Return opaque change journal entries after a client cursor."""
    _uuid(vault_id, "vault_id")
    changes = db.scalars(select(HealthRecordSyncChange).where(
        HealthRecordSyncChange.subject == identity.subject,
        HealthRecordSyncChange.vault_id == vault_id,
        HealthRecordSyncChange.sequence > after,
    ).order_by(HealthRecordSyncChange.sequence).limit(limit + 1)).all()
    has_more = len(changes) > limit
    changes = changes[:limit]
    next_cursor = changes[-1].sequence if changes else after
    return {
        "changes": [{
            "sequence": item.sequence,
            "record_id": item.record_id,
            "version": item.version,
            "operation": item.operation,
            "created_at": item.created_at.isoformat(),
        } for item in changes],
        "next_cursor": next_cursor,
        "has_more": has_more,
    }
