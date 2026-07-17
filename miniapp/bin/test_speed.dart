import 'dart:math';
import 'package:activity_files/activity_files.dart';

double haver(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat/2)*sin(dLat/2) + cos(lat1*pi/180)*cos(lat2*pi/180)*sin(dLon/2)*sin(dLon/2);
  return 2*r*asin(sqrt(a));
}

void main() async {
  final start = DateTime(2026,5,23,8,0,0).toUtc();
  // 1 point/sec, ~5 m/s (18 km/h)
  final pts = List.generate(3600, (i) => GeoPoint(
    latitude: 39.817 + i*0.000045, longitude: 116.328 + i*0.000020,
    time: start.add(Duration(seconds: i)),
  ));
  final d01 = haver(pts[0].latitude, pts[0].longitude, pts[1].latitude, pts[1].longitude);
  print('p[0->1] dist=${d01.toStringAsFixed(3)}m -> expect speed=${d01.toStringAsFixed(3)}m/s = ${(d01*3.6).toStringAsFixed(1)}km/h');

  final a = RawActivity(points: pts, sport: Sport.cycling);
  final w = ActivityFiles.recomputeDistanceAndSpeed(a);
  final spd = w.channel(Channel.speed);
  final dist = w.channel(Channel.distance);
  final maxSpd = spd.map((s)=>s.value).reduce((a,b)=>a>b?a:b);
  print('speed[1]=${spd[1].value.toStringAsFixed(4)}m/s = ${(spd[1].value*3.6).toStringAsFixed(1)}km/h');
  print('speed max=${maxSpd.toStringAsFixed(4)}m/s = ${(maxSpd*3.6).toStringAsFixed(1)}km/h');
  print('distance last=${dist.last.value.toStringAsFixed(1)}m');

  // test with long gap (simulating stream points with 30s interval)
  final pts2 = List.generate(200, (i) => GeoPoint(
    latitude: 39.817 + i*0.000135, longitude: 116.328 + i*0.000060,
    time: start.add(Duration(seconds: i*30)),
  ));
  final d01b = haver(pts2[0].latitude, pts2[0].longitude, pts2[1].latitude, pts2[1].longitude);
  print('\nstream-style (30s interval):');
  print('p[0->1] dist=${d01b.toStringAsFixed(1)}m dt=30s -> real speed=${(d01b/30).toStringAsFixed(3)}m/s = ${(d01b/30*3.6).toStringAsFixed(1)}km/h');
  final a2 = RawActivity(points: pts2, sport: Sport.cycling);
  final w2 = ActivityFiles.recomputeDistanceAndSpeed(a2);
  final spd2 = w2.channel(Channel.speed);
  final maxSpd2 = spd2.map((s)=>s.value).reduce((a,b)=>a>b?a:b);
  print('speed[1]=${spd2[1].value.toStringAsFixed(4)}m/s = ${(spd2[1].value*3.6).toStringAsFixed(1)}km/h');
  print('speed max=${maxSpd2.toStringAsFixed(4)}m/s = ${(maxSpd2*3.6).toStringAsFixed(1)}km/h');
}
