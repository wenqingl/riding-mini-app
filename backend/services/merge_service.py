import fitparse
import gpxpy
from lxml import etree
from datetime import datetime
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
    return records


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
    return records


def parse_tcx_records(data: bytes) -> list:
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
    return records


def stream_to_records(stream_data) -> list:
    """将行者 stream 接口返回数据转为 record 列表。

    行者 stream 接口可能返回的格式：
    1. [{"lat": ..., "lon": ..., "ele": ..., "time": ...}, ...]
    2. {"latitudes": [...], "longitudes": [...], "timestamps": [...]}
    3. {"points": [{"lat": ..., ...}, ...]}
    4. GPX/TCX/FIT 字节流

    如果无法识别格式，抛出 ValueError。
    """
    # 格式 1: 直接是 list
    if isinstance(stream_data, list):
        return [_point_to_record(p) for p in stream_data if _is_valid_point(p)]

    # 格式 4: 字节数据（GPX/TCX/FIT）
    if isinstance(stream_data, bytes):
        # 尝试 GPX
        try:
            return parse_gpx_records(stream_data)
        except Exception:
            pass
        # 尝试 TCX
        try:
            return parse_tcx_records(stream_data)
        except Exception:
            pass
        # 尝试 FIT
        try:
            return parse_fit_records(stream_data)
        except Exception:
            pass

    # 格式 2/3: 是 dict
    if isinstance(stream_data, dict):
        # 格式 3: 有 points 键
        if "points" in stream_data:
            return [_point_to_record(p) for p in stream_data["points"] if _is_valid_point(p)]

        # 格式 2: 并行数组
        if "latitudes" in stream_data and "longitudes" in stream_data:
            lats = stream_data["latitudes"]
            lons = stream_data["longitudes"]
            times = stream_data.get("timestamps", [])
            alts = stream_data.get("altitudes", [])
            records = []
            for i in range(len(lats)):
                r = {"position_lat": lats[i], "position_long": lons[i]}
                if i < len(times):
                    ts = times[i]
                    if isinstance(ts, (int, float)):
                        # unix ms → datetime
                        from datetime import timezone
                        r["timestamp"] = datetime.fromtimestamp(ts / 1000, tz=timezone.utc)
                    else:
                        r["timestamp"] = ts
                if i < len(alts):
                    r["altitude"] = alts[i]
                records.append(r)
            return records

        # 其他 dict 格式，尝试递归找列表
        for key, val in stream_data.items():
            if isinstance(val, list) and len(val) > 0 and isinstance(val[0], dict):
                return [_point_to_record(p) for p in val if _is_valid_point(p)]

    raise ValueError(f"Cannot parse stream data format: {type(stream_data)}")


def _is_valid_point(p: dict) -> bool:
    """检查一个点是否有基本的经纬度。"""
    if not isinstance(p, dict):
        return False
    lat = p.get("lat") or p.get("latitude") or p.get("position_lat")
    lon = p.get("lon") or p.get("lng") or p.get("longitude") or p.get("position_long")
    return lat is not None and lon is not None


def _point_to_record(p: dict) -> dict:
    """标准化一个 GPS 点为 record 格式。"""
    r = {
        "position_lat": p.get("lat") or p.get("latitude") or p.get("position_lat"),
        "position_long": p.get("lon") or p.get("lng") or p.get("longitude") or p.get("position_long"),
    }
    if "ele" in p:
        r["altitude"] = p["ele"]
    elif "elevation" in p:
        r["altitude"] = p["elevation"]
    elif "altitude" in p:
        r["altitude"] = p["altitude"]
    elif "alt" in p:
        r["altitude"] = p["alt"]

    ts = p.get("time") or p.get("timestamp")
    if ts is not None:
        if isinstance(ts, (int, float)):
            from datetime import timezone
            # 毫秒还是秒？>1e12 认为是毫秒
            if ts > 1e12:
                r["timestamp"] = datetime.fromtimestamp(ts / 1000, tz=timezone.utc)
            else:
                r["timestamp"] = datetime.fromtimestamp(ts, tz=timezone.utc)
        else:
            r["timestamp"] = ts

    if "heart_rate" in p:
        r["heart_rate"] = p["heart_rate"]
    if "hr" in p:
        r["heart_rate"] = p["hr"]

    return r


