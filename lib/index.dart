
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bcs/bcs_type.dart';
import 'package:bcs/uleb.dart';

class bcs {
	/// Creates a BcsType that can be used to read and write an 8-bit unsigned integer.
	/// ```dart
	/// bcs.u8().serialize(255).toBytes() // Uint8List [ 255 ]
  /// ```
	static BcsType<int, int> u8([BcsTypeOptions<int, int>? options]) {
		return uIntBcsType(
			name: 'u8',
			readMethod: 'read8',
			writeMethod: 'write8',
			size: 1,
			maxValue: (pow(2, 8) - 1).toInt(),
			validate: options?.validate,
		);
	}

	/// Creates a BcsType that can be used to read and write a 16-bit unsigned integer.
	/// ```dart
	/// bcs.u16().serialize(65535).toBytes() // Uint8List [ 255, 255 ]
  /// ```
	static BcsType<int, int> u16([BcsTypeOptions<int, int>? options]) {
		return uIntBcsType(
			name: 'u16',
			readMethod: 'read16',
			writeMethod: 'write16',
			size: 2,
      maxValue: (pow(2, 16) - 1).toInt(),
			validate: options?.validate,
		);
	}

	/// Creates a BcsType that can be used to read and write a 32-bit unsigned integer.
	/// ```dart
	/// bcs.u32().serialize(4294967295).toBytes() // Uint8List [ 255, 255, 255, 255 ]
  /// ```
	static BcsType<int, int> u32([BcsTypeOptions<int, int>? options]) {
		return uIntBcsType(
			name: 'u32',
			readMethod: 'read32',
			writeMethod: 'write32',
			size: 4,
			maxValue: (pow(2, 32) - 1).toInt(),
			validate: options?.validate,
		);
	}

	/// Creates a BcsType that can be used to read and write a 64-bit unsigned integer.
	/// ```dart
	/// bcs.u64().serialize(BigInt.one).toBytes() // Uint8List [ 1, 0, 0, 0, 0, 0, 0, 0 ]
  /// ```
	static BcsType<String, BigInt> u64([BcsTypeOptions<String, BigInt>? options]) {
		return bigUIntBcsType(
			name: 'u64',
			readMethod: 'read64',
			writeMethod: 'write64',
			size: 8,
      maxValue: BigInt.from(2).pow(64) - BigInt.one,
			validate: options?.validate
		);
	}

	/// Creates a BcsType that can be used to read and write a 128-bit unsigned integer.
	/// ```dart
	/// bcs.u128().serialize(BigInt.one).toBytes() // Uint8List [ 1, ..., 0 ]
  /// ```
	static BcsType<String, BigInt> u128([BcsTypeOptions<String, BigInt>? options]) {
		return bigUIntBcsType(
			name: 'u128',
			readMethod: 'read128',
			writeMethod: 'write128',
			size: 16,
      maxValue: BigInt.from(2).pow(128) - BigInt.one,
			validate: options?.validate
		);
	}

	/// Creates a BcsType that can be used to read and write a 256-bit unsigned integer.
	/// ```dart
	/// bcs.u256().serialize(BigInt.one).toBytes() // Uint8List [ 1, ..., 0 ]
  /// ```
	static BcsType<String, BigInt> u256([BcsTypeOptions<String, BigInt>? options]) {
		return bigUIntBcsType(
			name: 'u256',
			readMethod: 'read256',
			writeMethod: 'write256',
			size: 32,
      maxValue: BigInt.from(2).pow(256) - BigInt.one,
			validate: options?.validate
		);
	}

	/// Creates a BcsType that can be used to read and write boolean values.
	/// ```dart
	/// bcs.boolType().serialize(true).toBytes() // Uint8List [ 1 ]
  /// ```
	static BcsType<bool, bool> boolType([BcsTypeOptions<bool, bool>? options]) {
		return fixedSizeBcsType<bool, bool>(
			name: 'bool',
			size: 1,
			read: (reader) => reader.read8() == 1,
			write: (value, writer) => writer.write8(value == true ? 1 : 0),
			validate: (value) {
				options?.validate?.call(value);
				if (value is! bool) {
					throw ArgumentError("Expected boolean, found ${value.runtimeType}");
				}
			},
		);
	}

