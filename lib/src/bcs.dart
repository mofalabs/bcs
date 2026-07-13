import 'dart:convert';
import 'dart:typed_data';

import 'bcs_type.dart';
import 'reader.dart';
import 'writer.dart';

final BigInt _maxU64 = (BigInt.one << 64) - BigInt.one;
final BigInt _maxU128 = (BigInt.one << 128) - BigInt.one;
final BigInt _maxU256 = (BigInt.one << 256) - BigInt.one;

/// Factories for building BCS schemas.
///
/// Primitive schemas (`u8`, `string`, `boolean`, ...) are combined into
/// complex ones (`struct`, `vector`, `enumeration`, ...) that can serialize
/// and deserialize BCS bytes:
///
/// ```dart
/// final coin = Bcs.struct('Coin', {
///   'value': Bcs.u64(),
///   'owner': Bcs.string(),
/// });
///
/// final bytes = coin.serialize({'value': 1000000, 'owner': 'Alice'}).toBytes();
/// final decoded = coin.parse(bytes);
/// ```
abstract final class Bcs {
  /// An unsigned 8-bit integer.
  static BcsType<int, int> u8([BcsTypeOptions<int, int>? options]) =>
      _uint('u8', 1, 0xff, (r) => r.read8(), (w, v) => w.write8(v), options);

  /// An unsigned 16-bit integer, little-endian.
  static BcsType<int, int> u16([BcsTypeOptions<int, int>? options]) => _uint(
      'u16', 2, 0xffff, (r) => r.read16(), (w, v) => w.write16(v), options);

  /// An unsigned 32-bit integer, little-endian.
  static BcsType<int, int> u32([BcsTypeOptions<int, int>? options]) => _uint(
      'u32', 4, 0xffffffff, (r) => r.read32(), (w, v) => w.write32(v), options);

  /// An unsigned 64-bit integer, little-endian.
  ///
  /// Reads as [BigInt]; accepts [int], [BigInt] or a decimal [String] as input.
  static BcsType<BigInt, Object> u64(
          [BcsTypeOptions<BigInt, BigInt>? options]) =>
      _bigUint('u64', 8, _maxU64, (r) => r.read64(), (w, v) => w.write64(v),
          options);

  /// An unsigned 128-bit integer, little-endian.
  ///
  /// Reads as [BigInt]; accepts [int], [BigInt] or a decimal [String] as input.
  static BcsType<BigInt, Object> u128(
          [BcsTypeOptions<BigInt, BigInt>? options]) =>
      _bigUint('u128', 16, _maxU128, (r) => r.read128(),
          (w, v) => w.write128(v), options);

  /// An unsigned 256-bit integer, little-endian.
  ///
  /// Reads as [BigInt]; accepts [int], [BigInt] or a decimal [String] as input.
  static BcsType<BigInt, Object> u256(
          [BcsTypeOptions<BigInt, BigInt>? options]) =>
      _bigUint('u256', 32, _maxU256, (r) => r.read256(),
          (w, v) => w.write256(v), options);

  /// A boolean, encoded as a single byte that must be `0` or `1`.
  static BcsType<bool, bool> boolean([BcsTypeOptions<bool, bool>? options]) {
    return BcsType<bool, bool>(
      name: 'bool',
      serializedSize: (_) => 1,
      read: (reader) {
        final byte = reader.read8();
        if (byte > 1) {
          throw FormatException('Invalid boolean byte $byte, expected 0 or 1');
        }
        return byte == 1;
      },
      write: (value, writer) => writer.write8(value ? 1 : 0),
      validate: options?.validate,
    );
  }

  /// A ULEB128-encoded unsigned integer.
  static BcsType<int, int> uleb128([BcsTypeOptions<int, int>? options]) {
    return BcsType<int, int>(
      name: 'uleb128',
      read: (reader) => reader.readULEB(),
      write: (value, writer) => writer.writeULEB(value),
      validate: (value) {
        // Matches the decoder, which caps ULEB128 values at u32 per BCS.
        if (value < 0 || value > 0xffffffff) {
          throw ArgumentError.value(
              value, 'value', 'Expected uleb128 value in range 0-0xffffffff');
        }
        options?.validate?.call(value);
      },
    );
  }