def merge_records(file_list: list[dict]) -> list:
    """合并多组 record 列表，按时间排序。"""
    all_records = []
    for f in file_list:
        fmt = f.get("format", "fit")
        data = f.get("data")
        if not data:
            continue
        if fmt == "fit":
            all_records.extend(parse_fit_records(data))
        elif fmt == "gpx":
            all_records.extend(parse_gpx_records(data))
        elif fmt == "tcx":
            all_records.extend(parse_tcx_records(data))
    return sorted(all_records, key=lambda x: x["timestamp"])


def records_to_fit(records: list, title: str = "合并骑行记录") -> bytes:
    """将 record 列表转为 FIT 文件（供上传行者使用）。"""
    from fit_tool.fit_file_builder import FitFileBuilder
    from fit_tool.profile.messages.file_id_message import FileIdMessage
    from fit_tool.profile.messages.event_message import EventMessage
    from fit_tool.profile.messages.record_message import RecordMessage
    from fit_tool.profile.profile_type import FileType, Manufacturer, Event, EventType
    from datetime import timezone
    import time as _time

    if not records:
        raise ValueError("No records to convert")

    builder = FitFileBuilder(auto_define=True, min_string_size=50)

    # File ID message
    file_id = FileIdMessage()
    file_id.type = FileType.ACTIVITY
    file_id.manufacturer = Manufacturer.DEVELOPMENT.value
    file_id.product = 0
    file_id.time_created = int(records[0].get("timestamp", datetime.now()).timestamp() * 1000)
    file_id.serial_number = 0x12345678
    builder.add(file_id)

    # Timer start event
    start_event = EventMessage()
    start_event.event = Event.TIMER
    start_event.event_type = EventType.START
    start_event.timestamp = file_id.time_created
    builder.add(start_event)

    # Record messages (GPS points)
    distance = 0.0
    prev_lat = None
    prev_lon = None
    for r in records:
        msg = RecordMessage()
        msg.position_lat = r.get("position_lat", 0)
        msg.position_long = r.get("position_long", 0)

        # Altitude: FIT stores as (altitude + 500) * 5
        alt = r.get("altitude")
        if alt is not None:
            msg.enhanced_altitude = int(alt)

        # Timestamp
        ts = r.get("timestamp")
        if isinstance(ts, datetime):
            msg.timestamp = int(ts.timestamp() * 1000)
        elif isinstance(ts, (int, float)):
            msg.timestamp = int(ts) if ts > 1e12 else int(ts * 1000)
        else:
            msg.timestamp = file_id.time_created

        # Cumulative distance
        lat, lon = msg.position_lat, msg.position_long
        if prev_lat is not None:
            from math import radians, sin, cos, sqrt, atan2
            R = 6371000  # earth radius in meters
            dlat = radians(lat - prev_lat)
            dlon = radians(lon - prev_lon)
            a = sin(dlat / 2) ** 2 + cos(radians(prev_lat)) * cos(radians(lat)) * sin(dlon / 2) ** 2
            distance += R * 2 * atan2(sqrt(a), sqrt(1 - a))
        msg.distance = distance
        prev_lat, prev_lon = lat, lon

        builder.add(msg)

    # Timer stop event
    stop_event = EventMessage()
    stop_event.event = Event.TIMER
    stop_event.event_type = EventType.STOP
    stop_event.timestamp = msg.timestamp if records else file_id.time_created
    builder.add(stop_event)

    fit_file = builder.build()
    return fit_file.to_bytes()


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
