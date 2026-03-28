import asyncio
import hashlib

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from typing import Optional

from routers.utils import parse_token
from services.record_service import get_activity_stream
from services.merge_service import stream_to_records, merge_records, records_to_gpx
from services.upload_service import upload_to_xingzhe

router = APIRouter()


class MergeRequest(BaseModel):
    record_ids: list[int]
    format: Optional[str] = "gpx"


async def _download_and_merge(token: str, record_ids: list[int]) -> list:
    """并行下载所有活动 stream 数据并合并。"""
    if len(record_ids) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 records to merge")

    try:
        results = await asyncio.gather(
            *[get_activity_stream(token, rid) for rid in record_ids]
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to download one or more records: {e}")

    all_records = []
    for stream_data in results:
        records = stream_to_records(stream_data)
        all_records.extend(records)

    if len(all_records) < 2:
        raise HTTPException(status_code=400, detail="Not enough track points to merge")

    return all_records


@router.post("/merge-and-upload")
async def merge_and_upload(body: MergeRequest, authorization: str = Header(...)):
    token = parse_token(authorization)
    merged_records = await _download_and_merge(token, body.record_ids)
    merged_gpx = records_to_gpx(merged_records)

    try:
        # 行者上传只接受 FIT 格式，目前先传 GPX（需要后续转换）
        # TODO: 实现 GPX → FIT 转换，或直接生成 FIT
        fit_data = merged_gpx  # 占位，需要 FIT 转换
        md5 = hashlib.md5(fit_data).hexdigest()
        result = await upload_to_xingzhe(token, fit_data, title="合并骑行记录")
        return {"success": True, "record_id": result.get("id"), "total_points": len(merged_records)}
    except Exception as e:
        return {
            "success": False,
            "error": f"Upload failed: {e}",
            "merged_data_available": True,
            "total_points": len(merged_records),
        }


@router.post("/merge")
async def merge_only(body: MergeRequest, authorization: str = Header(...)):
    token = parse_token(authorization)
    merged_records = await _download_and_merge(token, body.record_ids)
    merged_gpx = records_to_gpx(merged_records)

    return Response(
        content=merged_gpx,
        media_type="application/gpx+xml",
        headers={"Content-Disposition": "attachment; filename=merged.gpx"},
    )
