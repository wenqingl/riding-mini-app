import httpx
from config import XINGZHE_API_BASE


async def get_records(access_token: str, limit: int = 100, offset: int = 0) -> dict:
    """获取用户轨迹列表（GET /activities/）

    Returns: {"count": N, "results": [...], "next": null, "previous": null}
    """
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{XINGZHE_API_BASE}/activities/",
            params={"limit": limit, "offset": offset},
            headers={"Authorization": f"Bearer {access_token}"},
        )
        resp.raise_for_status()
        return resp.json()


async def get_activity_stream(access_token: str, activity_id: int | str) -> dict:
    """获取轨迹 stream 点数据（POST /activities/{id}/stream/）

    TODO: 确认返回格式 — Swagger 标注返回 OpenApiWorkout，
    实际可能返回 GPS 点序列。上线前需实测。
    """
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(
            f"{XINGZHE_API_BASE}/activities/{activity_id}/stream/",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
            json={},
        )
        resp.raise_for_status()
        return resp.json()


async def get_activity_detail(access_token: str, activity_id: int | str) -> dict:
    """获取单条轨迹详情（GET /activities/{id}/）"""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{XINGZHE_API_BASE}/activities/{activity_id}/",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        resp.raise_for_status()
        return resp.json()
