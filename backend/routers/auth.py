import secrets

from fastapi import APIRouter, Query, HTTPException
from fastapi.responses import RedirectResponse

from services.auth_service import get_auth_url, exchange_code_for_token, refresh_access_token

router = APIRouter()

# In-memory state store for CSRF protection (use Redis in production)
_state_store: dict[str, str] = {}


@router.get("/login")
async def login():
    url, state = get_auth_url()
    _state_store[state] = state  # store for callback verification
    return RedirectResponse(url=url)


@router.get("/callback")
async def callback(code: str = Query(...), state: str = Query(default="")):
    if not state or state not in _state_store:
        raise HTTPException(status_code=400, detail="Invalid or missing state parameter")
    _state_store.pop(state)  # one-time use

    token_data = await exchange_code_for_token(code)
    return {
        "access_token": token_data.get("access_token"),
        "refresh_token": token_data.get("refresh_token"),
    }


@router.post("/refresh")
async def refresh(refresh_token: str = Query(...)):
    token_data = await refresh_access_token(refresh_token)
    return {"access_token": token_data.get("access_token")}
