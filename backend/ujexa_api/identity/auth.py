from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import jwt
from jwt import PyJWKClient
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from ..config import get_settings

bearer = HTTPBearer(auto_error=True)


@dataclass(frozen=True)
class Identity:
    subject: str
    token_id: str
    claims: dict[str, Any]


@lru_cache(maxsize=8)
def _jwks_client(url: str) -> PyJWKClient:
    # Keep PyJWT's signing-key cache across requests instead of rebuilding the
    # client (and refetching the JWKS) for every authenticated API call.
    return PyJWKClient(url, cache_keys=True)


def verify_access_token(token: str) -> Identity:
    settings = get_settings()
    try:
        signing_key = _jwks_client(settings.oidc_jwks_url).get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=settings.algorithms,
            audience=settings.oidc_audience,
            issuer=settings.oidc_issuer,
            leeway=settings.access_token_leeway_seconds,
            options={"require": ["exp", "iat", "iss", "aud", "sub", "jti"]},
        )
    except Exception as exc:
        # Do not leak provider/JWKS details to callers.
        raise HTTPException(status_code=401, detail="Invalid or expired access token") from exc

    subject, token_id = claims.get("sub"), claims.get("jti")
    if not isinstance(subject, str) or not subject or not isinstance(token_id, str) or not token_id:
        raise HTTPException(status_code=401, detail="Invalid access token claims")

    if settings.require_mfa:
        amr = claims.get("amr", [])
        if not isinstance(amr, list):
            amr = []
        mfa_satisfied = "mfa" in amr or bool(settings.mfa_acr and claims.get("acr") == settings.mfa_acr)
        if not mfa_satisfied:
            raise HTTPException(status_code=403, detail="Multi-factor authentication is required")

    return Identity(subject=subject, token_id=token_id, claims=claims)


def get_current_identity(credentials: HTTPAuthorizationCredentials = Depends(bearer)) -> Identity:
    return verify_access_token(credentials.credentials)
