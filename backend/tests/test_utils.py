import pytest
from fastapi import HTTPException
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from routers.utils import parse_token


def test_parse_token_valid():
    token = parse_token("Bearer abc123")
    assert token == "abc123"


def test_parse_token_missing_bearer():
    with pytest.raises(HTTPException) as exc_info:
        parse_token("abc123")
    assert exc_info.value.status_code == 401


def test_parse_token_empty():
    with pytest.raises(HTTPException) as exc_info:
        parse_token("")
    assert exc_info.value.status_code == 401


def test_parse_token_none():
    with pytest.raises(HTTPException) as exc_info:
        parse_token(None)
    assert exc_info.value.status_code == 401