  /// A fixed-length byte sequence of exactly [size] bytes (no length prefix).
  static BcsType<Uint8List, List<int>> bytes(int size,
      [BcsTypeOptions<Uint8List, List<int>>? options]) {
    return BcsType<Uint8List, List<int>>(
      name: 'bytes[$size]',
      serializedSize: (_) => size,
      read: (reader) => reader.readBytes(size),
      write: (value, writer) => writer
          .writeBytes(value is Uint8List ? value : Uint8List.fromList(value)),
      validate: (value) {
        if (value.length != size) {
          throw ArgumentError.value(
              value, 'value', 'Expected $size byte(s), found ${value.length}');
        }
        // Uint8List.fromList silently truncates to 8 bits; reject
        // out-of-range elements instead. A Uint8List can't be out of range.
        if (value is! Uint8List) {
          for (final byte in value) {
            if (byte < 0 || byte > 0xff) {
              throw ArgumentError.value(value, 'value',
                  'Invalid byte $byte, expected a value in range 0-255');
            }
          }
        }
        options?.validate?.call(value);
      },
    );
  }

  /// A UTF-8 string, prefixed with its byte length as ULEB128.
  static BcsType<String, String> string(
      [BcsTypeOptions<String, String>? options]) {
    return BcsType<String, String>(
      name: 'string',
      read: (reader) {
        final length = reader.readULEB();
        return utf8.decode(reader.readBytes(length));
      },
      write: (value, writer) {
        final bytes = utf8.encode(value);
        writer
          ..writeULEB(bytes.length)
          ..writeBytes(bytes);
      },
      validate: options?.validate,
    );
  }

  /// A fixed-length array of exactly [size] elements (no length prefix).
  ///
  /// The input side is deliberately loose (`Iterable<dynamic>`) so that
  /// dynamically-built lists can be serialized; elements are checked against
  /// the element type at write time.
  static BcsType<List<T>, Iterable<dynamic>> fixedArray<T, Input>(
      int size, BcsType<T, Input> type,
      [BcsTypeOptions<List<T>, Iterable<dynamic>>? options]) {
    return BcsType<List<T>, Iterable<dynamic>>(
      name: '${type.name}[$size]',
      read: (reader) => List<T>.generate(size, (_) => type.read(reader)),
      write: (value, writer) {
        for (final item in value) {
          type.write(item as Input, writer);
        }
      },
      validate: (value) {
        if (value.length != size) {
          throw ArgumentError.value(value, 'value',
              'Expected $size element(s), found ${value.length}');
        }
        options?.validate?.call(value);
      },
    );
  }

  /// A Move/Rust `Option<T>`: `null` maps to `None`, any other value to
  /// `Some`.
  static BcsType<T?, Input?> option<T, Input>(BcsType<T, Input> type) {
    return enumeration('Option<${type.name}>', {
      'None': null,
      'Some': type,
    }).transform(
      input: (Input? value) =>
          value == null ? const {'None': true} : {'Some': value},
      output: (value) => value.containsKey('Some') ? value['Some'] as T : null,
    );
  }

  /// A variable-length list, prefixed with its element count as ULEB128.
  ///
  /// The input side is deliberately loose (`Iterable<dynamic>`) so that
  /// dynamically-built lists can be serialized; elements are checked against
  /// the element type at write time.
  static BcsType<List<T>, Iterable<dynamic>> vector<T, Input>(
      BcsType<T, Input> type,
      [BcsTypeOptions<List<T>, Iterable<dynamic>>? options]) {
    return BcsType<List<T>, Iterable<dynamic>>(
      name: 'vector<${type.name}>',
      read: (reader) {
        final length = reader.readULEB();
        // Every element takes at least one byte, so a length beyond the
        // remaining input is malformed; reject it before allocating.
        if (length > reader.remaining) {
          throw FormatException(
              'Vector length $length exceeds the ${reader.remaining} '
              'remaining byte(s) of input');
        }
        return List<T>.generate(length, (_) => type.read(reader));
      },
      write: (value, writer) {
        writer.writeULEB(value.length);
        for (final item in value) {
          type.write(item as Input, writer);
        }
      },
      validate: options?.validate,
    );
  }

