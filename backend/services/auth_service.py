import httpx
from config import (
    XINGZHE_CLIENT_ID,
    XINGZHE_CLIENT_SECRET,
    XINGZHE_AUTH_URL,
    XINGZHE_TOKEN_URL,
    REDIRECT_URI,
)
import secrets


def get_auth_url(state: str = None) -> tuple[str, str]:
    """Generate OAuth2 authorization URL with random CSRF state.

    Returns:
        (url, state) — state must be verified on callback.
    """
    if state is None:
        state = secrets.token_urlsafe(16)
    url = (
        f"{XINGZHE_AUTH_URL}?client_id={XINGZHE_CLIENT_ID}"
        f"&response_type=code&state={state}&scope=write"
        f"&redirect_uri={REDIRECT_URI}"
    )
    return url, state


def _token_headers() -> dict:
    """行者 API 要求 Authorization: Bearer client_id:client_secret"""
    return {
        "Authorization": f"Bearer {XINGZHE_CLIENT_ID}:{XINGZHE_CLIENT_SECRET}",
    }


async def exchange_code_for_token(code: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            XINGZHE_TOKEN_URL,
            headers=_token_headers(),
            files=[
                ("grant_type", (None, "authorization_code")),
                ("code", (None, code)),
                ("redirect_uri", (None, REDIRECT_URI)),
            ],
        )
        resp.raise_for_status()
        return resp.json()


async def refresh_access_token(refresh_token: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            XINGZHE_TOKEN_URL,
            headers=_token_headers(),
            files=[
                ("grant_type", (None, "refresh_token")),
                ("refresh_token", (None, refresh_token)),
            ],
        )
        resp.raise_for_status()
        return resp.json()