	/// Creates a BcsType that can be used to read and write unsigned LEB encoded integers
	/// ```dart
	/// bcs.uleb128().serialize(1).toBytes()  // Uint8List [ 1 ]
  /// ```
	static BcsType<int, int> uleb128([BcsTypeOptions<int, int>? options]) {
		return dynamicSizeBcsType<int, int>(
			name: 'uleb128',
			read: (reader) => reader.readULEB(),
			serialize: (value, [_]) {
				return Uint8List.fromList(ulebEncode(value));
			},
			validate: options?.validate
		);
	}

	/// Creates a BcsType representing a fixed length byte array.
	/// The number of bytes this types represents [size]
	/// ```dart
	/// bcs.bytes(3).serialize(Uint8List.fromList([1, 2, 3]) // Uint8List [1, 2, 3]
  /// ```
	static BcsType<Uint8List, Uint8List> bytes(int size, [BcsTypeOptions<Uint8List, Uint8List>? options]) {
		return fixedSizeBcsType<Uint8List, Uint8List>(
			name: "bytes[$size]",
			size: size,
			read: (reader) => reader.readBytes(size),
			write: (value, writer) {
				for (int i = 0; i < size; i++) {
					writer.write8(value[i] ?? 0);
				}
			},
			validate: (value) {
				options?.validate?.call(value);
				if (value is! Iterable) {
					throw ArgumentError("Expected array, found ${value.runtimeType}");
				}
				if (value.length != size) {
					throw ArgumentError("Expected array of length $size, found ${value.length}");
				}
			},
		);
	}

	/// Creates a BcsType that can ser/de string values. Strings will be UTF-8 encoded
	/// ```dart
	/// bcs.string().serialize('a').toBytes() // Uint8List [ 1, 97 ]
  /// ```
	static BcsType<String, String> string([BcsTypeOptions<String, String>? options]) {
		return stringLikeBcsType<String, String>(
			name: 'string',
			toBytes: (value) => Uint8List.fromList(utf8.encode(value)),
			fromBytes: (bytes) => utf8.decode(bytes),
			validate: options?.validate
		);
	}

	/// Creates a BcsType that represents a fixed length array of a given type.
	/// The [size] is number of elements in the array.
	/// The [type] is BcsType of each element in the array.
	/// ```dart
	/// bcs.fixedArray(3, bcs.u8()).serialize([1, 2, 3]).toBytes() // Uint8List [ 1, 2, 3 ]
  /// ```
	static BcsType<List<T>, List<Input>> fixedArray<T, Input>(
		int size,
		BcsType<T, Input> type,
		[BcsTypeOptions<List<T>, List<Input>>? options]
	) {
		return BcsType<List<T>, List<Input>>(
			name: "${type.name}[$size]",
			read: (reader) {
				final result = <T>[];
				for (int i = 0; i < size; i++) {
          result.add(type.read(reader));
				}
				return result;
			},
			write: (value, writer) {
				for (var item in value) {
					type.write(item, writer);
				}
			},
			validate: (value) {
				options?.validate?.call(value);
				if (value is! Iterable) {
					throw ArgumentError("Expected array, found ${value.runtimeType}");
				}
				if (value.length != size) {
					throw ArgumentError("Expected array of length ${size}, found ${value.length}");
				}
			},
		);
	}

	/// Creates a BcsType representing an optional value.
	/// The [type] is BcsType of the optional value.
	/// ```dart
	/// bcs.option(bcs.u8()).serialize(null).toBytes() // Uint8List [ 0 ]
	/// bcs.option(bcs.u8()).serialize(1).toBytes() // Uint8List [ 1, 1 ]
  /// ```
	static BcsType<T?, Input?> option<T, Input>(BcsType<T?, Input?> type) {
		return enumType("Option<${type.name}>", {
				"None": null,
				"Some": type,
			})
			.transform(
				input: (value) {
					if (value == null) {
						return { "None": true };
					}

					return { "Some": value };
				},
				output: (value) {
					if (value["Some"] != null) {
						return value["Some"];
					}

					return null;
				},
			);
	}

