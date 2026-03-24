import asyncio

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from typing import Optional

from routers.utils import parse_token
from services.record_service import download_record_file
from services.merge_service import merge_records, records_to_gpx
from services.upload_service import upload_to_xingzhe

router = APIRouter()


class MergeRequest(BaseModel):
    record_ids: list[str]
    format: Optional[str] = "gpx"


async def _download_and_merge(token: str, record_ids: list[str], fmt: str) -> list:
    """Download all records in parallel and merge them.

    Returns sorted merged records list.
    Raises HTTPException on download failure.
    """
    if len(record_ids) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 records to merge")

    try:
        results = await asyncio.gather(
            *[download_record_file(token, rid, fmt) for rid in record_ids]
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail="Failed to download one or more records")

    file_list = [{"format": fmt, "data": data} for data in results]
    merged_records = merge_records(file_list)

    if not merged_records:
        raise HTTPException(status_code=400, detail="No valid records to merge")

    return merged_records


@router.post("/merge-and-upload")
async def merge_and_upload(body: MergeRequest, authorization: str = Header(...)):
    token = parse_token(authorization)
    merged_records = await _download_and_merge(token, body.record_ids, body.format)
    merged_bytes = records_to_gpx(merged_records)

    try:
        result = await upload_to_xingzhe(token, merged_bytes, f"merged.{body.format}")
        return {"success": True, "record_id": result.get("id"), "total_points": len(merged_records)}
    except Exception:
        return {
            "success": False,
            "error": "Upload failed, merged file available for download",
            "merged_data_available": True,
            "total_points": len(merged_records),
        }


@router.post("/merge")
async def merge_only(body: MergeRequest, authorization: str = Header(...)):
    token = parse_token(authorization)
    merged_records = await _download_and_merge(token, body.record_ids, body.format)
    merged_bytes = records_to_gpx(merged_records)

    return Response(
        content=merged_bytes,
        media_type="application/gpx+xml",
        headers={"Content-Disposition": f"attachment; filename=merged.{body.format}"},
    )
