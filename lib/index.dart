import 'dart:convert';
import 'dart:typed_data';

import 'package:bcs/bcs_type.dart';
import 'package:bcs/uleb.dart';

class BcsWriterOptions {
  /// The initial size (in bytes) of the buffer tht will be allocated
  int? size;
  /// The maximum size (in bytes) that the buffer is allowed to grow to
  int? maxSize;
  /// The amount of bytes that will be allocated whenever additional memory is required
  int? allocateSize;

  BcsWriterOptions({this.size, this.maxSize, this.allocateSize});
}

class Bcs {
  static BcsType<int,dynamic> u8([BcsTypeOptions<int,int>? options]) {
    return uIntBcsType(
      name: 'u8',
      readMethod: 'read8',
      writeMethod: 'write8',
      size: 1,
      maxValue: 255,
      validate: options?.validate,
    );
  }

  static BcsType<int,dynamic> u16([BcsTypeOptions<int,int>? options]) {
    return uIntBcsType(
      name: 'u16',
      readMethod: 'read16',
      writeMethod: 'write16',
      size: 2,
      maxValue: 65535,
      validate: options?.validate,
    );
  }

  static BcsType<int,dynamic> u32([BcsTypeOptions<int,int>? options]) {
    return uIntBcsType(
      name: 'u32',
      readMethod: 'read32',
      writeMethod: 'write32',
      size: 4,
      maxValue: 4294967295,
      validate: options?.validate,
    );
  }

  static BcsType<BigInt,dynamic> u64([BcsTypeOptions<String, dynamic>? options]) {
    return bigUIntBcsType(
      name: 'u64',
      readMethod: 'read64',
      writeMethod: 'write64',
      size: 8,
      maxValue: BigInt.two.pow(64) - BigInt.one,
      validate: options?.validate,
    );
  }

  static BcsType<BigInt,dynamic> u128([BcsTypeOptions<String, dynamic>? options]) {
    return bigUIntBcsType(
      name: 'u128',
      readMethod: 'read128',
      writeMethod: 'write128',
      size: 16,
      maxValue: BigInt.two.pow(128) - BigInt.one,
      validate: options?.validate,
    );
  }

  static BcsType<BigInt,dynamic> u256([BcsTypeOptions<String, dynamic>? options]) {
    return bigUIntBcsType(
      name: 'u256',
      readMethod: 'read256',
      writeMethod: 'write256',
      size: 32,
      maxValue: BigInt.two.pow(256) - BigInt.one,
      validate: options?.validate,
    );
  }

  static BcsType<bool,dynamic> boolean([BcsTypeOptions<bool,bool>? options]) {
    return fixedSizeBcsType<bool,dynamic>(
      name: 'Bool',
      size: 1,
      read: (reader) => reader.read8() == 1,
      write: (value, writer) => writer.write8(value ? 1 : 0),
      validate: (value) {
        options?.validate?.call(value);
      },
    );
  }

  static BcsType<int,int> uleb128([BcsTypeOptions<int,int>? options]) {
    return dynamicSizeBcsType<int,int>(
      name: 'uleb128',
      read: (reader) => reader.readULEB(),
      serialize: (value, {BcsWriterOptions? options}) {
        return Uint8List.fromList(ulebEncode(value));
      },
      validate: options?.validate,
    );
  }

  static BcsType<Uint8List,Uint8List> bytes(int size, [BcsTypeOptions<Uint8List, Iterable<int>>? options]) {
    return fixedSizeBcsType<Uint8List,Uint8List>(
      name: 'bytes[$size]',
      size: size,
      read: (reader) => reader.readBytes(size),
      write: (value, writer) {
        for (int i = 0; i < size; i++) {
          writer.write8(value.elementAt(i));
        }
      },
      validate: (value) {
        options?.validate?.call(value);
        if (value.length != size) {
          throw ArgumentError('Expected Iterable of length $size, found ${value.length}');
        }
      },
    );
  }

  static BcsType<String,dynamic> string([BcsTypeOptions<String, String>? options]) {
    return stringLikeBcsType(
      name: 'string',
      toBytes: (value) => Uint8List.fromList(utf8.encode(value)),
      fromBytes: (bytes) => utf8.decode(bytes),
      validate: options?.validate,
    );
  }

  static BcsType<List<T>, Iterable<Input>> fixedArray<T, Input>(
    int size,
    BcsType<T, Input> type,
    [BcsTypeOptions<List<T>, Iterable<Input>>? options]
  ) {
    return BcsType<List<T>, Iterable<Input>>(
      name: '${type.name}[$size]',
      read: (reader) {
        final result = <T>[];
        for (int i = 0; i < size; i++) {
          result.add(type.read(reader));
        }
        return result;
      },
      write: (value, writer) {
        for (final item in value) {
          type.write(item, writer);
        }
      },
      validate: (value) {
        options?.validate?.call(value);
        if (value.length != size) {
          throw ArgumentError('Expected Iterable of length $size, found ${value.length}');
        }
      },
    );
  }

