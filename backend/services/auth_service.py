import httpx
from config import XINGZHE_CLIENT_ID, XINGZHE_CLIENT_SECRET, XINGZHE_AUTH_URL, XINGZHE_TOKEN_URL, REDIRECT_URI


def get_auth_url(state: str = "abc") -> str:
    return (
        f"{XINGZHE_AUTH_URL}?client_id={XINGZHE_CLIENT_ID}"
        f"&response_type=code&state={state}&scope=write"
        f"&redirect_uri={REDIRECT_URI}"
    )


async def exchange_code_for_token(code: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.post(XINGZHE_TOKEN_URL, data={
            "grant_type": "authorization_code",
            "code": code,
            "client_id": XINGZHE_CLIENT_ID,
            "client_secret": XINGZHE_CLIENT_SECRET,
            "redirect_uri": REDIRECT_URI,
        })
        resp.raise_for_status()
        return resp.json()


async def refresh_access_token(refresh_token_str: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.post(XINGZHE_TOKEN_URL, data={
            "grant_type": "refresh_token",
            "refresh_token": refresh_token_str,
            "client_id": XINGZHE_CLIENT_ID,
            "client_secret": XINGZHE_CLIENT_SECRET,
        })
        resp.raise_for_status()
        return resp.json()
