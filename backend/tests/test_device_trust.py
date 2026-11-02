import base64
from datetime import datetime, timezone
from uuid import uuid4

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives import serialization
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from ujexa_api.main import app
from ujexa_api.database import Base, get_db
from ujexa_api.identity.auth import Identity, get_current_identity
from ujexa_api.identity.models import VaultKeyEnvelope

engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
TestingSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
Base.metadata.create_all(bind=engine)

def override_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()

identity_state = {"device_id": None}

def override_identity():
    claims = {"sub":"patient-test-001","jti":"session-test-001","amr":["mfa"]}
    if identity_state["device_id"]:
        claims["device_id"] = identity_state["device_id"]
    return Identity(subject="patient-test-001", token_id="session-test-001", claims=claims)

app.dependency_overrides[get_db] = override_db
app.dependency_overrides[get_current_identity] = override_identity
client = TestClient(app)

def enc(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")

def test_device_enrollment_requires_signed_one_time_challenge():
    private = Ed25519PrivateKey.generate()
    public = private.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    challenge = client.post("/v1/identity/device-challenges").json()
    name = "Kwame's Android"
    encryption_private = X25519PrivateKey.generate()
    encryption_public = encryption_private.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    encryption_public_encoded = enc(encryption_public)
    message = f"UJEXA_DEVICE_ENROLLMENT_V1\n{challenge['nonce']}\npatient-test-001\n{name}\n{encryption_public_encoded}".encode()
    signature = private.sign(message)

    response = client.post("/v1/identity/devices", json={
        "challenge_id": challenge["challenge_id"], "name": name,
        "public_key": enc(public), "encryption_public_key": encryption_public_encoded,
        "signature": enc(signature),
    })
    assert response.status_code == 201
    device_id = response.json()["id"]
    assert response.json()["is_current_device"] is True

    replay = client.post("/v1/identity/devices", json={
        "challenge_id": challenge["challenge_id"], "name": name,
        "public_key": enc(public), "encryption_public_key": encryption_public_encoded, "signature": enc(signature),
    })
    assert replay.status_code == 400

    listed = client.get("/v1/identity/devices")
    assert listed.status_code == 200
    assert any(d["id"] == device_id for d in listed.json())

    identity_state["device_id"] = device_id
    db = TestingSession()
    envelope = VaultKeyEnvelope(
        id=str(uuid4()), subject="patient-test-001", vault_id=str(uuid4()),
        recipient_type="device", recipient_id=device_id,
        algorithm="X25519-HKDF-SHA256-AES-256-GCM",
        envelope_json='{"algorithm":"X25519-HKDF-SHA256-AES-256-GCM"}',
    )
    db.add(envelope)
    db.commit()
    envelope_id = envelope.id
    db.close()

    revoked = client.delete(f"/v1/identity/devices/{device_id}")
    assert revoked.status_code == 200
    assert revoked.json()["status"] == "revoked"
    assert client.get("/v1/identity/devices").status_code == 401
    db = TestingSession()
    assert db.get(VaultKeyEnvelope, envelope_id).revoked_at is not None
    db.close()
    identity_state["device_id"] = None
    assert all(d["id"] != device_id for d in client.get("/v1/identity/devices").json())

def test_invalid_device_proof_is_rejected():
    private = Ed25519PrivateKey.generate()
    public = private.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    challenge = client.post("/v1/identity/device-challenges").json()
    wrong_signature = enc(b"x" * 64)
    response = client.post("/v1/identity/devices", json={
        "challenge_id": challenge["challenge_id"], "name": "Untrusted device",
        "public_key": enc(public), "encryption_public_key": enc(b"x" * 32), "signature": wrong_signature,
    })
    assert response.status_code == 400
    assert response.json()["detail"] == "Device proof-of-possession failed"

def test_session_revocation_blocks_future_protected_requests():
    response = client.post("/v1/identity/sessions/revoke-current")
    assert response.status_code == 200
    assert response.json()["revoked_id"] == "session-test-001"
    blocked = client.get("/v1/identity/devices")
    assert blocked.status_code == 401
