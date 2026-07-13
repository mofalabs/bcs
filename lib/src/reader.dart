import 'dart:typed_data';

import 'uleb.dart';

/// Reads BCS primitives from a byte buffer, advancing an internal cursor.
///
/// Usually used indirectly through `BcsType.parse`, but can be driven by hand
/// when decoding data without a schema:
///
/// ```dart
/// final reader = BcsReader(hexDecode('0101000000'));
/// final flag = reader.read8();
/// final count = reader.read32();
/// ```
class BcsReader {
  final Uint8List _bytes;
  final ByteData _view;
  int _offset = 0;

  BcsReader(Uint8List bytes)
      : _bytes = bytes,
        _view = ByteData.sublistView(bytes);

  /// The current cursor position in bytes.
  int get offset => _offset;

  /// The number of unread bytes remaining in the buffer.
  int get remaining => _bytes.length - _offset;

  void _require(int count) {
    if (count > remaining) {
      throw RangeError(
        'Attempted to read $count byte(s) at offset $_offset, '
        'but only $remaining byte(s) remain',
      );
    }
  }

  /// Reads an unsigned 8-bit integer.
  int read8() {
    _require(1);
    final value = _view.getUint8(_offset);
    _offset += 1;
    return value;
  }

  /// Reads an unsigned 16-bit little-endian integer.
  int read16() {
    _require(2);
    final value = _view.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  /// Reads an unsigned 32-bit little-endian integer.
  int read32() {
    _require(4);
    final value = _view.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  /// Reads an unsigned 64-bit little-endian integer.
  BigInt read64() {
    final low = read32();
    final high = read32();
    return (BigInt.from(high) << 32) | BigInt.from(low);
  }

  /// Reads an unsigned 128-bit little-endian integer.
  BigInt read128() {
    final low = read64();
    final high = read64();
    return (high << 64) | low;
  }

  /// Reads an unsigned 256-bit little-endian integer.
  BigInt read256() {
    final low = read128();
    final high = read128();
    return (high << 128) | low;
  }

  /// Reads [count] bytes and returns them as a new (unaliased) list.
  Uint8List readBytes(int count) {
    RangeError.checkNotNegative(count, 'count');
    _require(count);
    final value = _bytes.sublist(_offset, _offset + count);
    _offset += count;
    return value;
  }

  /// Reads a ULEB128-encoded unsigned integer, used in BCS for vector
  /// lengths and enum variant indexes.
  int readULEB() {
    final (value, length) = ulebDecode(_bytes, _offset);
    _offset += length;
    return value;
  }
}
