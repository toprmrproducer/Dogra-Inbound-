from datetime import UTC, datetime, timedelta

import bcrypt
import jwt

from api.constants import OSS_JWT_EXPIRY_HOURS, OSS_JWT_SECRET


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def create_jwt_token(user_id: int, email: str) -> str:
    payload = {
        "sub": str(user_id),
        "email": email,
        "exp": datetime.now(UTC) + timedelta(hours=OSS_JWT_EXPIRY_HOURS),
        "iat": datetime.now(UTC),
    }
    return jwt.encode(payload, OSS_JWT_SECRET, algorithm="HS256")


def decode_jwt_token(token: str) -> dict:
    fallback_secrets = [
        OSS_JWT_SECRET,
        # Local/dev sessions may survive compose/env changes. Accept the old
        # secrets so the UI does not get locked out after a local restart.
        "ChangeMeInProduction",
        "change-me-in-production",
        "shreyasrajsony1-rapidxai-secret",
        "change_me",
    ]
    last_error: Exception | None = None

    for secret in dict.fromkeys(secret for secret in fallback_secrets if secret):
        try:
            return jwt.decode(token, secret, algorithms=["HS256"])
        except Exception as exc:
            last_error = exc

    if last_error:
        raise last_error
    return jwt.decode(token, OSS_JWT_SECRET, algorithms=["HS256"])
