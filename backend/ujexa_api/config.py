from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="UJEXA_", env_file=".env", extra="ignore")
    env: str = "development"
    database_url: str = "sqlite:///./ujexa-dev.db"
    oidc_issuer: str = "https://identity-provider-not-configured.invalid/"
    oidc_audience: str = "ujexa-health-api"
    oidc_jwks_url: str = "https://identity-provider-not-configured.invalid/.well-known/jwks.json"
    oidc_algorithms: str = "RS256,ES256"
    require_mfa: bool = True
    mfa_acr: str = ""
    access_token_leeway_seconds: int = 30

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
