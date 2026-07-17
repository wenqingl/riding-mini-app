import 'dart:io';
import 'dart:typed_data';

void main() async {
  await parseFit('REF', r'D:\tmp_ref.fit');
  await parseFit('GEN', r'D:\tmp_gen.fit');
}

Future<void> parseFit(String label, String path) async {
  final bytes = await File(path).readAsBytes();
  final data = bytes.buffer.asByteData();
  print('\n== $label ==');
  print('size: ${bytes.length}');
  final headerSize = bytes[0];
  final dataSize = data.getUint32(4, Endian.little);
  print('headerSize=$headerSize  dataSize=$dataSize');

  int pos = headerSize;
  final end = headerSize + dataSize;
  final Map<int, int> localToGlobal = {};
  final Map<int, List<_Field>> localFields = {};
  bool bigEndian = false;

  while (pos < end) {
    if (pos >= bytes.length) break;
    final header = bytes[pos];
    final isDefinition = (header & 0x40) != 0;
    final localId = header & 0x0F;

    if (isDefinition) {
      pos++;
      pos++; // reserved
      bigEndian = bytes[pos++] != 0;
      final globalId = data.getUint16(pos, bigEndian ? Endian.big : Endian.little);
      pos += 2;
      final fieldCount = bytes[pos++];
      final fields = <_Field>[];
      for (int i = 0; i < fieldCount; i++) {
        fields.add(_Field(bytes[pos++], bytes[pos++], bytes[pos++]));
      }
      localToGlobal[localId] = globalId;
      localFields[localId] = fields;
    } else {
      pos++;
      final globalId = localToGlobal[localId] ?? -1;
      final fields = localFields[localId] ?? [];
      if (globalId == 18) {
        print('SESSION message fields:');
        int fp = pos;
        for (final f in fields) {
          final val = _read(data, fp, f.size, bigEndian);
          print('  field_num=${f.num}  size=${f.size}  value=$val');
          fp += f.size;
        }
      }
      pos += fields.fold(0, (s, f) => s + f.size);
    }
  }
}

dynamic _read(ByteData d, int off, int size, bool be) {
  final e = be ? Endian.big : Endian.little;
  switch (size) {
    case 1: return d.getUint8(off);
    case 2: return d.getUint16(off, e);
    case 4: return d.getUint32(off, e);
    default: return '?';
  }
}

class _Field { final int num, size, type; _Field(this.num, this.size, this.type); }