	/// Creates a BcsType representing a variable length vector of a given type.
	/// The [type] is BcsType of each element in the vector.
	/// ```dart
	/// bcs.vector(bcs.u8()).toBytes([1, 2, 3]) // Uint8List [ 3, 1, 2, 3 ]
  /// ```
	static BcsType<List<T>, List<Input>> vector<T, Input>(
		BcsType<T, Input> type,
		[BcsTypeOptions<List<T>, List<Input>>? options]
	) {
		return BcsType<List<T>, List<Input>>(
			name: "vector<${type.name}>",
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
				for (var item in value) {
					type.write(item, writer);
				}
			},
			validate: (value) {
				options?.validate?.call(value);
				if (value is! Iterable) {
					throw ArgumentError("Expected array, found ${value.runtimeType}");
				}
			}
		);
	}

	/// Creates a BcsType representing a tuple of a given set of types.
	/// The [types] is BcsTypes for each element in the tuple
	/// ```dart
	/// final tuple = bcs.tuple([bcs.u8(), bcs.string(), bcs.boolType()])
	/// tuple.serialize([1, 'a', true]).toBytes() // Uint8List [ 1, 1, 97, 1 ]
  /// ```
	static BcsType tuple(
		List<BcsType> types,
    [BcsTypeOptions? options]
	) {
		return BcsType(
			name: "(${types.map((t) => t.name).join(', ')})",
			serializedSize: (values, [_]) {
				int total = 0;
				for (int i = 0; i < types.length; i++) {
          final value = values[i];
          final type = types[i];
          int? size;
          if (type is BcsType<int, int>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<String, BigInt>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<String, String>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<bool, bool>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<Uint8List, Uint8List>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<List<int>, List<int>>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<List<dynamic>, List<dynamic>>) {
            size = type.serializedSize(value);
          } else {
					  size = type.serializedSize(value);
          }

					if (size == null) {
						return null;
					}

					total += size;
				}

				return total;
			},
			read: (reader) {
				final result = <dynamic>[];
				for (var type in types) {
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
				if (value is! Iterable) {
					throw ArgumentError("Expected array, found ${value.runtimeType}");
				}
				if (value.length != types.length) {
					throw ArgumentError("Expected array of length ${types.length}, found ${value.length}");
				}
			},
		);
	}

	/// Creates a BcsType representing a struct of a given set of fields.
	/// The [name] of the struct.
	/// The [fields] of the struct. The order of the fields affects how data is serialized and deserialized
	/// ```dart
	/// final struct = bcs.struct('MyStruct', {
	///   "a": bcs.u8(),
	///   "b": bcs.string(),
	/// })
	/// struct.serialize({ "a": 1, "b": 'a' }).toBytes() // Uint8List [ 1, 1, 97 ]
  /// ```
	static BcsType<dynamic, dynamic> struct<T extends Map<String, BcsType<dynamic, dynamic>?>>(
		String name,
		T fields,
    [BcsTypeOptions<dynamic, dynamic>? options]
	) {
    final canonicalOrder = fields.entries.toList();

		return BcsType<dynamic, dynamic>(
			name: name,
			serializedSize: (values, [_]) {
				int total = 0;
				for (var entry in canonicalOrder) {
          final field = entry.key;
          final type = entry.value;
          final value = values[field];
          int? size;
          if (type is BcsType<int, int>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<String, BigInt>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<String, String>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<bool, bool>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<Uint8List, Uint8List>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<List<int>, List<int>>) {
            size = type.serializedSize(value);
          } else if (type is BcsType<List<dynamic>, List<dynamic>>) {
            size = type.serializedSize(value);
          } else {
					  size = type?.serializedSize(values[field]);
          }

					if (size == null) {
						return null;
					}

					total += size;
				}

				return total;
			},
			read: (reader) {
				final result = {};
        for (var entry in canonicalOrder) {
          final field = entry.key;
          final type = entry.value;
					result[field] = type?.read(reader);
				}

				return result;
			},
			write: (value, writer) {
				for (var entry in canonicalOrder) {
          final field = entry.key;
          final type = entry.value;
					type?.write(value[field], writer);
				}
			},
			validate: (value) {
				options?.validate?.call(value);
				if (value == null) {
					throw ArgumentError("Expected object, found ${value.runtimeType}");
				}
			},
		);
	}

	/// Creates a BcsType representing an enum of a given set of options.
	/// The [name] of the enum.
	/// The [values] of the enum. The order of the values affects how data is serialized and deserialized.
	/// null can be used to represent a variant with no data.
	/// ```dart
	/// final enumType = bcs.enumType('MyEnum', {
	///  "A": bcs.u8(),
	///  "B": bcs.string(),
	///  "C": null,
	/// });
	/// enumType.serialize({ "A": 1 }).toBytes() // Uint8List [ 0, 1 ]
	/// enumType.serialize({ "B": 'a' }).toBytes() // Uint8List [ 1, 1, 97 ]
	/// enumType.serialize({ "C": true }).toBytes() // Uint8List [ 2 ]
  /// ```
	static BcsType<Map, Map> enumType<T extends Map<String, BcsType<dynamic, dynamic>?>>(
		String name,
		T values,
		[BcsTypeOptions<dynamic, dynamic>? options]
	) {
    final canonicalOrder = values.entries.toList();
		return BcsType<Map, Map>(
			name: name,
			read: (reader) {
				final index = reader.readULEB();
				final entry = canonicalOrder[index];
        final name = entry.key;
        final type = entry.value;
				return {
					name: type?.read(reader) ?? true,
				};
			},
			write: (value, writer) {
        final entry = value.entries.toList()[0];
        final name = entry.key;
        final val = entry.value;
				for (int i = 0; i < canonicalOrder.length; i++) {
					final entry = canonicalOrder[i];
          final optionName = entry.key;
          final optionType = entry.value;
					if (optionName == name) {
						writer.writeULEB(i);
						optionType?.write(val, writer);
						return;
					}
				}
			},
			validate: (value) {
				options?.validate?.call(value);
				if (value == null || value is! Map) {
					throw ArgumentError("Expected object, found ${value.runtimeType}");
				}

				final keys = value.keys.toList();
				if (keys.length != 1) {
					throw ArgumentError("Expected object with one key, found ${keys.length}");
				}

				final name = keys[0];
				if (!values.keys.contains(name)) {
					throw ArgumentError("Invalid enum variant $name");
				}
			},
		);
	}

	/// Creates a BcsType representing a map of a given key and value type.
	/// The [keyType] of the BcsType.
	/// The [valueType] of the BcsType.
	/// ```dart
	/// final map = bcs.map(bcs.u8(), bcs.string())
	/// map.serialize({2: 'a'}).toBytes() // Uint8List [ 1, 2, 1, 97 ]
  /// ```
	static BcsType<Map, Map> map<K, V, InputK, InputV>(BcsType<K, InputK> keyType, BcsType<V, InputV> valueType) {
		return bcs.vector(bcs.tuple([keyType, valueType])).transform(
			name: "Map<${keyType.name}, ${valueType.name}>",
			input: (value) {
        final list = [];
        for (var entry in value.entries) {
          list.add([entry.key, entry.value]);
        }
        return list;
			},
			output: (value) {
				final result = <K, V>{};
				for (var entry in value) {
					result.addAll({entry[0]: entry[1]});
				}
				return result;
			},
		);
	}

	/// Creates a helper function representing a generic type. This method returns
	/// a function that can be used to create concrete version of the generic type.
	/// The [names] of the generic parameters.
	/// A [cb] callback that returns the generic type.
	/// ```dart
	/// final MyStruct = bcs.generic(['T'], (List<BcsType> T) => bcs.struct('MyStruct', { "inner": T[0] }))
	/// MyStruct([bcs.u8()]).serialize({ "inner": 1 }).toBytes() // Uint8List [ 1 ]
	/// MyStruct([bcs.string()]).serialize({ "inner": 'a' }).toBytes() // Uint8List [ 1, 97 ]
  /// ```
	static BcsType Function(T) generic<T extends List<BcsType>>(
		List<String> names,
		BcsType Function(T) cb
	) {
		return (T types) {
			return cb(types).transform(
				name: "${cb/*.name*/}<${types.map((t) => t.name).join(', ')}>",
				input: (value) => value,
				output: (value) => value,
			);
		};
	}

	/// Creates a BcsType that wraps another BcsType which is lazily evaluated. This is useful for creating recursive types.
	/// A [cb] callback that returns the BcsType.
	T lazy<T extends BcsType<dynamic, dynamic>>(T Function() cb){
		return lazyBcsType(cb) as T;
	}
}
