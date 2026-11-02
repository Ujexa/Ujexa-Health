from datetime import datetime, timezone
from sqlalchemy import String, DateTime, Boolean, ForeignKey, Text, Index, LargeBinary, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base

def utcnow():
    return datetime.now(timezone.utc)

class DeviceChallenge(Base):
    __tablename__ = "device_challenges"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    subject: Mapped[str] = mapped_column(String(255), index=True)
    nonce: Mapped[str] = mapped_column(String(128), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

class TrustedDevice(Base):
    __tablename__ = "trusted_devices"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    subject: Mapped[str] = mapped_column(String(255), index=True)
    name: Mapped[str] = mapped_column(String(80))
    public_key: Mapped[str] = mapped_column(Text)  # Ed25519 signing key
    encryption_public_key: Mapped[str | None] = mapped_column(Text, nullable=True)  # X25519 key agreement key
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_revoked: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

class RevokedSession(Base):
    __tablename__ = "revoked_sessions"
    jti: Mapped[str] = mapped_column(String(255), primary_key=True)
    subject: Mapped[str] = mapped_column(String(255), index=True)
    revoked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    reason: Mapped[str] = mapped_column(String(80), default="user_initiated")

class SecurityEvent(Base):
    __tablename__ = "security_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    subject: Mapped[str] = mapped_column(String(255), index=True)
    event_type: Mapped[str] = mapped_column(String(80), index=True)
    target_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    outcome: Mapped[str] = mapped_column(String(24), default="success")
    detail: Mapped[str] = mapped_column(String(255), default="")


class VaultObject(Base):
    __tablename__ = "vault_objects"
    __table_args__ = (
        Index("ix_vault_objects_owner_vault", "subject", "vault_id"),
    )
    object_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    subject: Mapped[str] = mapped_column(String(255), primary_key=True)
    version: Mapped[int] = mapped_column(primary_key=True)
    vault_id: Mapped[str] = mapped_column(String(36), index=True)
    algorithm: Mapped[str] = mapped_column(String(48))
    nonce: Mapped[bytes] = mapped_column(LargeBinary)  # Base64url nonce; never plaintext.
    ciphertext: Mapped[bytes] = mapped_column(LargeBinary)  # Base64url ciphertext only.
    ciphertext_sha256: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

class VaultKeyEnvelope(Base):
    __tablename__ = "vault_key_envelopes"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    subject: Mapped[str] = mapped_column(String(255), index=True)
    vault_id: Mapped[str] = mapped_column(String(36), index=True)
    recipient_type: Mapped[str] = mapped_column(String(16))  # recovery | device
    recipient_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    algorithm: Mapped[str] = mapped_column(String(64))
    envelope_json: Mapped[str] = mapped_column(Text)  # Opaque client-side key envelope.
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class HealthRecordVersion(Base):
    """Encrypted, immutable patient record version. No clinical plaintext metadata."""
    __tablename__ = "health_record_versions"
    record_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    subject: Mapped[str] = mapped_column(String(255), primary_key=True)
    version: Mapped[int] = mapped_column(primary_key=True)
    vault_id: Mapped[str] = mapped_column(String(36), index=True)
    algorithm: Mapped[str] = mapped_column(String(48))
    nonce: Mapped[bytes] = mapped_column(LargeBinary)
    ciphertext: Mapped[bytes] = mapped_column(LargeBinary)
    ciphertext_sha256: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class HealthRecordSyncChange(Base):
    """Opaque synchronization journal; contains no clinical plaintext."""
    __tablename__ = "health_record_sync_changes"
    sequence: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    subject: Mapped[str] = mapped_column(String(255), index=True)
    vault_id: Mapped[str] = mapped_column(String(36), index=True)
    record_id: Mapped[str] = mapped_column(String(36), index=True)
    version: Mapped[int] = mapped_column(Integer)
    operation: Mapped[str] = mapped_column(String(16))  # upsert | delete
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
