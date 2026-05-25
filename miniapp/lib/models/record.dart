class RideRecord {
  final String id;
  final String date;
  final String distanceKm;
  final String duration;
  final String? title;
  bool selected;

  RideRecord({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.duration,
    this.title,
    this.selected = false,
  });

  factory RideRecord.fromJson(Map<String, dynamic> json) {
    // distance in metres → km
    final distRaw = json['distance'];
    final distKm = distRaw != null
        ? (distRaw / 1000.0).toStringAsFixed(1)
        : '0';

    // duration in seconds → HH:MM:SS
    final durRaw = json['duration'] as int?;
    String duration = '00:00:00';
    if (durRaw != null) {
      final h = durRaw ~/ 3600;
      final m = (durRaw % 3600) ~/ 60;
      final s = durRaw % 60;
      duration =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    // date from start_time or date field
    String date = '';
    final startTime = json['start_time'] as String?;
    if (startTime != null && startTime.isNotEmpty) {
      date = startTime.split('T').first;
    } else {
      date = json['date'] as String? ?? '';
    }

    return RideRecord(
      id: json['id'].toString(),
      date: date,
      distanceKm: distKm,
      duration: duration,
      title: json['title'] as String?,
    );
  }
}
