"""Integration test for POST /api/merge-and-upload (AT-03).

Tests the full flow: download activity streams → merge → upload.
Mocks external行者 API calls, verifies the orchestration logic.
"""
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# 模拟 stream 接口返回的 GPS 点数据
SAMPLE_STREAM_1 = [
    {"lat": 39.9, "lon": 116.4, "ele": 50, "time": 1700000000000},
    {"lat": 39.91, "lon": 116.41, "ele": 55, "time": 1700000300000},
]

SAMPLE_STREAM_2 = [
    {"lat": 39.92, "lon": 116.42, "ele": 60, "time": 1700001000000},
    {"lat": 39.93, "lon": 116.43, "ele": 65, "time": 1700001300000},
]


@pytest.mark.asyncio
async def test_merge_and_upload_success():
    """Verify merge-and-upload: downloads 2 activity streams, merges, uploads."""
    from routers.merge import merge_and_upload, MergeRequest

    with patch("routers.merge.get_activity_stream") as mock_stream, \
         patch("routers.merge.upload_to_xingzhe") as mock_upload:

        mock_stream.side_effect = AsyncMock(side_effect=[SAMPLE_STREAM_1, SAMPLE_STREAM_2])
        mock_upload.return_value = {"id": "merged_123"}

        body = MergeRequest(record_ids=[1, 2], format="gpx")
        result = await merge_and_upload(body, authorization="Bearer test_token")

        assert result["success"] is True
        assert result["record_id"] == "merged_123"
        assert result["total_points"] == 4

        assert mock_stream.call_count == 2
        mock_upload.assert_called_once()


@pytest.mark.asyncio
async def test_merge_and_upload_min_records():
    """Should reject if fewer than 2 records."""
    from routers.merge import merge_and_upload, MergeRequest
    from fastapi import HTTPException

    body = MergeRequest(record_ids=[1], format="gpx")
    with pytest.raises(HTTPException) as exc_info:
        await merge_and_upload(body, authorization="Bearer test_token")
    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_merge_and_upload_download_failure():
    """Should return 502 if stream download fails."""
    from routers.merge import merge_and_upload, MergeRequest
    from fastapi import HTTPException

    with patch("routers.merge.get_activity_stream") as mock_stream:
        mock_stream.side_effect = Exception("Network error")

        body = MergeRequest(record_ids=[1, 2], format="gpx")
        with pytest.raises(HTTPException) as exc_info:
            await merge_and_upload(body, authorization="Bearer test_token")
        assert exc_info.value.status_code == 502


@pytest.mark.asyncio
async def test_merge_and_upload_upload_failure():
    """Should return partial success if upload fails but merge worked."""
    from routers.merge import merge_and_upload, MergeRequest

    with patch("routers.merge.get_activity_stream") as mock_stream, \
         patch("routers.merge.upload_to_xingzhe") as mock_upload:

        mock_stream.side_effect = AsyncMock(side_effect=[SAMPLE_STREAM_1, SAMPLE_STREAM_2])
        mock_upload.side_effect = Exception("Upload server error")

        body = MergeRequest(record_ids=[1, 2], format="gpx")
        result = await merge_and_upload(body, authorization="Bearer test_token")

        assert result["success"] is False
        assert result["merged_data_available"] is True
        assert result["total_points"] == 4


@pytest.mark.asyncio
async def test_merge_only_returns_gpx():
    """Verify merge-only endpoint returns downloadable GPX."""
    from routers.merge import merge_only, MergeRequest

    with patch("routers.merge.get_activity_stream") as mock_stream:
        mock_stream.side_effect = AsyncMock(side_effect=[SAMPLE_STREAM_1, SAMPLE_STREAM_2])

        body = MergeRequest(record_ids=[1, 2], format="gpx")
        response = await merge_only(body, authorization="Bearer test_token")

        assert response.status_code == 200
        assert b"gpx" in response.body
        assert b"trkpt" in response.body