  /// A heterogeneous fixed-size sequence, serialized as the concatenation of
  /// its elements.
  static BcsType<List<dynamic>, List<dynamic>> tuple(
      List<BcsType<dynamic, dynamic>> types,
      [BcsTypeOptions<List<dynamic>, List<dynamic>>? options]) {
    return BcsType<List<dynamic>, List<dynamic>>(
      name: '(${types.map((t) => t.name).join(', ')})',
      serializedSize: (values) => _totalSize(types, values),
      read: (reader) => [for (final type in types) type.read(reader)],
      write: (value, writer) {
        for (var i = 0; i < types.length; i++) {
          types[i].write(value[i], writer);
        }
      },
      validate: (value) {
        if (value.length != types.length) {
          throw ArgumentError.value(value, 'value',
              'Expected ${types.length} element(s), found ${value.length}');
        }
        options?.validate?.call(value);
      },
    );
  }

  /// A struct with named [fields], serialized as the concatenation of the
  /// field values in declaration order.
  ///
  /// Reads `Map<String, dynamic>` keyed by field name. Accepts any [Map] as
  /// input; a non-map input must expose a `toJson()` method returning a map.
  /// Use [BcsType.transform] to map a struct to a data class.
  static BcsType<Map<String, dynamic>, dynamic> struct(
      String name, Map<String, BcsType<dynamic, dynamic>> fields,
      [BcsTypeOptions<Map<String, dynamic>, dynamic>? options]) {
    final orderedFields = fields.entries.toList();

    return BcsType<Map<String, dynamic>, dynamic>(
      name: name,
      serializedSize: (value) {
        final values = _asMap(name, value);
        return _totalSize([
          for (final f in orderedFields) f.value
        ], [
          for (final f in orderedFields) values[f.key],
        ]);
      },
      read: (reader) => {
        for (final field in orderedFields) field.key: field.value.read(reader),
      },
      write: (value, writer) {
        final values = _asMap(name, value);
        for (final field in orderedFields) {
          field.value.write(values[field.key], writer);
        }
      },
      validate: options?.validate,
    );
  }

  /// An enum with the given [variants], serialized as the ULEB128 variant
  /// index followed by the variant value (if any). Variants without a
  /// payload use a `null` type.
  ///
  /// Values are maps with a single entry, `{variantName: payload}` (payload
  /// `true` for empty variants); reading also adds a `$kind` entry holding
  /// the variant name. Accepts any [Map] as input; a non-map input must
  /// expose a `toJson()` method returning a map.
  static BcsType<Map<String, dynamic>, dynamic> enumeration(
      String name, Map<String, BcsType<dynamic, dynamic>?> variants,
      [BcsTypeOptions<Map<String, dynamic>, dynamic>? options]) {
    final orderedVariants = variants.entries.toList();

    return BcsType<Map<String, dynamic>, dynamic>(
      name: name,
      read: (reader) {
        final index = reader.readULEB();
        if (index >= orderedVariants.length) {
          throw FormatException('Unknown variant index $index for enum $name');
        }
        final variant = orderedVariants[index];
        return {
          variant.key: variant.value?.read(reader) ?? true,
          r'$kind': variant.key,
        };
      },
      write: (value, writer) {
        final values = _asMap(name, value);
        final index = orderedVariants.indexWhere((variant) =>
            variant.key != r'$kind' && values.containsKey(variant.key));
        if (index == -1) {
          throw ArgumentError.value(
              value, 'value', 'No variant of enum $name found in value');
        }
        final variant = orderedVariants[index];
        writer.writeULEB(index);
        variant.value?.write(values[variant.key], writer);
      },
      validate: (value) {
        final values = _asMap(name, value);
        final keys = values.keys
            .where((k) => k != r'$kind' && variants.containsKey(k))
            .toList();
        if (keys.length != 1) {
          throw ArgumentError.value(value, 'value',
              'Expected a map with exactly one variant of enum $name, found ${keys.length}');
        }
        options?.validate?.call(value);
      },
    );
  }

