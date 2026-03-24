"""Integration test for POST /api/merge-and-upload (AT-03).

Tests the full flow: download records → merge → upload.
Mocks external行者 API calls, verifies the orchestration logic.
"""
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


SAMPLE_GPX_1 = b"""<?xml version="1.0"?>
<gpx version="1.1">
  <trk><name>Ride 1</name><trkseg>
    <trkpt lat="39.9" lon="116.4"><ele>50</ele><time>2026-03-01T08:00:00Z</time></trkpt>
    <trkpt lat="39.91" lon="116.41"><ele>55</ele><time>2026-03-01T08:05:00Z</time></trkpt>
  </trkseg></trk>
</gpx>"""

SAMPLE_GPX_2 = b"""<?xml version="1.0"?>
<gpx version="1.1">
  <trk><name>Ride 2</name><trkseg>
    <trkpt lat="39.92" lon="116.42"><ele>60</ele><time>2026-03-01T10:00:00Z</time></trkpt>
    <trkpt lat="39.93" lon="116.43"><ele>65</ele><time>2026-03-01T10:05:00Z</time></trkpt>
  </trkseg></trk>
</gpx>"""


@pytest.mark.asyncio
async def test_merge_and_upload_success():
    """Verify merge-and-upload: downloads 2 records, merges, uploads."""
    from routers.merge import merge_and_upload, MergeRequest

    with patch("routers.merge.download_record_file") as mock_download, \
         patch("routers.merge.upload_to_xingzhe") as mock_upload:

        mock_download.side_effect = AsyncMock(side_effect=[SAMPLE_GPX_1, SAMPLE_GPX_2])
        mock_upload.return_value = {"id": "merged_123"}

        body = MergeRequest(record_ids=["r1", "r2"], format="gpx")
        result = await merge_and_upload(body, authorization="Bearer test_token")

        assert result["success"] is True
        assert result["record_id"] == "merged_123"
        assert result["total_points"] == 4  # 2 from each file

        # Verify download was called for both records
        assert mock_download.call_count == 2
        # Verify upload was called once
        mock_upload.assert_called_once()


@pytest.mark.asyncio
async def test_merge_and_upload_min_records():
    """Should reject if fewer than 2 records."""
    from routers.merge import merge_and_upload, MergeRequest
    from fastapi import HTTPException

    body = MergeRequest(record_ids=["r1"], format="gpx")
    with pytest.raises(HTTPException) as exc_info:
        await merge_and_upload(body, authorization="Bearer test_token")
    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_merge_and_upload_download_failure():
    """Should return 502 if download fails."""
    from routers.merge import merge_and_upload, MergeRequest
    from fastapi import HTTPException

    with patch("routers.merge.download_record_file") as mock_download:
        mock_download.side_effect = Exception("Network error")

        body = MergeRequest(record_ids=["r1", "r2"], format="gpx")
        with pytest.raises(HTTPException) as exc_info:
            await merge_and_upload(body, authorization="Bearer test_token")
        assert exc_info.value.status_code == 502


@pytest.mark.asyncio
async def test_merge_and_upload_upload_failure():
    """Should return partial success if upload fails but merge worked."""
    from routers.merge import merge_and_upload, MergeRequest

    with patch("routers.merge.download_record_file") as mock_download, \
         patch("routers.merge.upload_to_xingzhe") as mock_upload:

        mock_download.side_effect = AsyncMock(side_effect=[SAMPLE_GPX_1, SAMPLE_GPX_2])
        mock_upload.side_effect = Exception("Upload server error")

        body = MergeRequest(record_ids=["r1", "r2"], format="gpx")
        result = await merge_and_upload(body, authorization="Bearer test_token")

        assert result["success"] is False
        assert result["merged_data_available"] is True
        assert result["total_points"] == 4


@pytest.mark.asyncio
async def test_merge_only_returns_gpx():
    """Verify merge-only endpoint returns downloadable GPX."""
    from routers.merge import merge_only, MergeRequest

    with patch("routers.merge.download_record_file") as mock_download:
        mock_download.side_effect = AsyncMock(side_effect=[SAMPLE_GPX_1, SAMPLE_GPX_2])

        body = MergeRequest(record_ids=["r1", "r2"], format="gpx")
        response = await merge_only(body, authorization="Bearer test_token")

        assert response.status_code == 200
        assert b"gpx" in response.body
        assert b"trkpt" in response.body
