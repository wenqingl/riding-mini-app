import 'dart:typed_data';
import 'package:activity_files/activity_files.dart';
import 'dart:convert';

/// 本地 FIT 文件合并服务
class FitMergeService {
  /// 合并多个 FIT 二进制文件，返回合并后的 FIT 字节
  static Future<Uint8List> mergeFitFiles(List<Uint8List> fitFiles) async {
    if (fitFiles.isEmpty) throw ArgumentError('No FIT files provided');
    if (fitFiles.length == 1) return fitFiles.first;

    final activities = <RawActivity>[];
    for (int i = 0; i < fitFiles.length; i++) {
      final result = await ActivityFiles.load(fitFiles[i]);
      if (result.hasErrors && result.activity.points.isEmpty) {
        throw FitMergeException(
            'FIT file ${i + 1} parse failed: ${result.diagnosticsSummary()}');
      }
      activities.add(result.activity);
    }

    // 合并所有 points，按时间排序
    final allPoints = activities.expand((a) => a.points).toList()
      ..sort((a, b) {
        final ta = a.time;
        final tb = b.time;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });

    // 合并 channels（心率、速度、踏频等），按时间排序
    final mergedChannels = <Channel, List<Sample>>{};
    for (final activity in activities) {
      for (final entry in activity.channels.entries) {
        mergedChannels.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
    }
    for (final key in mergedChannels.keys) {
      mergedChannels[key]!.sort((a, b) => a.time.compareTo(b.time));
    }

    // 用第一个 activity 作为模板，替换 points 和 channels
    final merged = activities.first.copyWith(
      points: allPoints,
      channels: mergedChannels,
      laps: [], // 合并后 lap 数据不再准确，清空
    );

    // normalize：去重 + 裁剪无效点
    final normalized = ActivityFiles.normalizeActivity(merged);

    // 导出为 FIT
    final exportResult = await ActivityFiles.export(
      activity: normalized,
      to: ActivityFileFormat.fit,
    );

    if (exportResult.hasErrors) {
      throw FitMergeException(
          'FIT export failed: ${exportResult.diagnosticsSummary()}');
    }

    return exportResult.asBytes();
  }

  /// 将行者 stream 接口返回的 JSON 转换为 FIT 字节
  /// 行者 stream 可能返回多种格式，统一先转成 GPX XML 再 load
  static Future<Uint8List> streamJsonToFit(dynamic streamData) async {
    // 收集 GPS 点
    final points = <Map<String, dynamic>>[];

    if (streamData is List) {
      for (final p in streamData) {
        if (p is Map<String, dynamic>) points.add(p);
      }
    } else if (streamData is Map<String, dynamic>) {
      if (streamData.containsKey('points')) {
        final pts = streamData['points'];
        if (pts is List) {
          for (final p in pts) {
            if (p is Map<String, dynamic>) points.add(p);
          }
        }
      } else if (streamData.containsKey('latitudes')) {
        final lats = streamData['latitudes'] as List;
        final lons = streamData['longitudes'] as List;
        final times = streamData['timestamps'] as List? ?? [];
        final alts = streamData['altitudes'] as List? ?? [];
        for (int i = 0; i < lats.length; i++) {
          points.add({
            'lat': lats[i],
            'lon': lons[i],
            if (i < times.length) 'time': times[i],
            if (i < alts.length) 'ele': alts[i],
          });
        }
      }
    }

    if (points.isEmpty) {
      throw FitMergeException('Stream data contains no GPS points');
    }

    // 构建 GPX XML
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">');
    buf.writeln('<trk><trkseg>');
    for (final p in points) {
      final lat = p['lat'] ?? p['latitude'] ?? p['position_lat'];
      final lon = p['lon'] ?? p['lng'] ?? p['longitude'] ?? p['position_long'];
      if (lat == null || lon == null) continue;
      final ele = p['ele'] ?? p['elevation'] ?? p['altitude'] ?? p['alt'];
      final time = p['time'] ?? p['timestamp'];
      buf.write('<trkpt lat="$lat" lon="$lon">');
      if (ele != null) buf.write('<ele>$ele</ele>');
      if (time != null) {
        String timeStr;
        if (time is num) {
          final ms = time > 1e12 ? time.toInt() : (time * 1000).toInt();
          timeStr = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
              .toIso8601String();
        } else {
          timeStr = time.toString();
        }
        buf.write('<time>$timeStr</time>');
      }
      buf.writeln('</trkpt>');
    }
    buf.writeln('</trkseg></trk></gpx>');

    final gpxBytes = utf8.encode(buf.toString());
    final loadResult = await ActivityFiles.load(Uint8List.fromList(gpxBytes));
    if (loadResult.hasErrors && loadResult.activity.points.isEmpty) {
      throw FitMergeException(
          'GPX conversion failed: ${loadResult.diagnosticsSummary()}');
    }

    final exportResult = await ActivityFiles.export(
      activity: ActivityFiles.normalizeActivity(loadResult.activity),
      to: ActivityFileFormat.fit,
    );
    if (exportResult.hasErrors) {
      throw FitMergeException(
          'FIT export failed: ${exportResult.diagnosticsSummary()}');
    }
    return exportResult.asBytes();
  }
}

class FitMergeException implements Exception {
  final String message;
  FitMergeException(this.message);

  @override
  String toString() => 'FitMergeException: $message';
}
