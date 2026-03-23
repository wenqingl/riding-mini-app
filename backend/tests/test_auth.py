import pytest
from unittest.mock import AsyncMock, patch
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.auth_service import get_auth_url, exchange_code_for_token


def test_get_auth_url_contains_client_id():
    url = get_auth_url()
    assert "client_id=" in url
    assert "response_type=code" in url
    assert "scope=write" in url


def test_get_auth_url_contains_redirect():
    url = get_auth_url()
    assert "redirect_uri=" in url


@pytest.mark.asyncio
async def test_exchange_code_for_token():
    mock_response = {"access_token": "test_token", "refresh_token": "test_refresh"}
    with patch("services.auth_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.post = AsyncMock()
        instance.post.return_value.raise_for_status = AsyncMock()
        instance.post.return_value.json = lambda: mock_response
        result = await exchange_code_for_token("test_code")
        assert result["access_token"] == "test_token"
