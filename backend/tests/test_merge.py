import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.merge_service import parse_gpx_records, merge_records, records_to_gpx


SAMPLE_GPX = b"""<?xml version="1.0"?>
<gpx version="1.1">
  <trk><name>Test</name><trkseg>
    <trkpt lat="39.9" lon="116.4"><ele>50</ele><time>2026-03-01T08:00:00Z</time></trkpt>
    <trkpt lat="39.91" lon="116.41"><ele>55</ele><time>2026-03-01T08:05:00Z</time></trkpt>
  </trkseg></trk>
</gpx>"""


def test_parse_gpx_records():
    records = parse_gpx_records(SAMPLE_GPX)
    assert len(records) == 2
    assert records[0]["position_lat"] == 39.9


def test_merge_two_files():
    file1 = {"format": "gpx", "data": SAMPLE_GPX}
    file2 = {"format": "gpx", "data": SAMPLE_GPX}
    merged = merge_records([file1, file2])
    assert len(merged) == 4


def test_records_to_gpx_roundtrip():
    records = parse_gpx_records(SAMPLE_GPX)
    gpx_bytes = records_to_gpx(records)
    roundtrip = parse_gpx_records(gpx_bytes)
    assert len(roundtrip) == 2


def test_merge_empty_list():
    merged = merge_records([])
    assert merged == []


def test_gpx_records_sorted_by_time():
    records = parse_gpx_records(SAMPLE_GPX)
    for i in range(len(records) - 1):
        assert records[i]["timestamp"] <= records[i + 1]["timestamp"]