  /// A map, serialized as a vector of key/value tuples.
  static BcsType<Map<K, V>, Map<InputK, InputV>> map<K, V, InputK, InputV>(
      BcsType<K, InputK> keyType, BcsType<V, InputV> valueType) {
    return vector(tuple([keyType, valueType])).transform(
      name: 'Map<${keyType.name}, ${valueType.name}>',
      input: (Map<InputK, InputV> value) => [
        for (final entry in value.entries) [entry.key, entry.value]
      ],
      output: (value) =>
          {for (final entry in value) entry[0] as K: entry[1] as V},
    );
  }

  /// Defers schema construction until first use, enabling recursive types:
  ///
  /// ```dart
  /// late final BcsType<Map<String, dynamic>, dynamic> tree;
  /// tree = Bcs.struct('Tree', {
  ///   'value': Bcs.u8(),
  ///   'children': Bcs.vector(Bcs.lazy(() => tree)),
  /// });
  /// ```
  static BcsType<T, Input> lazy<T, Input>(BcsType<T, Input> Function() cb) {
    BcsType<T, Input>? cached;
    BcsType<T, Input> resolve() => cached ??= cb();

    return BcsType<T, Input>(
      name: 'lazy',
      read: (reader) => resolve().read(reader),
      write: (value, writer) => resolve().write(value, writer),
      serializedSize: (value) => resolve().serializedSizeOf(value),
      validate: (value) => resolve().validate(value),
    );
  }

  static BcsType<int, int> _uint(
    String name,
    int size,
    int max,
    int Function(BcsReader reader) read,
    void Function(BcsWriter writer, int value) write,
    BcsTypeOptions<int, int>? options,
  ) {
    return BcsType<int, int>(
      name: name,
      serializedSize: (_) => size,
      read: read,
      write: (value, writer) => write(writer, value),
      validate: (value) {
        if (value < 0 || value > max) {
          throw ArgumentError.value(value, 'value',
              'Invalid $name value, expected a value in range 0-$max');
        }
        options?.validate?.call(value);
      },
    );
  }

  static BcsType<BigInt, Object> _bigUint(
    String name,
    int size,
    BigInt max,
    BigInt Function(BcsReader reader) read,
    void Function(BcsWriter writer, BigInt value) write,
    BcsTypeOptions<BigInt, BigInt>? options,
  ) {
    return BcsType<BigInt, Object>(
      name: name,
      serializedSize: (_) => size,
      read: read,
      write: (value, writer) => write(writer, _toBigInt(name, value)),
      validate: (value) {
        final bigValue = _toBigInt(name, value);
        if (bigValue < BigInt.zero || bigValue > max) {
          throw ArgumentError.value(value, 'value',
              'Invalid $name value, expected a value in range 0-$max');
        }
        options?.validate?.call(bigValue);
      },
    );
  }

  static Map<dynamic, dynamic> _asMap(String name, dynamic value) {
    if (value is Map) {
      return value;
    }
    final dynamic json;
    try {
      json = (value as dynamic).toJson();
    } on NoSuchMethodError {
      throw ArgumentError.value(
          value, 'value', 'Expected a Map or an object with toJson() for $name');
    }
    if (json is Map) {
      return json;
    }
    throw ArgumentError.value(
        value, 'value', 'Expected toJson() to return a Map for $name');
  }

  static BigInt _toBigInt(String name, Object value) {
    return switch (value) {
      final BigInt v => v,
      final int v => BigInt.from(v),
      final String v => BigInt.parse(v),
      _ => throw ArgumentError.value(value, 'value',
          'Invalid $name value, expected int, BigInt or String'),
    };
  }

  static int? _totalSize(
      List<BcsType<dynamic, dynamic>> types, List<dynamic> values) {
    var total = 0;
    for (var i = 0; i < types.length; i++) {
      final size = types[i].serializedSizeOf(values[i]);
      if (size == null) {
        return null;
      }
      total += size;
    }
    return total;
  }
}
