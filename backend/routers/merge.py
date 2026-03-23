from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from typing import Optional
from services.record_service import download_record_file
from services.merge_service import merge_records, records_to_gpx
from services.upload_service import upload_to_xingzhe

router = APIRouter()


class MergeRequest(BaseModel):
    record_ids: list[str]
    format: Optional[str] = "gpx"


@router.post("/merge-and-upload")
async def merge_and_upload(body: MergeRequest, authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    token = authorization.split(" ", 1)[1]

    if len(body.record_ids) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 records to merge")

    file_list = []
    for rid in body.record_ids:
        try:
            data = await download_record_file(token, rid, body.format)
            file_list.append({"format": body.format, "data": data})
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Failed to download record {rid}: {str(e)}")

    merged_records = merge_records(file_list)
    if not merged_records:
        raise HTTPException(status_code=400, detail="No valid records to merge")

    merged_bytes = records_to_gpx(merged_records)

    try:
        result = await upload_to_xingzhe(token, merged_bytes, f"merged.{body.format}")
        return {"success": True, "record_id": result.get("id"), "total_points": len(merged_records)}
    except Exception as e:
        return {
            "success": False,
            "error": f"Upload failed: {str(e)}",
            "merged_data_available": True,
            "total_points": len(merged_records),
        }


@router.post("/merge")
async def merge_only(body: MergeRequest, authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    token = authorization.split(" ", 1)[1]

    if len(body.record_ids) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 records to merge")

    file_list = []
    for rid in body.record_ids:
        data = await download_record_file(token, rid, body.format)
        file_list.append({"format": body.format, "data": data})

    merged_records = merge_records(file_list)
    merged_bytes = records_to_gpx(merged_records)

    return Response(
        content=merged_bytes,
        media_type="application/gpx+xml",
        headers={"Content-Disposition": f"attachment; filename=merged.{body.format}"},
    )
