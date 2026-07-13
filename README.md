# BCS - Binary Canonical Serialization

[![Pub](https://img.shields.io/badge/pub-v0.2.0-blue)](https://pub.dev/packages/bcs)

This library implements [Binary Canonical Serialization (BCS)](https://github.com/diem/bcs) in Dart.

## Quickstart

```dart
import 'dart:typed_data';

import 'package:bcs/bcs.dart';

// define UID as a 32-byte array, then add a transform to/from hex strings
final uid = Bcs.fixedArray(32, Bcs.u8()).transform(
  input: (String id) => hexDecode(id),
  output: (id) => hexEncode(Uint8List.fromList(id)),
);

final coin = Bcs.struct('Coin', {
  'id': uid,
  'value': Bcs.u64(),
});

// serialization: a Map into BCS bytes
final bytes = coin.serialize({
  'id': '0000000000000000000000000000000000000000000000000000000000000001',
  'value': 1000000,
}).toBytes();

// deserialization: BCS bytes into a Map
final parsed = coin.parse(bytes);

// an Option with <T = Coin>, encoded as hex
final hex = Bcs.option(coin).serialize(parsed).toHex();
```

## Description

BCS defines the way the data is serialized, and the serialized results contain no type
information. To be able to serialize the data and later deserialize it, a schema has to be created
(based on the built-in primitives, such as `string` or `u64`). There are no type hints in the
serialized bytes on what they mean, so the schema used for decoding must match the schema used to
encode the data.

The `bcs` library can be used to define schemas that can serialize and deserialize BCS
encoded data.

## Basic types

`Bcs` exposes factories for all BCS primitives, which can be combined into more complex schemas:

| Factory               | Reads as    | Accepts as input            | Description                              |
| --------------------- | ----------- | --------------------------- | ---------------------------------------- |
| `Bcs.boolean()`       | `bool`      | `bool`                      | Single byte, `0` or `1`                  |
| `Bcs.u8/u16/u32()`    | `int`       | `int`                       | Unsigned integers, little-endian         |
| `Bcs.u64/u128/u256()` | `BigInt`    | `int`, `BigInt` or `String` | Big unsigned integers, little-endian     |
| `Bcs.uleb128()`       | `int`       | `int`                       | ULEB128-encoded unsigned integer         |
| `Bcs.string()`        | `String`    | `String`                    | UTF-8 string with ULEB128 length prefix  |
| `Bcs.bytes(n)`        | `Uint8List` | `List<int>`                 | Fixed-length raw bytes, no length prefix |

```dart
import 'package:bcs/bcs.dart';

final u8 = Bcs.u8().serialize(100).toBytes();
final u64 = Bcs.u64().serialize(1000000).toBytes(); // int, BigInt or String input
final u128 = Bcs.u128().serialize('100000010000001000000').toBytes();

final str = Bcs.string().serialize('this is an ascii string').toBytes();
final bytes = Bcs.bytes(4).serialize([1, 2, 3, 4]).toBytes();

final parsedU8 = Bcs.u8().parse(u8); // int
final parsedU64 = Bcs.u64().parse(u64); // BigInt
final parsedStr = Bcs.string().parse(str); // String
```

## Compound types

For most use-cases you'll want to combine primitive types into more complex types like `vectors`,
`structs` and `enums`. The following table lists the factories available for creating compound
types:

| Factory                     | Description                                           |
| --------------------------- | ----------------------------------------------------- |
| `vector(T)`                 | A variable length list of values of type `T`          |
| `fixedArray(size, T)`       | A fixed length array of values of type `T`            |
| `option(T)`                 | A value of type `T` or `null`                         |
| `enumeration(name, values)` | An enum value representing one of the provided values |
| `struct(name, fields)`      | A struct with named fields of the provided types      |
| `tuple(types)`              | A tuple of the provided types                         |
| `map(K, V)`                 | A map of keys of type `K` to values of type `V`       |

```dart
import 'package:bcs/bcs.dart';

// Vectors
final intList = Bcs.vector(Bcs.u8()).serialize([1, 2, 3, 4, 5]).toBytes();
final stringList = Bcs.vector(Bcs.string()).serialize(['a', 'b', 'c']).toBytes();

// Arrays
final intArray = Bcs.fixedArray(4, Bcs.u8()).serialize([1, 2, 3, 4]).toBytes();

// Option
final option = Bcs.option(Bcs.string()).serialize('some value').toBytes();
final nullOption = Bcs.option(Bcs.string()).serialize(null).toBytes();

// Enum
final myEnum = Bcs.enumeration('MyEnum', {
  'NoType': null,
  'Int': Bcs.u8(),
  'String': Bcs.string(),
  'Array': Bcs.fixedArray(3, Bcs.u8()),
});

final noTypeEnum = myEnum.serialize({'NoType': null}).toBytes();
final intEnum = myEnum.serialize({'Int': 100}).toBytes();

// Struct
final myStruct = Bcs.struct('MyStruct', {
  'id': Bcs.u8(),
  'name': Bcs.string(),
});

final struct = myStruct.serialize({'id': 1, 'name': 'name'}).toBytes();

// Tuple
final tuple = Bcs.tuple([Bcs.u8(), Bcs.string()]).serialize([1, 'name']).toBytes();

// Map
final map = Bcs.map(Bcs.u8(), Bcs.string()).serialize({1: 'one', 2: 'two'}).toBytes();

// Parsing data back into original types
final parsedIntList = Bcs.vector(Bcs.u8()).parse(intList); // List<int>
final parsedOption = Bcs.option(Bcs.string()).parse(option); // String?
final parsedIntEnum = myEnum.parse(intEnum); // {'Int': 100, '$kind': 'Int'}
final parsedStruct = myStruct.parse(struct); // {'id': 1, 'name': 'name'}
final parsedMap = Bcs.map(Bcs.u8(), Bcs.string()).parse(map); // Map<int, String>
```

## Generics

To define a generic struct or enum, you can use a generic function helper:

```dart
import 'package:bcs/bcs.dart';

// The type parameters are placeholders for the Dart types of the generic value.
// The `inner` argument is the bcs type passed in when creating a concrete
// instance of the Container type.
BcsType<Map<String, dynamic>, dynamic> container<T, Input>(
    BcsType<T, Input> inner) {
  return Bcs.struct('Container<${inner.name}>', {
    'contents': inner,
  });
}

// When serializing, we have to pass the type to use for the contents
final bytes = container(Bcs.u8()).serialize({'contents': 100}).toBytes();

// Using multiple generics
BcsType<Map<String, dynamic>, dynamic> vecMap<K, V, InK, InV>(
    BcsType<K, InK> key, BcsType<V, InV> value) {
  // You can use the names of the generic params to give your type a more useful name
  return Bcs.struct('VecMap<${key.name}, ${value.name}>', {
    'keys': Bcs.vector(key),
    'values': Bcs.vector(value),
  });
}

final vecMapBytes = vecMap(Bcs.string(), Bcs.string()).serialize({
  'keys': ['key1', 'key2', 'key3'],
  'values': ['value1', 'value2', 'value3'],
}).toBytes();
```

## Transforms

If the format you use in your code is different from the format expected for BCS serialization,
you can use the `transform` API to map between the types you use in your application, and the
types needed for serialization.

The `address` type used by Move code is a good example of this. In many cases, you'll want to
represent an address as a hex string, but the BCS serialization format for addresses is a 32-byte
array. To handle this, you can use the `transform` API to map between the two formats:

```dart
final address = Bcs.bytes(32).transform(
  name: 'address',
  input: (String value) => hexDecode(value),
  output: (value) => hexEncode(value),
);

final serialized = address
    .serialize('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef')
    .toBytes();
final parsed = address.parse(serialized); // hex string
```

## Recursive types

Use `Bcs.lazy` to reference a schema that is not defined yet:

```dart
late final BcsType<Map<String, dynamic>, dynamic> tree;
tree = Bcs.struct('Tree', {
  'value': Bcs.u8(),
  'children': Bcs.vector(Bcs.lazy(() => tree)),
});
```

## Validation

Every factory accepts an optional `BcsTypeOptions` with a `validate` callback that runs before
each write:

```dart
final port = Bcs.u16(BcsTypeOptions(validate: (value) {
  if (value == 0) throw ArgumentError('port must not be 0');
}));
```

## Formats for serialized bytes

When you call `serialize` on a `BcsType`, you will receive a `SerializedBcs` instance. This
wrapper preserves type information for the serialized bytes, and can be used to get raw data in
various formats:

```dart
import 'dart:convert';

import 'package:bcs/bcs.dart';

final serializedString = Bcs.string().serialize('this is a string');

// SerializedBcs.toBytes() returns a Uint8List
final bytes = serializedString.toBytes();

// You can get the serialized bytes encoded as hex, base64 or base58
final hex = serializedString.toHex();
final b64 = serializedString.toBase64();
final b58 = serializedString.toBase58();

// To parse a BCS value from bytes, the bytes need to be a Uint8List
final str1 = Bcs.string().parse(bytes);

// If your data is an encoded string, decode it first (or use the from* helpers)
final str2 = Bcs.string().fromHex(hex);
final str3 = Bcs.string().fromBase64(b64);
final str4 = Bcs.string().fromBase58(b58);
```

Standalone helpers `hexEncode`/`hexDecode` and `base58Encode`/`base58Decode` are also exported;
for base64 use `base64Encode`/`base64Decode` from `dart:convert`.
