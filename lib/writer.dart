import 'dart:math';
import 'dart:typed_data';

import 'package:bcs/consts.dart';
import 'package:bcs/uleb.dart';
import 'package:bcs/utils.dart';

/// Class used to write BCS data into a buffer. Initializer requires
/// some size of a buffer to init; default value for this buffer is 1KB.
///
/// Most methods are chainable, so it is possible to write them in one go.
///
/// ```dart
/// final serialized = BcsWriter()
///   .write8(10)
///   .write32(1000000)
///   .write64(BigInt.from(10000001000000))
///   .hex();
/// ```
class BcsWriter {
  late ByteData _dataView;
  int _bytePosition = 0;

  late int _size;
  late int _maxSize;
  late int _allocateSize;

  BcsWriter({int size = 1024, int? maxSize, int allocateSize = 1024}) {
    _size = size;
    _maxSize = maxSize ?? size;
    _allocateSize = allocateSize;
    _dataView = ByteData.sublistView(Uint8List(size));
  }

  ensureSizeOrGrow(int bytes) {
    final requiredSize = _bytePosition + bytes;
    if (requiredSize > _size) {
      final nextSize = min(_maxSize, _size + _allocateSize);
      if (requiredSize > nextSize) {
        throw ArgumentError(
          "Attempting to serialize to BCS, but buffer does not have enough size. Allocated size: $_size, Max size: $_maxSize, Required size: $requiredSize"
        );
      }

      _size = nextSize;
      final nextBuffer = Uint8List(_size);
      nextBuffer.setAll(0, _dataView.buffer.asUint8List());
      _dataView = ByteData.view(nextBuffer.buffer);
    }
  }

  /// Shift current cursor position by [bytes].
  BcsWriter shift(int bytes) {
    _bytePosition += bytes;
    return this;
  }

  /// Write a U8 value into a buffer and shift cursor position by 1.
  BcsWriter write8(int value) {
    ensureSizeOrGrow(1);
    _dataView.setUint8(_bytePosition, value);
    return shift(1);
  }

  /// Write a U16 value into a buffer and shift cursor position by 2.
  BcsWriter write16(int value) {
    ensureSizeOrGrow(2);
    _dataView.setUint16(_bytePosition, value, Endian.little);
    return shift(2);
  }

  /// Write a U32 value into a buffer and shift cursor position by 4.
  BcsWriter write32(int value) {
    ensureSizeOrGrow(4);
    _dataView.setUint32(_bytePosition, value, Endian.little);
    return shift(4);
  }

  /// Write a U64 value into a buffer and shift cursor position by 8.
  BcsWriter write64(BigInt value) {
    final low = value & BigInt.from(MAX_U32_NUMBER);
    final high = value >> 32;

    // write little endian number
    write32(low.toInt());
    write32(high.toInt());

    return this;
  }

  /// Write a U128 value into a buffer and shift cursor position by 16.
  BcsWriter write128(BigInt value) {
    final low = value & MAX_U64_BIG_INT;
    final high = value >> 64;

    // write little endian number
    write64(low);
    write64(high);

    return this;
  }

  /// Write a U256 value into a buffer and shift cursor position by 32.
  BcsWriter write256(BigInt value) {
    final low = value & MAX_U128_BIG_INT;
    final high = value >> 128;

    // write little endian number
    write128(low);
    write128(high);

    return this;
  }

  /// Write a ULEB value into a buffer and shift cursor position by number of bytes
  /// written.
  BcsWriter writeULEB(int value) {
    final data = ulebEncode(value);
    for (var item in data) {
      write8(item);
    }
    return this;
  }

  /// Write a vector into a buffer by first writing the vector length and then calling
  /// a callback on each passed value.
  BcsWriter writeVec(
    dynamic vector,
    dynamic Function(BcsWriter writer, dynamic el, int i, int len) cb
  ) {
    writeULEB(vector.length);
    List.from(vector).asMap().forEach((i, el) => cb(this, el, i, vector.length));
    return this;
  }

  BcsWriter writeFixedArray(
    dynamic vector,
    int? size,
    dynamic Function(BcsWriter writer, dynamic el, int i, int len) cb
  ) {
    final lst = List.from(vector);
    lst.sublist(0, size ?? lst.length).asMap().forEach((i, el) => cb(this, el, i, vector.length));
    return this;
  }

  /// Get underlying buffer taking only value bytes (in case initial buffer size was bigger).
  Uint8List toBytes() {
    return Uint8List.sublistView(_dataView, 0, _bytePosition);
  }

  String encode(Encoding encoding) {
    return encodeStr(toBytes(), encoding);
  }

  String hex() {
    return encode(Encoding.hex);
  }

  String base64() {
    return encode(Encoding.base64);
  }

  String base58() {
    return encode(Encoding.base58);
  }

}