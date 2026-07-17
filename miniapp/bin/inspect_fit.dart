import 'dart:io';
import 'dart:typed_data';
import 'package:activity_files/activity_files.dart';
import '../lib/services/fit_merge_service.dart';

void main() async {
  final points = List.generate(100, (i) => [116.328 + i * 0.001, 39.817 + i * 0.0005]);
  final fakeStream = {'code': 0, 'data': {'location': points}};
  final startTime = DateTime(2026, 5, 23, 8, 0, 0).toUtc();

  print('== generating patched FIT ==');
  final fitBytes = await FitMergeService.streamJsonToFit(
    fakeStream,
    activityStartTime: startTime,
    xingzheSport: 3,
  );
  print('size: ${fitBytes.length} bytes');
  await File(r'D:\tmp_patched.fit').writeAsBytes(fitBytes);

  // parse session
  print('\n== session fields ==');
  final data = fitBytes.buffer.asByteData();
  final headerSize = fitBytes[0];
  int pos = headerSize;
  final end = headerSize + data.getUint32(4, Endian.little);
  final Map<int, int> g = {};
  final Map<int, List<int>> fn = {}, fs = {};
  while (pos < end && pos < fitBytes.length) {
    final hdr = fitBytes[pos];
    final isDef = (hdr & 0x40) != 0;
    final lid = hdr & 0x0F;
    if (isDef) {
      final gid = data.getUint16(pos + 3, Endian.little);
      final fc = fitBytes[pos + 5];
      final nums = <int>[], sizes = <int>[];
      for (int i = 0; i < fc; i++) { nums.add(fitBytes[pos+6+i*3]); sizes.add(fitBytes[pos+6+i*3+1]); }
      g[lid] = gid; fn[lid] = nums; fs[lid] = sizes;
      pos += 6 + fc * 3;
    } else {
      pos++;
      final gid = g[lid] ?? -1;
      final sizes = fs[lid] ?? [];
      final nums = fn[lid] ?? [];
      if (gid == 18) {
        int fp = pos;
        for (int i = 0; i < sizes.length; i++) {
          final v = sizes[i]==4 ? data.getUint32(fp,Endian.little) : sizes[i]==2 ? data.getUint16(fp,Endian.little) : data.getUint8(fp);
          String meaning = '';
          if (nums[i]==253) meaning='timestamp';
          else if (nums[i]==2) meaning='start_time';
          else if (nums[i]==5) meaning='sport';
          else if (nums[i]==7) meaning='total_elapsed_time(ms)';
          else if (nums[i]==9) meaning='total_distance(cm) = ${v/100.0}m';
          print('  field_num=${nums[i]} ($meaning): $v');
          fp += sizes[i];
        }
      }
      pos += sizes.fold(0, (s, v) => s + v);
    }
  }
}
