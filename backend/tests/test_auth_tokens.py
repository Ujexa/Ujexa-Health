from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from ujexa_api.identity import auth
from ujexa_api.config import Settings
from fastapi import HTTPException

PRIVATE = rsa.generate_private_key(public_exponent=65537, key_size=2048)

class FakeSigningKey:
    key = PRIVATE.public_key()

class FakeJwks:
    def __init__(self, *args, **kwargs): pass
    def get_signing_key_from_jwt(self, token): return FakeSigningKey()

def token(**overrides):
    now = datetime.now(timezone.utc)
    claims = {
        "iss": "https://id.example.test/",
        "aud": "ujexa-health-api",
        "sub": "patient-123",
        "jti": "session-123",
        "iat": now,
        "exp": now + timedelta(minutes=5),
        "amr": ["pwd", "mfa"],
    }
    claims.update(overrides)
    return jwt.encode(claims, PRIVATE, algorithm="RS256")

def configure(monkeypatch):
    settings = Settings(
        oidc_issuer="https://id.example.test/",
        oidc_audience="ujexa-health-api",
        oidc_jwks_url="https://id.example.test/jwks.json",
        oidc_algorithms="RS256",
        require_mfa=True,
    )
    monkeypatch.setattr(auth, "get_settings", lambda: settings)
    monkeypatch.setattr(auth, "PyJWKClient", FakeJwks)

def test_valid_oidc_token_with_mfa_is_accepted(monkeypatch):
    configure(monkeypatch)
    identity = auth.verify_access_token(token())
    assert identity.subject == "patient-123"
    assert identity.token_id == "session-123"

def test_missing_mfa_claim_is_rejected(monkeypatch):
    configure(monkeypatch)
    with pytest.raises(HTTPException) as error:
        auth.verify_access_token(token(amr=["pwd"]))
    assert error.value.status_code == 403

def test_wrong_audience_is_rejected(monkeypatch):
    configure(monkeypatch)
    with pytest.raises(HTTPException) as error:
        auth.verify_access_token(token(aud="another-api"))
    assert error.value.status_code == 401
