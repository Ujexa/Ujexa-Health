from datetime import datetime, timedelta, timezone
from uuid import uuid4
import base64
import secrets

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from ..database import get_db
from .auth import Identity
from .dependencies import get_active_identity
from .models import DeviceChallenge, TrustedDevice, RevokedSession, SecurityEvent, VaultKeyEnvelope
from .schemas import ChallengeResponse, DeviceEnrollRequest, DeviceResponse, RevokeResponse

router = APIRouter(prefix="/v1/identity", tags=["identity & device trust"])
CHALLENGE_TTL = timedelta(minutes=5)

def _b64url_decode(value: str) -> bytes:
    try:
        return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
    except Exception as exc:
        raise ValueError("invalid base64url") from exc

def _aware(value: datetime) -> datetime:
    # SQLite may return naive timestamps even when timezone=True is declared.
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value

def _event(db: Session, subject: str, event_type: str, target_id: str | None = None, detail: str = ""):
    db.add(SecurityEvent(id=str(uuid4()), subject=subject, event_type=event_type, target_id=target_id, detail=detail[:255]))

@router.post("/device-challenges", response_model=ChallengeResponse)
def create_device_challenge(identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    challenge = DeviceChallenge(
        id=str(uuid4()), subject=identity.subject, nonce=secrets.token_urlsafe(32),
        expires_at=now + CHALLENGE_TTL,
    )
    db.add(challenge)
    _event(db, identity.subject, "device_enrollment_challenge_created", challenge.id)
    db.commit()
    return ChallengeResponse(challenge_id=challenge.id, nonce=challenge.nonce, expires_in_seconds=int(CHALLENGE_TTL.total_seconds()))

@router.post("/devices", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
def enroll_device(payload: DeviceEnrollRequest, identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    challenge = db.get(DeviceChallenge, payload.challenge_id)
    now = datetime.now(timezone.utc)
    if not challenge or challenge.subject != identity.subject or challenge.consumed_at is not None:
        raise HTTPException(status_code=400, detail="Challenge is invalid or already used")
    if _aware(challenge.expires_at) <= now:
        raise HTTPException(status_code=400, detail="Challenge has expired")

    try:
        public_key_bytes = _b64url_decode(payload.public_key)
        signature_bytes = _b64url_decode(payload.signature)
        if len(public_key_bytes) != 32 or len(signature_bytes) != 64:
            raise ValueError("invalid key or signature length")
        public_key = Ed25519PublicKey.from_public_bytes(public_key_bytes)
        encryption_key_bytes = _b64url_decode(payload.encryption_public_key)
        if encryption_key_bytes and len(encryption_key_bytes) != 32:
            raise ValueError("invalid X25519 public key length")
        message = f"UJEXA_DEVICE_ENROLLMENT_V1\n{challenge.nonce}\n{identity.subject}\n{payload.name.strip()}\n{payload.encryption_public_key}".encode()
        public_key.verify(signature_bytes, message)
    except (ValueError, InvalidSignature) as exc:
        _event(db, identity.subject, "device_enrollment_failed", challenge.id, "proof_of_possession_failed")
        db.commit()
        raise HTTPException(status_code=400, detail="Device proof-of-possession failed") from exc

    challenge.consumed_at = now
    device = TrustedDevice(
        id=str(uuid4()), subject=identity.subject, name=payload.name.strip(),
        public_key=payload.public_key, encryption_public_key=payload.encryption_public_key,
        created_at=now, last_seen_at=now,
    )
    db.add(device)
    _event(db, identity.subject, "device_enrolled", device.id)
    db.commit()
    return DeviceResponse(id=device.id, name=device.name, created_at=device.created_at.isoformat(), last_seen_at=device.last_seen_at.isoformat(), is_current_device=True)

@router.get("/devices", response_model=list[DeviceResponse])
def list_devices(identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    devices = db.scalars(select(TrustedDevice).where(TrustedDevice.subject == identity.subject, TrustedDevice.is_revoked.is_(False)).order_by(TrustedDevice.created_at.desc())).all()
    return [DeviceResponse(id=d.id, name=d.name, created_at=d.created_at.isoformat(), last_seen_at=d.last_seen_at.isoformat()) for d in devices]

@router.delete("/devices/{device_id}", response_model=RevokeResponse)
def revoke_device(device_id: str, identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    device = db.get(TrustedDevice, device_id)
    if not device or device.subject != identity.subject:
        raise HTTPException(status_code=404, detail="Trusted device not found")
    if not device.is_revoked:
        device.is_revoked = True
        device.revoked_at = datetime.now(timezone.utc)
        # Revoke all vault-key envelopes addressed to this device.
        envelopes = db.scalars(select(VaultKeyEnvelope).where(
            VaultKeyEnvelope.subject == identity.subject,
            VaultKeyEnvelope.recipient_type == "device",
            VaultKeyEnvelope.recipient_id == device.id,
            VaultKeyEnvelope.revoked_at.is_(None),
        )).all()
        for envelope in envelopes:
            envelope.revoked_at = device.revoked_at
        _event(db, identity.subject, "device_revoked", device.id)
        db.commit()
    return RevokeResponse(status="revoked", revoked_id=device.id)

@router.post("/sessions/revoke-current", response_model=RevokeResponse)
def revoke_current_session(identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    existing = db.get(RevokedSession, identity.token_id)
    if not existing:
        db.add(RevokedSession(jti=identity.token_id, subject=identity.subject, reason="user_initiated"))
        _event(db, identity.subject, "session_revoked", identity.token_id)
        db.commit()
    return RevokeResponse(status="revoked", revoked_id=identity.token_id)
