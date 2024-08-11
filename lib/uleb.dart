import 'dart:typed_data';

List<int> ulebEncode(int num) {
  final arr = <int>[];
  var len = 0;

  if (num == 0) {
    return [0];
  }

  while (num > 0) {
    arr.add(num & 0x7f);
    if ((num >>= 7) != 0) {
      arr[len] |= 0x80;
    }
    len += 1;
  }

  return arr;
}

// Helper utility: decode ULEB as an array of numbers.
(int, int) ulebDecode(Uint8List arr) {
  int total = 0;
  int shift = 0;
  int len = 0;

  while (true) {
    int byte = arr[len];
    len += 1;
    total |= (byte & 0x7f) << shift;
    if ((byte & 0x80) == 0) {
      break;
    }
    shift += 7;
  }

  return (total, len);
}