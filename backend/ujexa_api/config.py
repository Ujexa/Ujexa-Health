from functools import lru_cache
from urllib.parse import urlparse

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="UJEXA_", env_file=".env", extra="ignore")

    # Production is the safe default. Local development must be explicitly opted into.
    env: str = "production"
    database_url: str = "sqlite:///./ujexa-dev.db"
    oidc_issuer: str = "https://identity-provider-not-configured.invalid/"
    oidc_audience: str = "ujexa-health-api"
    oidc_jwks_url: str = "https://identity-provider-not-configured.invalid/.well-known/jwks.json"
    oidc_algorithms: str = "RS256,ES256"
    require_mfa: bool = True
    mfa_acr: str = ""
    access_token_leeway_seconds: int = 30

    @model_validator(mode="after")
    def validate_runtime_configuration(self):
        if self.env not in {"development", "staging", "production"}:
            raise ValueError("UJEXA_ENV must be development, staging, or production")

        if self.env == "production":
            for label, value in (("UJEXA_OIDC_ISSUER", self.oidc_issuer), ("UJEXA_OIDC_JWKS_URL", self.oidc_jwks_url)):
                parsed = urlparse(value)
                if parsed.scheme != "https" or not parsed.hostname or parsed.hostname.endswith(".invalid"):
                    raise ValueError(f"{label} must be a configured HTTPS URL in production")
        return self

    @property
    def algorithms(self) -> list[str]:
        allowed = {"RS256", "ES256"}
        configured = [item.strip() for item in self.oidc_algorithms.split(",") if item.strip()]
        if not configured or any(item not in allowed for item in configured):
            raise ValueError("OIDC algorithms must be a non-empty subset of RS256,ES256")
        return configured


@lru_cache
def get_settings() -> Settings:
    return Settings()
