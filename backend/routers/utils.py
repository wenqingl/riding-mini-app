"""Shared router utilities."""

from fastapi import HTTPException


def parse_token(authorization: str) -> str:
    """Extract Bearer token from Authorization header."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    return authorization.split(" ", 1)[1]
