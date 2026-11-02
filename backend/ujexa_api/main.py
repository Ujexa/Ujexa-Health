from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from .database import Base, engine, get_db
from .identity.auth import Identity
from .identity.dependencies import get_active_identity
from .identity.router import router as identity_router
from .vault import router as vault_router
from .health_records.router import router as health_records_router

@asynccontextmanager
async def lifespan(_: FastAPI):
    # Convenience for local development. Production must use reviewed Alembic migrations.
    Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(
    title="Ujexa Health API",
    version="0.2.0",
    description="Identity and device-trust foundation. Health records and cryptographic key recovery are deliberately out of scope.",
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
