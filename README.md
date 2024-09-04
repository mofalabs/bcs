## BCS - Binary Canonical Serialization

[![Pub](https://img.shields.io/badge/pub-v0.1.0-blue)](https://pub.dev/packages/bcs)

This library implements [Binary Canonical Serialization (BCS)](https://github.com/diem/bcs) in Dart.

## Quickstart

```dart
import 'package:bcs/bcs.dart';

// define UID as a 32-byte array, then add a transform to/from hex strings
final UID = Bcs.fixedArray(32, Bcs.u8()).transform(
  input: (id) => fromHEX(id.toString()),
  output: (id) => toHEX(Uint8List.fromList(id)),
);

final Coin = Bcs.struct('Coin', {
  "id": UID,
  "value": Bcs.u64(),
});

// deserialization: BCS bytes into Coin
final bcsBytes = Coin.serialize({
  "id": '0000000000000000000000000000000000000000000000000000000000000001',
  "value": BigInt.from(1000000),
}).toBytes();

final coin = Coin.parse(bcsBytes);

// serialization: Object into bytes - an Option with <T = Coin>
final hex = Bcs.option(Coin).serialize(coin).toHex();

print(hex);
```

## Description

BCS defines the way the data is serialized, and the serialized results contains no type information.
To be able to serialize the data and later deserialize it, a schema has to be created (based on the
built-in primitives, such as `string` or `u64`). There are no type hints in the serialized bytes on
what they mean, so the schema used for decoding must match the schema used to encode the data.

The `bcs` library can be used to define schemas that can serialize and deserialize BCS
encoded data.

## Basic types

bcs supports a number of built in base types that can be combined to create more complex types. The
following table lists the primitive types available:

| Method                | Dart Type      | Dart Input Type                | Description                                                                 |
| --------------------- | ------------ | ---------------------------- | --------------------------------------------------------------------------- |
| `bool`                | `bool`    | `bool`                    | Boolean type (converts to `true` / `false`)                                 |
| `u8`, `u16`, `u32`    | `int`     | `int`                     | Unsigned Integer types                                                      |
| `u64`, `u128`, `u256` | `BigInt`     | `BigInt` | Unsigned Integer types, decoded as `string` to allow for JSON serialization |
| `uleb128`             | `int`     | `int`                     | Unsigned LEB128 integer type                                                |
| `string`              | `String`     | `String`                     | UTF-8 encoded string                                                        |
| `bytes(size)`         | `Uint8List` | `Uint8List`           | Fixed length bytes                                                          |

```dart
import 'package:bcs/bcs.dart';

final u8 = Bcs.u8().serialize(100).toBytes();
final u64 = Bcs.u64().serialize(BigInt.from(1000000)).toBytes();
final u128 = Bcs.u128().serialize('100000010000001000000').toBytes();

final str = Bcs.string().serialize('this is an ascii string').toBytes();
final bytes = Bcs.bytes(4).serialize(Uint8List.fromList([1, 2, 3, 4])).toBytes();

final parsedU8 = Bcs.u8().parse(u8);
final parsedU64 = Bcs.u64().parse(u64);
final parsedU128 = Bcs.u128().parse(u128);

final parsedStr = Bcs.string().parse(str);
final parsedBytes = Bcs.bytes(4).parse(bytes);
```

## Compound types

For most use-cases you'll want to combine primitive types into more complex types like `vectors`,
`structs` and `enums`. The following table lists methods available for creating compound types:

| Method                 | Description                                           |
| ---------------------- | ----------------------------------------------------- |
| `vector(T type)`      | A variable length list of values of type `T`          |
| `fixedArray(size, T)`  | A fixed length array of values of type `T`            |
| `option(T type)`      | A value of type `T` or `null`                         |
| `enumeration(name, values)`   | An enum value representing one of the provided values |
| `struct(name, fields)` | A struct with named fields of the provided types      |
| `tuple(types)`         | A tuple of the provided types                         |
| `map(K, V)`            | A map of keys of type `K` to values of type `V`       |

```dart
import 'package:bcs/bcs.dart';

// Vectors
final intList = Bcs.vector(Bcs.u8()).serialize([1, 2, 3, 4, 5]).toBytes();
final stringList = Bcs.vector(Bcs.string()).serialize(['a', 'b', 'c']).toBytes();

// Arrays
final intArray = Bcs.fixedArray(4, Bcs.u8()).serialize([1, 2, 3, 4]).toBytes();
final stringArray = Bcs.fixedArray(3, Bcs.string()).serialize(['a', 'b', 'c']).toBytes();

// Option
final option = Bcs.option(Bcs.string()).serialize('some value').toBytes();
final nullOption = Bcs.option(Bcs.string()).serialize(null).toBytes();

// Enum
final MyEnum = Bcs.enumeration('MyEnum', {
	"NoType": null,
	"Int": Bcs.u8(),
	"String": Bcs.string(),
	"Array": Bcs.fixedArray(3, Bcs.u8()),
});

final noTypeEnum = MyEnum.serialize({ "NoType": null }).toBytes();
final intEnum = MyEnum.serialize({ "Int": 100 }).toBytes();
final stringEnum = MyEnum.serialize({ "String": 'string' }).toBytes();
final arrayEnum = MyEnum.serialize({ "Array": [1, 2, 3] }).toBytes();

// Struct
final MyStruct = Bcs.struct('MyStruct', {
	"id": Bcs.u8(),
	"name": Bcs.string(),
});

final struct = MyStruct.serialize({ "id": 1, "name": 'name' }).toBytes();

// Tuple
final tuple = Bcs.tuple([Bcs.u8(), Bcs.string()]).serialize([1, 'name']).toBytes();

// Map
final map = Bcs
	.map(Bcs.u8(), Bcs.string())
	.serialize(
		{
			1: 'one',
			2: 'two',
    }).toBytes();

// Parsing data back into original types

// Vectors
final parsedIntList = Bcs.vector(Bcs.u8()).parse(intList);
final parsedStringList = Bcs.vector(Bcs.string()).parse(stringList);

// Arrays
final parsedIntArray = Bcs.fixedArray(4, Bcs.u8()).parse(intArray);

// Option
final parsedOption = Bcs.option(Bcs.string()).parse(option);
final parsedNullOption = Bcs.option(Bcs.string()).parse(nullOption);

// Enum
final parsedNoTypeEnum = MyEnum.parse(noTypeEnum);
final parsedIntEnum = MyEnum.parse(intEnum);
final parsedStringEnum = MyEnum.parse(stringEnum);
final parsedArrayEnum = MyEnum.parse(arrayEnum);

// Struct
final parsedStruct = MyStruct.parse(struct);

// Tuple
final parsedTuple = Bcs.tuple([Bcs.u8(), Bcs.string()]).parse(tuple);

// Map
final parsedMap = Bcs.map(Bcs.u8(), Bcs.string()).parse(map);
```

## Generics

To define a generic struct or an enum, you can define a generic typescript function helper

```dart
import 'package:bcs/bcs.dart';
import 'package:bcs/bcs_type.dart';

// The T typescript generic is a placeholder for the typescript type of the generic value
// The T argument will be the bcs type passed in when creating a concrete instance of the Container type
BcsType Container<T>(BcsType<T, T> T) {
	return Bcs.struct('Container<T>', {
		"contents": T,
	});
}

// When serializing, we have to pass the type to use for `T`
final bytes = Container(Bcs.u8()).serialize({ "contents": 100 }).toBytes();

// Alternatively we can save the concrete type as a variable
// final U8Container = Container(Bcs.u8());
// final bytes = U8Container.serialize({ "contents": 100 }).toBytes();

// Using multiple generics
BcsType VecMap<K, V>(BcsType<K, K> K, BcsType<V, V> V) {
	// You can use the names of the generic params in the type name to
	return Bcs.struct(
		// You can use the names of the generic params to give your type a more useful name
		"VecMap<${K.name}, ${V.name}>",
		{
			"keys": Bcs.vector(K),
			"values": Bcs.vector(V),
		}
	);
}

// To serialize VecMap, we can use:
VecMap(Bcs.string(), Bcs.string())
	.serialize({
		"keys": ['key1', 'key2', 'key3'],
		"values": ['value1', 'value2', 'value3'],
	})
	.toBytes();
```

## Transforms

If you the format you use in your code is different from the format expected for BCS serialization,
you can use the `transform` API to map between the types you use in your application, and the types
needed for serialization.

The `address` type used by Move code is a good example of this. In many cases, you'll want to
represent an address as a hex string, but the BCS serialization format for addresses is a 32 byte
array. To handle this, you can use the `transform` API to map between the two formats:

```dart
final Address = Bcs.bytes(32).transform(
	input: (val) => fromHEX(val.toString()),
	output: (val) => toHEX(val),
);

final serialized = Address.serialize('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef').toBytes();
final parsed = Address.parse(serialized);
```

## Formats for serialized bytes

When you call `serialize` on a `BcsType`, you will receive a `SerializedBcs` instance. This wrapper
preserves type information for the serialized bytes, and can be used to get raw data in various
formats.

```dart
final serializedString = Bcs.string().serialize('this is a string');

// SerializedBcs.toBytes() returns a Uint8List
final bytes = serializedString.toBytes();

// You can get the serialized bytes encoded as hex, base64 or base58
final hex = serializedString.toHex();
final base64 = serializedString.toBase64();
final base58 = serializedString.toBase58();

// To parse a BCS value from bytes, the bytes need to be a Uint8List
final str1 = Bcs.string().parse(bytes);

// If your data is encoded as string, you need to convert it to Uint8List first
final str2 = Bcs.string().parse(fromHEX(hex));
final str3 = Bcs.string().parse(fromB64(base64));
final str4 = Bcs.string().parse(fromB58(base58));

expect((str1 == str2) == (str3 == str4), true);
```
