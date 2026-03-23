import fitparse
import gpxpy
from io import BytesIO


def parse_fit_records(data: bytes) -> list:
    fitfile = fitparse.FitFile(BytesIO(data))
    records = []
    for record in fitfile.get_messages("record"):
        r = {}
        for field in record:
            r[field.name] = field.value
        if r.get("timestamp"):
            records.append(r)
    return sorted(records, key=lambda x: x["timestamp"])


def parse_gpx_records(data: bytes) -> list:
    gpx = gpxpy.parse(data.decode("utf-8"))
    records = []
    for track in gpx.tracks:
        for segment in track.segments:
            for point in segment.points:
                records.append({
                    "timestamp": point.time,
                    "position_lat": point.latitude,
                    "position_long": point.longitude,
                    "altitude": point.elevation,
                })
    return sorted(records, key=lambda x: x["timestamp"])


def parse_tcx_records(data: bytes) -> list:
    from lxml import etree
    root = etree.fromstring(data)
    ns = {"tcx": "http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"}
    records = []
    for trackpoint in root.findall(".//tcx:Trackpoint", ns):
        time_el = trackpoint.find("tcx:Time", ns)
        lat_el = trackpoint.find(".//tcx:LatitudeDegrees", ns)
        lon_el = trackpoint.find(".//tcx:LongitudeDegrees", ns)
        alt_el = trackpoint.find("tcx:AltitudeMeters", ns)
        hr_el = trackpoint.find(".//tcx:HeartRateBpm/tcx:Value", ns)
        if time_el is not None:
            from datetime import datetime
            r = {"timestamp": datetime.fromisoformat(time_el.text.replace("Z", "+00:00"))}
            if lat_el is not None:
                r["position_lat"] = float(lat_el.text)
            if lon_el is not None:
                r["position_long"] = float(lon_el.text)
            if alt_el is not None:
                r["altitude"] = float(alt_el.text)
            if hr_el is not None:
                r["heart_rate"] = int(hr_el.text)
            records.append(r)
    return sorted(records, key=lambda x: x["timestamp"])


def merge_records(file_list: list[dict]) -> list:
    all_records = []
    for f in file_list:
        fmt = f.get("format", "fit")
        if fmt == "fit":
            all_records.extend(parse_fit_records(f["data"]))
        elif fmt == "gpx":
            all_records.extend(parse_gpx_records(f["data"]))
        elif fmt == "tcx":
            all_records.extend(parse_tcx_records(f["data"]))
    return sorted(all_records, key=lambda x: x["timestamp"])


def records_to_gpx(records: list) -> bytes:
    import gpxpy.gpx
    gpx = gpxpy.gpx.GPX()
    gpx_track = gpxpy.gpx.GPXTrack()
    gpx.tracks.append(gpx_track)
    gpx_segment = gpxpy.gpx.GPXTrackSegment()
    gpx_track.segments.append(gpx_segment)
    for r in records:
        point = gpxpy.gpx.GPXTrackPoint(
            latitude=r.get("position_lat", 0),
            longitude=r.get("position_long", 0),
            elevation=r.get("altitude", 0),
            time=r.get("timestamp"),
        )
        gpx_segment.points.append(point)
    return gpx.to_xml().encode("utf-8")
