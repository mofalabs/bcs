import 'dart:math' as math;
import 'dart:typed_data';

import 'uleb.dart';

final BigInt _maxU32 = BigInt.from(0xffffffff);
final BigInt _maxU64 = (BigInt.one << 64) - BigInt.one;
final BigInt _maxU128 = (BigInt.one << 128) - BigInt.one;

/// Options controlling the buffer of a [BcsWriter].
class BcsWriterOptions {
  /// The initial size (in bytes) of the buffer.
  final int? size;

  /// The maximum size (in bytes) the buffer is allowed to grow to.
  final int? maxSize;

  const BcsWriterOptions({this.size, this.maxSize});
}

/// Writes BCS primitives into a growable byte buffer.
///
/// Usually used indirectly through `BcsType.serialize`, but can be driven by
/// hand when encoding data without a schema. Writes can be chained with
/// cascades:
///
/// ```dart
/// final writer = BcsWriter()
///   ..write8(10)
///   ..write32(1000000);
/// final bytes = writer.toBytes();
/// ```
class BcsWriter {
  Uint8List _buffer;
  ByteData _view;
  int _length = 0;
  final int? _maxSize;

  /// Creates a writer with an initial buffer of [size] bytes that grows
  /// geometrically as needed, up to [maxSize] bytes if given.
  BcsWriter({int size = 1024, int? maxSize})
      : _buffer = Uint8List(_checkInitialSize(size, maxSize)),
        _view = ByteData(0),
        _maxSize = maxSize {
    _view = ByteData.sublistView(_buffer);
  }

  static int _checkInitialSize(int size, int? maxSize) {
    if (size < 0) {
      throw ArgumentError.value(
          size, 'size', 'Buffer size must not be negative');
    }
    if (maxSize != null && size > maxSize) {
      throw ArgumentError.value(
          size, 'size', 'Buffer size cannot exceed maxSize ($maxSize)');
    }
    return size;
  }

  /// The number of bytes written so far.
  int get length => _length;

  void _ensure(int count) {
    final required = _length + count;
    if (required <= _buffer.length) {
      return;
    }
    if (_maxSize != null && required > _maxSize) {
      throw ArgumentError(
        'Attempting to serialize to BCS, but buffer does not have enough size. '
        'Max size: $_maxSize, Required size: $required',
      );
    }

    var nextSize = math.max(_buffer.length * 2, required);
    if (_maxSize != null) {
      nextSize = math.min(nextSize, _maxSize);
    }
    final nextBuffer = Uint8List(nextSize)..setRange(0, _length, _buffer);
    _buffer = nextBuffer;
    _view = ByteData.sublistView(_buffer);
  }

  void _checkUint(int value, int max, String type) {
    if (value < 0 || value > max) {
      throw ArgumentError.value(
          value, 'value', 'Expected $type value in range 0-$max');
    }
  }

  void _checkBigUint(BigInt value, BigInt max, String type) {
    if (value < BigInt.zero || value > max) {
      throw ArgumentError.value(
          value, 'value', 'Expected $type value in range 0-$max');
    }
  }

  /// Writes an unsigned 8-bit integer.
  void write8(int value) {
    _checkUint(value, 0xff, 'u8');
    _ensure(1);
    _view.setUint8(_length, value);
    _length += 1;
  }

  /// Writes an unsigned 16-bit little-endian integer.
  void write16(int value) {
    _checkUint(value, 0xffff, 'u16');
    _ensure(2);
    _view.setUint16(_length, value, Endian.little);
    _length += 2;
  }

  /// Writes an unsigned 32-bit little-endian integer.
  void write32(int value) {
    _checkUint(value, 0xffffffff, 'u32');
    _ensure(4);
    _view.setUint32(_length, value, Endian.little);
    _length += 4;
  }

  /// Writes an unsigned 64-bit little-endian integer.
  void write64(BigInt value) {
    _checkBigUint(value, _maxU64, 'u64');
    write32((value & _maxU32).toInt());
    write32((value >> 32).toInt());
  }

  /// Writes an unsigned 128-bit little-endian integer.
  void write128(BigInt value) {
    _checkBigUint(value, _maxU128, 'u128');
    write64(value & _maxU64);
    write64(value >> 64);
  }

  /// Writes an unsigned 256-bit little-endian integer.
  void write256(BigInt value) {
    _checkBigUint(value, (BigInt.one << 256) - BigInt.one, 'u256');
    write128(value & _maxU128);
    write128(value >> 128);
  }

  /// Writes a ULEB128-encoded unsigned integer.
  void writeULEB(int value) {
    writeBytes(ulebEncode(value));
  }

  /// Writes raw [bytes] as-is (no length prefix).
  void writeBytes(Uint8List bytes) {
    _ensure(bytes.length);
    _buffer.setRange(_length, _length + bytes.length, bytes);
    _length += bytes.length;
  }

  /// Returns a copy of the bytes written so far.
  Uint8List toBytes() => _buffer.sublist(0, _length);
}
