import base64
import hashlib
from uuid import uuid4

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from ujexa_api.vault import router as vault_router
from ujexa_api.database import Base, get_db
from ujexa_api.identity.auth import Identity
from ujexa_api.identity.models import TrustedDevice
from ujexa_api.identity.dependencies import get_active_identity

engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
TestingSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
Base.metadata.create_all(bind=engine)

def override_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()

def override_identity():
    return Identity(subject="vault-patient-001", token_id="vault-session-001", claims={"sub":"vault-patient-001","jti":"vault-session-001","amr":["mfa"]})

app = FastAPI()
app.include_router(vault_router)
app.dependency_overrides[get_db] = override_db
app.dependency_overrides[get_active_identity] = override_identity
client = TestClient(app)

def b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode().rstrip("=")

def test_encrypted_object_upload_list_download_and_immutable_version():
    vault_id, object_id = str(uuid4()), str(uuid4())
    ciphertext = b"synthetic-ciphertext-payload-with-auth-tag"
    payload = {
        "object_id": object_id, "version": 1, "algorithm": "AES-256-GCM",
        "nonce": b64(b"n" * 12), "ciphertext": b64(ciphertext),
        "ciphertext_sha256": hashlib.sha256(ciphertext).hexdigest(),
    }
    uploaded = client.post(f"/v1/vaults/{vault_id}/objects", json=payload)
    assert uploaded.status_code == 201
    assert uploaded.json()["plaintext_access"] is False
    listed = client.get(f"/v1/vaults/{vault_id}/objects")
    assert listed.status_code == 200 and listed.json()[0]["object_id"] == object_id
    downloaded = client.get(f"/v1/vaults/{vault_id}/objects/{object_id}/1")
    assert downloaded.status_code == 200
    assert base64.urlsafe_b64decode(downloaded.json()["ciphertext"] + "==") == ciphertext
    duplicate = client.post(f"/v1/vaults/{vault_id}/objects", json=payload)
    assert duplicate.status_code == 409

def test_server_rejects_wrong_ciphertext_hash():
    vault_id, object_id = str(uuid4()), str(uuid4())
    response = client.post(f"/v1/vaults/{vault_id}/objects", json={
        "object_id": object_id, "version": 1, "algorithm": "AES-256-GCM",
        "nonce": b64(b"n" * 12), "ciphertext": b64(b"ciphertext-and-tag"),
        "ciphertext_sha256": "0" * 64,
    })
    assert response.status_code == 422

def test_key_envelope_is_opaque_and_recovery_metadata_validated():
    vault_id = str(uuid4())
    envelope_id = str(uuid4())
    envelope = {
        "algorithm": "AES-256-GCM-HKDF-SHA256-RECOVERY",
        "nonce": b64(b"n" * 12), "wrapped_key": b64(b"w" * 48), "version": "1",
    }
    response = client.post(f"/v1/vaults/{vault_id}/key-envelopes", json={
        "envelope_id": envelope_id, "recipient_type": "recovery", "recipient_id": None,
        "algorithm": envelope["algorithm"], "envelope_json": envelope,
    })
    assert response.status_code == 201
    listed = client.get(f"/v1/vaults/{vault_id}/key-envelopes")
    assert listed.status_code == 200
    assert listed.json()[0]["envelope"] == envelope

def test_vault_id_and_object_id_must_be_uuids():
    response = client.get("/v1/vaults/not-a-uuid/objects")
    assert response.status_code == 422


def test_device_key_envelope_requires_registered_encryption_device():
    db = TestingSession()
    device_id = str(uuid4())
    db.add(TrustedDevice(
        id=device_id, subject="vault-patient-001", name="Test device",
        public_key=b64(b"s" * 32), encryption_public_key=b64(b"x" * 32),
    ))
    db.commit()
    db.close()
    vault_id, envelope_id = str(uuid4()), str(uuid4())
    envelope = {
        "algorithm": "X25519-HKDF-SHA256-AES-256-GCM",
        "ephemeral_public_key": b64(b"e" * 32),
        "nonce": b64(b"n" * 12),
        "wrapped_key": b64(b"w" * 48),
        "version": "1",
    }
    response = client.post(f"/v1/vaults/{vault_id}/key-envelopes", json={
        "envelope_id": envelope_id, "recipient_type": "device", "recipient_id": device_id,
        "algorithm": envelope["algorithm"], "envelope_json": envelope,
    })
    assert response.status_code == 201
    assert client.get(f"/v1/vaults/{vault_id}/key-envelopes").json()[0]["recipient_id"] == device_id
