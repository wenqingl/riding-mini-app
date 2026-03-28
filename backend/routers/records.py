from fastapi import APIRouter, Header, HTTPException, Response
from services.record_service import get_records, get_activity_detail
from routers.utils import parse_token

router = APIRouter()


@router.get("/records")
async def list_records(authorization: str = Header(...)):
    token = parse_token(authorization)
    data = await get_records(token)
    return {"records": data.get("results", []), "count": data.get("count", 0)}


@router.get("/records/{record_id}/detail")
async def record_detail(record_id: int, authorization: str = Header(...)):
    token = parse_token(authorization)
    detail = await get_activity_detail(token, record_id)
    return detail
