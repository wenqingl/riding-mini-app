import pytest
from unittest.mock import AsyncMock, patch
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.record_service import get_records, download_record_file


@pytest.mark.asyncio
async def test_get_records():
    with patch("services.record_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.get = AsyncMock()
        instance.get.return_value.raise_for_status = AsyncMock()
        instance.get.return_value.json = lambda: [{"id": "1", "date": "2026-03-01", "distance": 50}]
        records = await get_records("fake_token")
        assert len(records) == 1
        assert records[0]["distance"] == 50


@pytest.mark.asyncio
async def test_download_record_file():
    with patch("services.record_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.get = AsyncMock()
        instance.get.return_value.raise_for_status = AsyncMock()
        instance.get.return_value.content = b"fake_fit_data"
        data = await download_record_file("fake_token", "123", "fit")
        assert data == b"fake_fit_data"
