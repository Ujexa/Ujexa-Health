from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from .auth import Identity, get_current_identity
from .models import RevokedSession, TrustedDevice
from ..config import get_settings

def get_active_identity(
    identity: Identity = Depends(get_current_identity),
    db: Session = Depends(get_db),
) -> Identity:
    if db.get(RevokedSession, identity.token_id):
        raise HTTPException(status_code=401, detail="Session has been revoked")

    # Production must fail closed: a missing device claim must never silently
    # disable trusted-device enforcement.
    device_id = identity.claims.get("device_id")
    if get_settings().env == "production" and not device_id:
        raise HTTPException(status_code=401, detail="A trusted-device claim is required")
    if device_id:
        device = db.get(TrustedDevice, device_id)
        if not device or device.subject != identity.subject or device.is_revoked:
            raise HTTPException(status_code=401, detail="This device is not trusted or has been revoked")
    return identity
