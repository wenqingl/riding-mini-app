from fastapi import APIRouter, Query
from fastapi.responses import RedirectResponse
from services.auth_service import get_auth_url, exchange_code_for_token

router = APIRouter()


@router.get("/login")
async def login():
    url = get_auth_url()
    return RedirectResponse(url=url)


@router.get("/callback")
async def callback(code: str = Query(...), state: str = Query(default="abc")):
    token_data = await exchange_code_for_token(code)
    return {
        "access_token": token_data.get("access_token"),
        "refresh_token": token_data.get("refresh_token"),
    }
