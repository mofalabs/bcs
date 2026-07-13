import 'dart:convert';
import 'dart:typed_data';

import 'encoding.dart';
import 'reader.dart';
import 'writer.dart';

/// Extra options accepted by the `Bcs` type factories.
class BcsTypeOptions<T, Input> {
  /// Overrides the default name of the type.
  final String? name;

  /// Called with the input value before every write; throw to reject it.
  final void Function(Input value)? validate;

  const BcsTypeOptions({this.name, this.validate});
}

/// A BCS schema for values of type [T].
///
/// [T] is the type produced when reading, [Input] is the type accepted when
/// writing. They usually match, but may differ for types that accept several
/// input representations (for example `Bcs.u64` reads [BigInt] and accepts
/// `int`, `BigInt` or [String] input).
///
/// Instances are created through the factories on `Bcs` and composed into
/// complex schemas; [transform] maps a schema to different Dart types.
class BcsType<T, Input> {
  /// The descriptive name of this type, used in error messages.
  final String name;

  /// Reads a value of this type from [reader].
  final T Function(BcsReader reader) read;

  final int? Function(Input value)? _serializedSize;
  final void Function(Input value)? _validate;
  final void Function(Input value, BcsWriter writer) _write;

  BcsType({
    required this.name,
    required this.read,
    required void Function(Input value, BcsWriter writer) write,
    int? Function(Input value)? serializedSize,
    void Function(Input value)? validate,
  })  : _write = write,
        _serializedSize = serializedSize,
        _validate = validate;

  /// Returns the exact serialized size in bytes for [value], or `null` if it
  /// cannot be computed cheaply. Used to pre-size write buffers.
  int? serializedSizeOf(Input value) => _serializedSize?.call(value);

  /// Validates [value] without writing it; throws if it is not acceptable.
  void validate(Input value) => _validate?.call(value);

  /// Validates [value] and writes it to [writer].
  void write(Input value, BcsWriter writer) {
    validate(value);
    _write(value, writer);
  }

  /// Validates and serializes [value], returning the result as a
  /// [SerializedBcs] wrapper.
  SerializedBcs<T, Input> serialize(Input value, {BcsWriterOptions? options}) {
    validate(value);
    final writer = BcsWriter(
      size: options?.size ?? _serializedSize?.call(value) ?? 1024,
      maxSize: options?.maxSize,
    );
    _write(value, writer);
    return SerializedBcs(this, writer.toBytes());
  }

  /// Deserializes a value of this type from [bytes].
  T parse(Uint8List bytes) => read(BcsReader(bytes));

  /// Deserializes a value of this type from a hexadecimal string.
  T fromHex(String hex) => parse(hexDecode(hex));

  /// Deserializes a value of this type from a base58 string.
  T fromBase58(String b58) => parse(base58Decode(b58));

  /// Deserializes a value of this type from a base64 string.
  T fromBase64(String b64) => parse(base64Decode(b64));

  /// Creates a schema for the same wire format that reads and writes
  /// different Dart types, converting with [input] and [output].
  ///
  /// [input] is declared as returning `dynamic` so that schemas held as
  /// `BcsType<dynamic, dynamic>` can still be transformed; its result is cast
  /// to [Input] at write time.
  ///
  /// [input] may be invoked more than once per serialization (once to
  /// validate and once to write), so it must be a pure conversion without
  /// side effects.
  ///
  /// ```dart
  /// final address = Bcs.bytes(32).transform(
  ///   input: (String hex) => hexDecode(hex),
  ///   output: (bytes) => hexEncode(bytes),
  /// );
  /// ```
  BcsType<T2, Input2> transform<T2, Input2>({
    String? name,
    required dynamic Function(Input2 value) input,
    required T2 Function(T value) output,
    void Function(Input2 value)? validate,
  }) {
    final size = _serializedSize;
    return BcsType<T2, Input2>(
      name: name ?? this.name,
      read: (reader) => output(read(reader)),
      write: (value, writer) => _write(input(value) as Input, writer),
      serializedSize:
          size == null ? null : (value) => size(input(value) as Input),
      validate: (value) {
        validate?.call(value);
        _validate?.call(input(value) as Input);
      },
    );
  }
}

/// The result of serializing a value: raw bytes plus the schema that produced
/// them, convertible to common string encodings.
class SerializedBcs<T, Input> {
  final BcsType<T, Input> _schema;
  final Uint8List _bytes;

  SerializedBcs(this._schema, this._bytes);

  /// The raw BCS bytes.
  Uint8List toBytes() => _bytes;

  /// The BCS bytes encoded as a hexadecimal string.
  String toHex() => hexEncode(_bytes);

  /// The BCS bytes encoded as a base64 string.
  String toBase64() => base64Encode(_bytes);

  /// The BCS bytes encoded as a base58 string.
  String toBase58() => base58Encode(_bytes);

  /// Deserializes the bytes back into a value using the original schema.
  T parse() => _schema.parse(_bytes);
}
