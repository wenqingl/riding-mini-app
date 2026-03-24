import pytest
from unittest.mock import AsyncMock, patch
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.auth_service import get_auth_url, exchange_code_for_token, refresh_access_token


def test_get_auth_url_contains_client_id():
    url, state = get_auth_url()
    assert "client_id=" in url
    assert "response_type=code" in url
    assert "scope=write" in url
    assert len(state) > 0


def test_get_auth_url_contains_redirect():
    url, _ = get_auth_url()
    assert "redirect_uri=" in url


def test_get_auth_url_generates_unique_state():
    _, state1 = get_auth_url()
    _, state2 = get_auth_url()
    assert state1 != state2, "Each call should generate a unique CSRF state"


def test_get_auth_url_with_custom_state():
    url, state = get_auth_url(state="custom_state")
    assert state == "custom_state"
    assert "state=custom_state" in url


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
        assert result["refresh_token"] == "test_refresh"


@pytest.mark.asyncio
async def test_refresh_access_token():
    mock_response = {"access_token": "new_token"}
    with patch("services.auth_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.post = AsyncMock()
        instance.post.return_value.raise_for_status = AsyncMock()
        instance.post.return_value.json = lambda: mock_response
        result = await refresh_access_token("old_refresh_token")
        assert result["access_token"] == "new_token"
