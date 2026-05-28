class UploadRecord {
  final String id;
  final String title;
  final String? fitFileUrl;   // 来自 /uploads/ 的直接下载地址
  final String? thumbnailUrl; // 来自 /activities/ 的缩略图
  final bool hasFitFile;      // true = 直接下载 FIT；false = 用 stream 接口
  final String date;
  final String distanceKm;
  final String duration;
  final int sport;
  bool selected;

  UploadRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.distanceKm,
    required this.duration,
    required this.sport,
    required this.hasFitFile,
    this.fitFileUrl,
    this.thumbnailUrl,
    this.selected = false,
  });

  factory UploadRecord.fromJson(Map<String, dynamic> json) {
    final fitFileUrl = json['fit_file'] as String?;
    final thumbnailUrl = json['thumbnail'] as String?;

    final title = (json['title'] as String?)?.isNotEmpty == true
        ? json['title'] as String
        : '骑行记录';

    final sport = (json['sport'] as num?)?.toInt() ?? 0;

    // 日期：upload_time (ISO) 或 start_time (unix ms)
    String date = '';
    final uploadTime = json['upload_time'] as String?;
    final startTimeRaw = json['start_time'];
    if (uploadTime != null && uploadTime.isNotEmpty) {
      date = uploadTime.split('T').first;
    } else if (startTimeRaw != null) {
      try {
        final ms = startTimeRaw is int
            ? startTimeRaw
            : int.parse(startTimeRaw.toString());
        date = DateTime.fromMillisecondsSinceEpoch(ms)
            .toLocal()
            .toString()
            .split(' ')
            .first;
      } catch (_) {}
    }

    // distance: m → km
    final distRaw = json['distance'] ?? json['total_distance'];
    final distKm = distRaw is num
        ? (distRaw / 1000.0).toStringAsFixed(1)
        : '?';

    // duration: s → Xh XXm
    final durRaw = (json['duration'] as num?)?.toInt();
    String dur = '--';
    if (durRaw != null && durRaw > 0) {
      final h = durRaw ~/ 3600;
      final m = (durRaw % 3600) ~/ 60;
      dur = h > 0 ? '${h}h${m.toString().padLeft(2, '0')}m' : '${m}m';
    }

    return UploadRecord(
      id: json['id']?.toString() ?? '',
      title: title,
      date: date,
      distanceKm: distKm,
      duration: dur,
      sport: sport,
      fitFileUrl: fitFileUrl,
      thumbnailUrl: thumbnailUrl,
      hasFitFile: fitFileUrl != null && fitFileUrl.isNotEmpty,
    );
  }

  String get sportName {
    const names = {0: '骑行', 1: '徒步', 2: '跑步', 3: '游泳'};
    return names[sport] ?? '运动';
  }
}