  static BcsType<T?, Input?> option<T, Input>(BcsType<T, Input> type) {
    return enumeration('Option<${type.name}>', {
      'None': null,
      'Some': type,
    }).transform(
      input: (Input? value) {
        if (value == null) {
          return {'None': true};
        }
        return {'Some': value};
      },
      output: (value) {
        if (value.containsKey('Some')) {
          return value['Some'] as T;
        }
        return null;
      },
    );
  }

  static BcsType<List<T>, dynamic> vector<T, Input>(
    BcsType<T, Input> type,
    [BcsTypeOptions<List<T>, Iterable<Input>>? options]
  ) {
    return BcsType<List<T>, dynamic>(
      name: 'vector<${type.name}>',
      read: (reader) {
        final length = reader.readULEB();
        final result = <T>[];
        for (int i = 0; i < length; i++) {
          result.add(type.read(reader));
        }
        return result;
      },
      write: (value, writer) {
        writer.writeULEB(value.length);
        for (final item in value) {
          type.write(item, writer);
        }
      },
      validate: (value) {
        options?.validate?.call(value);
      },
    );
  }

  static BcsType<List, List> tuple(
    List<BcsType> types,
    [BcsTypeOptions<List, List>? options]
  ) {
    return BcsType<List, List>(
      name: '(${types.map((t) => t.name).join(', ')})',
      serializedSize: (values, {BcsWriterOptions? options}) {
        int total = 0;
        for (int i = 0; i < types.length; i++) {
          final size = types[i].serializedSize(values[i]);
          if (size == null) {
            return null;
          }
          total += size;
        }
        return total;
      },
      read: (reader) {
        final result = [];
        for (final type in types) {
          result.add(type.read(reader));
        }
        return result;
      },
      write: (value, writer) {
        for (int i = 0; i < types.length; i++) {
          types[i].write(value[i], writer);
        }
      },
      validate: (value) {
        options?.validate?.call(value);
        if (value.length != types.length) {
          throw ArgumentError('Expected List of length ${types.length}, found ${value.length}');
        }
      },
    );
  }

  static BcsType<Map<String, dynamic>, Map<String, dynamic>> struct(
    String name,
    Map<String, BcsType> fields,
    [BcsTypeOptions<Map<String, dynamic>, Map<String, dynamic>>? options]
  ) {
    final canonicalOrder = fields.entries.toList();

    return BcsType<Map<String, dynamic>, Map<String, dynamic>>(
      name: name,
      serializedSize: (values, {BcsWriterOptions? options}) {
        int total = 0;
        for (final entry in canonicalOrder) {
          final size = entry.value.serializedSize(values[entry.key]);
          if (size == null) {
            return null;
          }
          total += size;
        }
        return total;
      },
      read: (reader) {
        final result = <String, dynamic>{};
        for (final entry in canonicalOrder) {
          result[entry.key] = entry.value.read(reader);
        }
        return result;
      },
      write: (value, writer) {
        for (final entry in canonicalOrder) {
          entry.value.write(value[entry.key], writer);
        }
      },
      validate: (value) {
        options?.validate?.call(value);
      },
    );
  }

  static BcsType<Map<String, dynamic>, dynamic> enumeration(
    String name,
    Map<String, BcsType?> values,
    [BcsTypeOptions<Map<String, dynamic>, Map<String, dynamic>>? options]
  ) {
    final canonicalOrder = values.entries.toList();

    return BcsType<Map<String, dynamic>, dynamic>(
      name: name,
      read: (reader) {
        final index = reader.readULEB();
        final entry = canonicalOrder[index];
        final value = entry.value?.read(reader) ?? true;
        return {
          entry.key: value,
          '\$kind': entry.key,
        };
      },
      write: (value, writer) {
        final entry = value.entries.firstWhere(
          (entry) => values.containsKey(entry.key) && entry.key != '\$kind',
        );
        final index = canonicalOrder.indexWhere((e) => e.key == entry.key);
        writer.writeULEB(index);
        canonicalOrder[index].value?.write(entry.value, writer);
      },
      validate: (value) {
        options?.validate?.call(value);
        final keys = value.keys.where((k) => k != '\$kind' && values.containsKey(k)).toList();
        if (keys.length != 1) {
          throw ArgumentError('Expected object with one key, but found ${keys.length} for type $name');
        }
        if (!values.containsKey(keys[0])) {
          throw ArgumentError('Invalid enum variant ${keys[0]}');
        }
      },
    );
  }

  static BcsType<Map<K, V>, Map<InputK, InputV>> map<K, V, InputK, InputV>(
    BcsType<K, InputK> keyType,
    BcsType<V, InputV> valueType
  ) {
    return Bcs.vector(Bcs.tuple([keyType, valueType])).transform(
      name: 'Map<${keyType.name}, ${valueType.name}>',
      input: (Map<InputK, InputV> value) {
        return value.entries.map((e) => [e.key, e.value]).toList();
      },
      output: (List<List> value) {
        return Map.fromEntries(
          value.map((e) => MapEntry(e[0] as K, e[1] as V))
        );
      },
    );
  }

  static BcsType<T, Input> lazy<T, Input>(BcsType<T, Input> Function() cb) {
    return lazyBcsType(cb);
  }

}