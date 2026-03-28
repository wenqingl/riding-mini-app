import pytest
from unittest.mock import AsyncMock, MagicMock, patch
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.record_service import get_records, get_activity_detail, get_activity_stream


@pytest.mark.asyncio
async def test_get_records():
    mock_resp = MagicMock()
    mock_resp.raise_for_status = MagicMock()
    mock_resp.json.return_value = {
        "count": 2,
        "results": [
            {"id": 1, "title": "骑行", "distance": 5000, "sport": 3},
            {"id": 2, "title": "夜骑", "distance": 3000, "sport": 3},
        ],
    }
    with patch("services.record_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.get = AsyncMock(return_value=mock_resp)
        data = await get_records("fake_token")
        assert data["count"] == 2
        assert len(data["results"]) == 2
        assert data["results"][0]["distance"] == 5000


@pytest.mark.asyncio
async def test_get_activity_detail():
    mock_resp = MagicMock()
    mock_resp.raise_for_status = MagicMock()
    mock_resp.json.return_value = {"id": 1, "user_id": 42, "distance": 5000, "sport": 3}
    with patch("services.record_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.get = AsyncMock(return_value=mock_resp)
        detail = await get_activity_detail("fake_token", 1)
        assert detail["id"] == 1
        assert detail["distance"] == 5000


@pytest.mark.asyncio
async def test_get_activity_stream():
    mock_resp = MagicMock()
    mock_resp.raise_for_status = MagicMock()
    mock_resp.json.return_value = [
        {"lat": 31.23, "lon": 121.47, "time": 1700000000000},
        {"lat": 31.24, "lon": 121.48, "time": 1700000060000},
    ]
    with patch("services.record_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.post = AsyncMock(return_value=mock_resp)
        stream = await get_activity_stream("fake_token", 1)
        assert len(stream) == 2
        assert stream[0]["lat"] == 31.23
