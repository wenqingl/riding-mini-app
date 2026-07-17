import "dart:io";
import "dart:typed_data";
import "package:activity_files/activity_files.dart";

void main() async {
  final bytes = await File(r"D:\tmp_ref.fit").readAsBytes();
  final result = await ActivityFiles.load(bytes, format: ActivityFileFormat.fit, strictFitIntegrity: false);
  final a = result.activity;
  print("=== activity_files channels ===");
  for (final ch in a.channels.entries) {
    if (ch.value.isEmpty) continue;
    final vals = ch.value.map((s) => s.value).toList();
    final max = vals.reduce((a,b)=>a>b?a:b);
    print("  ${ch.key}: count=${vals.length}  max=${max.toStringAsFixed(4)}  last=${vals.last.toStringAsFixed(4)}");
  }

  // raw session
  print("\n=== raw session fields ===");
  final data = bytes.buffer.asByteData();
  final hdrSize = bytes[0];
  final dataEnd = hdrSize + data.getUint32(4, Endian.little);
  int pos = hdrSize;
  final Map<int,int> g={},rs={};
  final Map<int,bool> be={};
  final Map<int,List<int>> fN={},fS={};
  while (pos < dataEnd && pos < bytes.length) {
    final hdr = bytes[pos]; final lid = hdr & 0x0F;
    if ((hdr & 0x40) != 0) {
      final b=bytes[pos+2]!=0; final e=b?Endian.big:Endian.little;
      final gid=data.getUint16(pos+3,e); final fc=bytes[pos+5];
      final ns=<int>[],ss=<int>[];
      for(int i=0;i<fc;i++){ns.add(bytes[pos+6+i*3]);ss.add(bytes[pos+6+i*3+1]);}
      g[lid]=gid; be[lid]=b; fN[lid]=ns; fS[lid]=ss; rs[lid]=ss.fold(0,(s,v)=>s+v);
      pos+=6+fc*3;
    } else {
      pos++;
      if ((g[lid]??-1)==18) {
        int fp=pos;
        for(int i=0;i<(fS[lid]??[]).length;i++){
          final sz=fS[lid]![i]; final nm=fN[lid]![i];
          final e2=(be[lid]??false)?Endian.big:Endian.little;
          final raw=sz==4?data.getUint32(fp,e2):sz==2?data.getUint16(fp,e2):data.getUint8(fp);
          String note="";
          if(nm==9) note=" -> ${raw/100.0}m = ${raw/100000.0}km";
          if(nm==7||nm==8) note=" -> ${raw/1000.0}s = ${(raw/60000.0).toStringAsFixed(1)}min";
          if(nm==14||nm==15) note=" mm/s -> ${(raw*3.6/1000.0).toStringAsFixed(1)}km/h";
          if(nm==5) note=" (sport)";
          print("  field[$nm] = $raw$note");
          fp+=sz;
        }
      }
      pos+=rs[lid]??0;
    }
  }
}
