# OIDC Provider Integration Checklist

This document is provider-neutral. Select and configure the production identity provider before enabling real sign-in.

## Required provider capabilities
- OpenID Connect discovery and JWKS.
- Authorization Code Flow with PKCE S256 for native apps.
- Passkeys / WebAuthn, preferably discoverable credentials.
- MFA policy and trustworthy `amr` / `acr` claims.
- Short-lived API access tokens with `sub`, `jti`, `iss`, `aud`, `iat`, `exp`.
- Refresh-token rotation and reuse detection.
- Session listing/revocation or global logout.
- Custom claim mapping for enrolled `device_id`.
- Secure account recovery and recovery event notifications.

## Mobile client contract
- Use system browser and AppAuth-compatible library.
- Register exact redirect URI and allowed app links.
- Store refresh tokens only in platform secure storage.
- Never log tokens, authorization codes, PKCE verifier, private keys or recovery secrets.
- Enforce TLS and validate state/nonce.
- On logout: revoke provider session/refresh token, revoke local session, clear local tokens and notify the user.
- Device private keys stay in platform secure hardware-backed storage when available.

## Token validation
The API validates issuer, audience, signature, expiry, issued-at, subject and jti. The configured algorithm allowlist is RS256 and ES256 only. Do not disable issuer/audience checks to make a provider integration work.

## Provider decision record
Provider selection, tenant/realm, region, data processing terms, MFA policy, passkey policy, recovery policy, audit export and service-level expectations must be reviewed and approved before production.
