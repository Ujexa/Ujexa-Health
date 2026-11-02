import base64
import hashlib
from uuid import uuid4

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from ujexa_api.health_records.router import router
from ujexa_api.database import Base, get_db
from ujexa_api.identity.auth import Identity
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
    return Identity(subject="health-patient-001", token_id="health-session-001",
                    claims={"sub":"health-patient-001","jti":"health-session-001","amr":["mfa"]})

app = FastAPI()
app.include_router(router)
app.dependency_overrides[get_db] = override_db
app.dependency_overrides[get_active_identity] = override_identity
client = TestClient(app)

def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")

def test_encrypted_health_record_version_roundtrip_and_immutability():
    vault_id, record_id = str(uuid4()), str(uuid4())
    ciphertext = b"encrypted-clinical-record-fixture"
    payload = {
        "record_id": record_id, "version": 1, "algorithm": "AES-256-GCM",
        "nonce": b64(b"n" * 12), "ciphertext": b64(ciphertext),
        "ciphertext_sha256": hashlib.sha256(ciphertext).hexdigest(),
    }
    created = client.post(f"/v1/health-records/{vault_id}/records", json=payload)
    assert created.status_code == 201
    assert created.json()["plaintext_access"] is False
    listed = client.get(f"/v1/health-records/{vault_id}/records")
    assert listed.status_code == 200
    assert listed.json()[0]["record_id"] == record_id
    assert "resource_type" not in listed.json()[0]
    fetched = client.get(f"/v1/health-records/{vault_id}/records/{record_id}/1")
    assert fetched.status_code == 200
    assert base64.urlsafe_b64decode(fetched.json()["ciphertext"] + "==") == ciphertext
    duplicate = client.post(f"/v1/health-records/{vault_id}/records", json=payload)
    assert duplicate.status_code == 409

def test_record_hash_mismatch_is_rejected():
    vault_id, record_id = str(uuid4()), str(uuid4())
    response = client.post(f"/v1/health-records/{vault_id}/records", json={
        "record_id": record_id, "version": 1, "algorithm": "AES-256-GCM",
        "nonce": b64(b"n" * 12), "ciphertext": b64(b"ciphertext-fixture"),
        "ciphertext_sha256": "0" * 64,
    })
    assert response.status_code == 422

def test_patient_cannot_access_another_vault_record():
    vault_id, record_id = str(uuid4()), str(uuid4())
    ciphertext = b"encrypted-fixture"
    client.post(f"/v1/health-records/{vault_id}/records", json={
        "record_id": record_id, "version": 1, "algorithm": "AES-256-GCM",
        "nonce": b64(b"n" * 12), "ciphertext": b64(ciphertext),
        "ciphertext_sha256": hashlib.sha256(ciphertext).hexdigest(),
    })
    other_vault = str(uuid4())
    response = client.get(f"/v1/health-records/{other_vault}/records/{record_id}/1")
    assert response.status_code == 404

def test_record_delete_is_soft_and_hides_version():
    vault_id, record_id = str(uuid4()), str(uuid4())
    ciphertext = b"encrypted-fixture"
    client.post(f"/v1/health-records/{vault_id}/records", json={
        "record_id": record_id, "version": 1, "algorithm": "AES-256-GCM",
        "nonce": b64(b"n" * 12), "ciphertext": b64(ciphertext),
        "ciphertext_sha256": hashlib.sha256(ciphertext).hexdigest(),
    })
    deleted = client.delete(f"/v1/health-records/{vault_id}/records/{record_id}/1")
    assert deleted.status_code == 200
    assert client.get(f"/v1/health-records/{vault_id}/records/{record_id}/1").status_code == 404


def test_sync_journal_returns_opaque_upsert_and_delete_tombstone():
    vault_id, record_id = str(uuid4()), str(uuid4())
    ciphertext = b"encrypted-fixture"
    payload = {
        "record_id": record_id, "version": 1, "algorithm": "AES-256-GCM",
        "nonce": b64(b"n" * 12), "ciphertext": b64(ciphertext),
        "ciphertext_sha256": hashlib.sha256(ciphertext).hexdigest(),
    }
    assert client.post(f"/v1/health-records/{vault_id}/records", json=payload).status_code == 201
    first = client.get(f"/v1/health-records/{vault_id}/sync?after=0")
    assert first.status_code == 200
    assert first.json()["changes"][0]["operation"] == "upsert"
    assert "clinical_type" not in first.json()["changes"][0]
    cursor = first.json()["next_cursor"]
    assert client.delete(f"/v1/health-records/{vault_id}/records/{record_id}/1").status_code == 200
    second = client.get(f"/v1/health-records/{vault_id}/sync?after={cursor}")
    assert second.json()["changes"][0]["operation"] == "delete"
    assert second.json()["changes"][0]["record_id"] == record_id
