import pytest
from unittest.mock import AsyncMock, MagicMock, patch
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.upload_service import upload_to_xingzhe


@pytest.mark.asyncio
async def test_upload_to_xingzhe():
    with patch("services.upload_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.post = AsyncMock()
        instance.post.return_value.raise_for_status = MagicMock()
        instance.post.return_value.json = lambda: {"id": "new_record_123"}
        result = await upload_to_xingzhe("fake_token", b"fake_data", "merged.gpx")
        assert result["id"] == "new_record_123"
