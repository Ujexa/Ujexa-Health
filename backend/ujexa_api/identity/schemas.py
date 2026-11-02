from pydantic import BaseModel, Field, ConfigDict

class ChallengeResponse(BaseModel):
    challenge_id: str
    nonce: str
    expires_in_seconds: int

class DeviceEnrollRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    challenge_id: str = Field(min_length=36, max_length=36)
    name: str = Field(min_length=1, max_length=80)
    public_key: str = Field(min_length=40, max_length=64, description="Base64url-encoded raw 32-byte Ed25519 public key")
    encryption_public_key: str = Field(min_length=40, max_length=64, description="Base64url-encoded raw 32-byte X25519 key-agreement public key")
    signature: str = Field(min_length=80, max_length=128, description="Base64url signature over the documented enrollment message")

class DeviceResponse(BaseModel):
    id: str
    name: str
    created_at: str
    last_seen_at: str
    is_current_device: bool = False

class RevokeResponse(BaseModel):
    status: str
    revoked_id: str
