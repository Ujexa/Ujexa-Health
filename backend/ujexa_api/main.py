from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from .database import Base, engine, get_db
from .config import get_settings
from .identity.auth import Identity
from .identity.dependencies import get_active_identity
from .identity.router import router as identity_router
from .vault import router as vault_router
from .health_records.router import router as health_records_router

@asynccontextmanager
async def lifespan(_: FastAPI):
    # Validate production identity-provider configuration before accepting traffic.
    settings = get_settings()
    if settings.env != "production":
        # Convenience for local development only. Production must use reviewed Alembic migrations.
        Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(
    title="Ujexa Health API",
    version="0.2.0",
    description="Privacy-first patient health records API with identity, device trust, encrypted vault sync, and record provenance.",
    lifespan=lifespan,
)

app.include_router(identity_router)
app.include_router(vault_router)
app.include_router(health_records_router)

@app.get("/health", tags=["operations"])
def health():
    return {"status": "ok", "service": "ujexa-health-api"}

@app.get("/v1/identity/me", tags=["identity"])
def identity_profile(identity: Identity = Depends(get_active_identity), db: Session = Depends(get_db)):
    return {"subject": identity.subject, "mfa_verified": "mfa" in identity.claims.get("amr", [])}
