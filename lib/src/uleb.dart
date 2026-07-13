import 'dart:typed_data';

const _maxU32 = 0xffffffff;

/// Encodes [value] as an unsigned LEB128 byte sequence.
Uint8List ulebEncode(int value) {
  if (value < 0) {
    throw ArgumentError.value(
        value, 'value', 'Cannot ULEB128-encode a negative value');
  }
  if (value == 0) {
    return Uint8List.fromList([0]);
  }

  final bytes = <int>[];
  var remaining = value;
  while (remaining > 0) {
    var byte = remaining % 0x80;
    remaining ~/= 0x80;
    if (remaining != 0) {
      byte |= 0x80;
    }
    bytes.add(byte);
  }
  return Uint8List.fromList(bytes);
}

/// Decodes an unsigned LEB128 value from [bytes], starting at [offset].
///
/// Returns the decoded value together with the number of bytes consumed.
/// Throws a [FormatException] if the input ends before the value is
/// complete, or if the value exceeds the `u32` range BCS uses for sequence
/// lengths and enum variant indexes.
(int value, int length) ulebDecode(Uint8List bytes, [int offset = 0]) {
  var value = 0;
  var multiplier = 1;
  var length = 0;

  while (true) {
    if (offset + length >= bytes.length) {
      throw const FormatException(
          'Unexpected end of input while decoding ULEB128');
    }
    final byte = bytes[offset + length];
    length++;
    value += (byte & 0x7f) * multiplier;
    if ((byte & 0x80) == 0) {
      break;
    }
    // BCS caps ULEB128 values at u32, which needs at most 5 bytes.
    if (length >= 5) {
      throw const FormatException(
          'ULEB128 value exceeds the u32 range used by BCS');
    }
    multiplier *= 0x80;
  }

  if (value > _maxU32) {
    throw const FormatException(
        'ULEB128 value exceeds the u32 range used by BCS');
  }
  return (value, length);
}
