import httpx
from config import XINGZHE_API_BASE


async def get_records(access_token: str) -> list:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{XINGZHE_API_BASE}/records",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        resp.raise_for_status()
        data = resp.json()
        return data if isinstance(data, list) else data.get("data", [])


async def download_record_file(access_token: str, record_id: str, fmt: str = "fit") -> bytes:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{XINGZHE_API_BASE}/records/{record_id}/export",
            params={"format": fmt},
            headers={"Authorization": f"Bearer {access_token}"},
        )
        resp.raise_for_status()
        return resp.content
