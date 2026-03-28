from fastapi import APIRouter, Header, HTTPException, Response
from services.record_service import get_records, download_record_file
from routers.utils import parse_token

router = APIRouter()


@router.get("/records")
async def list_records(authorization: str = Header(...)):
    token = parse_token(authorization)
    records = await get_records(token)
    return {"records": records}


@router.get("/records/{record_id}/file")
async def get_record_file(record_id: str, format: str = "fit", authorization: str = Header(...)):
    token = parse_token(authorization)
    data = await download_record_file(token, record_id, format)
    content_types = {
        "fit": "application/octet-stream",
        "gpx": "application/gpx+xml",
        "tcx": "application/xml",
    }
    return Response(content=data, media_type=content_types.get(format, "application/octet-stream"))
