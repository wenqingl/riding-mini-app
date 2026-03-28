import pytest
from unittest.mock import AsyncMock, MagicMock, patch
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.upload_service import upload_to_xingzhe


@pytest.mark.asyncio
async def test_upload_to_xingzhe():
    mock_resp = MagicMock()
    mock_resp.raise_for_status = MagicMock()
    mock_resp.json.return_value = {"id": "new_record_123"}
    with patch("services.upload_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.post = AsyncMock(return_value=mock_resp)
        result = await upload_to_xingzhe("fake_token", b"fake_fit_data", title="合并骑行")
        assert result["id"] == "new_record_123"
