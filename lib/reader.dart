import 'dart:typed_data';

import 'package:bcs/uleb.dart';

/// Class used for reading BCS data chunk by chunk. Meant to be used
/// by some wrapper, which will make sure that data is valid and is
/// matching the desired format.
///
/// ```dart
/// // data for this example is:
/// // { a: u8, b: u32, c: bool, d: u64 }
///
/// final reader = BcsReader(fromHEX("647f1a060001ffffe7890423c78a050102030405"));
/// final field1 = reader.read8();
/// final field2 = reader.read32();
/// final field3 = reader.read8() == 1; // bool
/// final field4 = reader.read64();
/// // ....
/// ```
///
/// Reading vectors is another deal in bcs. To read a vector, you first need to read
/// its length using {@link readULEB}. Here's an example:
/// ```dart
/// // data encoded: { field: [1, 2, 3, 4, 5] }
/// final reader = BcsReader(fromHEX("050102030405"));
/// final vec_length = reader.readULEB();
/// final elements = [];
/// for (var i = 0; i < vec_length; i++) {
///   elements.add(reader.read8());
/// }
/// print(elements); // [1,2,3,4,5]
/// ```
class BcsReader {
  late ByteData _dataView;
  int _bytePosition = 0;

  BcsReader(Uint8List data) {
    _dataView = ByteData.sublistView(data);
  }

  /// Shift current cursor position by [bytes].
  BcsReader shift(int bytes) {
    _bytePosition += bytes;
    return this;
  }

  /// Read U8 value from the buffer and shift cursor by 1.
  int read8() {
    final value = _dataView.getUint8(_bytePosition);
    shift(1);
    return value;
  }

  /// Read U16 value from the buffer and shift cursor by 2.
  int read16() {
    final value = _dataView.getUint16(_bytePosition, Endian.little);
    shift(2);
    return value;
  }

  /// Read U32 value from the buffer and shift cursor by 4.
  int read32() {
    final value = _dataView.getUint32(_bytePosition, Endian.little);
    shift(4);
    return value;
  }

  /// Read U64 value from the buffer and shift cursor by 8.
  BigInt read64() {
    final value1 = read32();
    final value2 = read32();
    final result = value2.toRadixString(16) + value1.toRadixString(16).padLeft(8, '0');

    return BigInt.parse(result, radix: 16);
  }

  /// Read U128 value from the buffer and shift cursor by 16.
  BigInt read128() {
    final value1 = read64();
    final value2 = read64();
    final result = value2.toRadixString(16) + value1.toRadixString(16).padLeft(16, '0');

    return BigInt.parse(result, radix: 16);
  }

  /// Read U256 value from the buffer and shift cursor by 32.
  BigInt read256() {
    final value1 = read128();
    final value2 = read128();
    final result = value2.toRadixString(16) + value1.toRadixString(16).padLeft(32, '0');

    return BigInt.parse(result, radix: 16);
  }


  /// Read `num` number of bytes from the buffer and shift cursor by `num`.
  Uint8List readBytes(int num) {
    int start = _bytePosition + _dataView.offsetInBytes;
    final value = Uint8List.view(_dataView.buffer, start, num);

    shift(num);

    return value;
  }

  /// Read ULEB value - an integer of varying size. Used for enum indexes and
  /// vector lengths.
  int readULEB() {
    int start = _bytePosition + _dataView.offsetInBytes;
    final buffer = Uint8List.view(_dataView.buffer, start);
    final (value, length) = ulebDecode(buffer);

    shift(length);

    return value;
  }

  /// Read a BCS vector: read a length and then apply function `cb` X times
  /// where X is the length of the vector, defined as ULEB in BCS bytes.
  /// 
  /// Array of the resulting values, returned by callback.
  List<dynamic> readVec(dynamic Function(BcsReader reader, int i, int length) cb) {
    int length = readULEB();
    final result = <dynamic>[];
    for (int i = 0; i < length; i++) {
      result.add(cb(this, i, length));
    }
    return result;
  }

  List<dynamic> readFixedArray(int size, dynamic Function(BcsReader reader, int i, int length) cb) {
    int length = size;
    final result = <dynamic>[];
    for (int i = 0; i < length; i++) {
      result.add(cb(this, i, length));
    }
    return result;
  }
}