import httpx
from config import XINGZHE_API_BASE


async def upload_to_xingzhe(access_token: str, file_data: bytes, filename: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{XINGZHE_API_BASE}/records/upload",
            headers={"Authorization": f"Bearer {access_token}"},
            files={"file": (filename, file_data)},
        )
        resp.raise_for_status()
        return resp.json()
