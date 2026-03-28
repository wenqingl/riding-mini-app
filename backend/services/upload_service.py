import hashlib

import httpx
from config import XINGZHE_API_BASE


async def upload_to_xingzhe(access_token: str, fit_data: bytes, title: str, sport: int = 0) -> dict:
    """上传运动数据到行者（POST /uploads/）

    行者只接受 FIT 格式文件，需要提供 title、fit_file、md5。
    """
    md5_hash = hashlib.md5(fit_data).hexdigest()

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{XINGZHE_API_BASE}/uploads/",
            headers={"Authorization": f"Bearer {access_token}"},
            files={
                "fit_file": ("merged.fit", fit_data, "application/octet-stream"),
            },
            data={
                "title": title,
                "md5": md5_hash,
                "sport": str(sport),
            },
        )
        resp.raise_for_status()
        return resp.json()
